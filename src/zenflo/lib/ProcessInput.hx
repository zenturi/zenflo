package zenflo.lib;

import zenflo.lib.Component.BracketContext;
import zenflo.lib.ProcessContext.ProcessResult;
import haxe.DynamicAccess;
import haxe.Constraints.Function;
import zenflo.lib.InPort.HasValidationCallback;
import tink.core.Error;
import haxe.ds.Either;
import sneaker.log.Logger.*;

class ProcessInput extends sneaker.tag.Tagged {
	public function new(ports:InPorts, context:ProcessContext) {
		super();
		this.ports = ports;
		this.context = context;
		this.nodeInstance = this.context.nodeInstance;
		this.ip = this.context.ip;
		this.port = this.context.port;
		this.result = this.context.result;
		this.scope = this.context.scope;

		this.newTag("zenflo:component");
	}

	public var ip:IP;

	public var nodeInstance:Component;

	public var port:InPort;

	public var result:ProcessResult;

	public var activated:Bool;

	public var scope:String;

	public var deactivated:Bool;

	public var context(default, null):ProcessContext;

	var ports:InPorts;

	/**
		When preconditions are met, set component state to `activated`
	**/
	public function activate() {
		if (this.context.activated) {
			return;
		}
		if (this.nodeInstance.isOrdered()) {
			// We're handling packets in order. Set the result as non-resolved
			// so that it can be send when the order comes up
			this.result.__resolved = false;
		}
		this.nodeInstance.activate(this.context);
		if (this.port.isAddressable()) {
			this.debug('${this.nodeInstance.nodeId} packet on \'${this.port.name}[${this.ip.index}]\' caused activation ${this.nodeInstance.load}: ${this.ip.type}');
		} else {
			this.debug('${this.nodeInstance.nodeId} packet on \'${this.port.name}\' caused activation ${this.nodeInstance.load}: ${this.ip.type}');
		}
	}

	/**
		## Connection listing

		This allows components to check which input ports are attached. This is
		useful mainly for addressable ports
	**/
	public function attached(...params:String):Either<Array<Int>, Array<Array<Int>>> {
		var args = params;
		if (args.length == 0) {
			args = ['in'];
		}

		final res:Array<Array<Int>> = [];

		for (port in args) {
			if (!this.ports.ports.exists(port)) {
				throw new Error('Node ${this.nodeInstance.nodeId} has no port \'${port}\'');
			}
			res.push(this.ports.ports[port].listAttached());
		}

		if (args.length == 1) {
			return Either.Left(res[0]);
		}
		return Either.Right(res);
	}

	/**
		## Input preconditions

		When the processing function is called, it can check if input buffers
		contain the packets needed for the process to fire.
		This precondition handling is done via the `has` and `hasStream` methods.

		Returns true if a port (or ports joined by logical AND) has a new IP
		Passing a validation callback as a last argument allows more selective
		checking of packets.
	**/
	public function has(...params:Dynamic):Bool {
		var validate:HasValidationCallback = null;
		var args = params.toArray().filter((p) -> !Reflect.isFunction(p));
		if (args.length == 0) {
			args = ['in'];
		}
		if (Reflect.isFunction(params[params.length - 1])) {
			validate = /** @type {HasValidationCallback} */ (params[params.length - 1]);
		} else {
			validate = (_) -> true;
		}

		for (i in 0...args.length) {
			final port:Dynamic = args[i];
			if (Std.isOfType(port, Array)) {
				final portImpl = /** @type {import("./InPort").default} */ (this.ports.ports[port[0]]);
				if (portImpl == null) {
					throw new Error('Node ${this.nodeInstance.nodeId} has no port \'${port[0]}\'');
				}
				if (!portImpl.isAddressable()) {
					throw new Error('Non-addressable ports, access must be with string ${port[0]}');
				}
				final portIdx:Int = (Std.isOfType(port[1], String)) ? Std.parseInt(port[1]) : port[1];
				if (!portImpl.has(this.scope, portIdx, validate)) {
					return false;
				}
			} else if (Std.isOfType(port, String)) {
				final portImpl = /** @type {import("./InPort").default} */ (this.ports.ports[port]);
				if (portImpl == null) {
					throw new Error('Node ${this.nodeInstance.nodeId} has no port \'${port}\'');
				}
				if (portImpl.isAddressable()) {
					throw new Error('For addressable ports, access must be with array [${port}, idx]');
				}
				if (!portImpl.has(this.scope, validate)) {
					return false;
				}
			} else {
				throw new Error('Unknown port type ${Type.getClassName(port)}');
			}
		}

		return true;
	}

	/**
		Returns true if the ports contain data packets
	**/
	public function hasData(...params:String):Bool {
		var args = params.toArray();
		if (args.length == 0) {
			args = ['in'];
		}
		final hasArgs:Array<Dynamic> = [for (arg in args) args];
		hasArgs.push((ip) -> ip.type == 'data');
		return this.has(...hasArgs);
	}

	/**
		Returns true if a port has a complete stream in its input buffer.
	**/
	public function hasStream(...params:Dynamic):Bool {
		var validateStream:Function = null;
		var args = params.toArray().filter((p) -> !Reflect.isFunction(p));
		if (args.length == 0) {
			args = ['in'];
		}
		if (Reflect.isFunction(args[args.length - 1])) {
			validateStream = /** @type {Function} */ (args.pop());
		} else {
			validateStream = () -> true;
		}

		for (i in 0...args.length) {
			final port = args[i];

			/** @type Array<string> */
			final portBrackets = [];

			var hasData = false;

			final validate:HasValidationCallback = (ip) -> {
				switch ip.type {
					case OpenBracket: {
							portBrackets.push(ip.data);
							return false;
						}
					case DATA: {
							// Run the stream validation callback
							hasData = validateStream(ip, portBrackets);
							// Data IP on its own is a valid stream
							if (portBrackets.length == 0) {
								return hasData;
							}
							// Otherwise we need to check for complete stream
							return false;
						}
					case CloseBracket: {
							portBrackets.pop();
							if (portBrackets.length != 0) {
								return false;
							}
							if (!hasData) {
								return false;
							}
							return true;
						}
				}
				return false;
			};

			if (!this.has(port, validate)) {
				return false;
			}
		}

		return true;
	}

	/**
		## Input processing

		Once preconditions have been met, the processing function can read from
		the input buffers. Reading packets sets the component as "activated".

		Fetches IP object(s) for port(s)
	**/
	public function get(...params:Dynamic):Dynamic {
		this.activate();

		var args = params;

		if (args.length == 0) {
			args = ['in'];
		}

		/** @type {Array<IP|void>} */
		final res:Array<Dynamic> = [];

		for (i in 0...args.length) {
			final port:Dynamic = args[i];
			var idx:Null<Int> = null;
			var ip:IP = null;
			var portname:String = "";

			if (Std.isOfType(port, Array)) {
				var v:Array<Dynamic> = cast port;
				portname = v[0];
				idx = v[1];
				if (!this.ports.ports[portname].isAddressable()) {
					throw new Error('Non-addressable ports, access must be with string portname');
				}
			} else {
				portname = port;
				if (this.ports.ports[portname].isAddressable()) {
					throw new Error('For addressable ports, access must be with array [portname, idx]');
				}
			}

			final name = /** @type {string} */ (portname);
			final idxName = /** @type {number} */ (idx);

			if (this.nodeInstance.isForwardingInport(name)) {
				ip = this.__getForForwarding(name, idxName);
				res.push(ip);
			} else {
				final portImpl = /** @type {import("./InPort").default} */ (this.ports.ports[name]);
				ip = portImpl.get(this.scope, idxName);
				res.push(ip);
			}
		}

		if (args.length == 1) {
			return res[0];
		}
		return res;
	}

	function __getForForwarding(port:String, idx:Int):Dynamic {
		final prefix = [];
		var dataIp = null;

		// Read IPs until we hit data
		var ok = true;

		while (ok) {
			// Read next packet
			final portImpl = /** @type {import("./InPort").default} */ (this.ports.ports[port]);
			final ip:IP = portImpl.get(this.scope, idx);
			// Stop at the end of the buffer
			if (ip == null) {
				break;
			}
			if (ip.type == DATA) {
				// Hit the data IP, stop here
				dataIp = ip;
				ok = false;
				break;
			}
			// Keep track of bracket closings and openings before
			prefix.push(ip);
		}

		// Forwarding brackets that came before data packet need to manipulate context
		// and be added to result so they can be forwarded correctly to ports that
		// need them
		for (i in 0...prefix.length) {
			final ip = prefix[i];
			switch ip.type {
				case CloseBracket:
					{
						// Bracket closings before data should remove bracket context
						if (this.result.__bracketClosingBefore == null) {
							this.result.__bracketClosingBefore = [];
						}
						final context = this.nodeInstance.getBracketContext('in', port, this.scope, idx).pop();
						context.closeIp = ip;
						this.result.__bracketClosingBefore.push(context);
					}
				case OpenBracket:
					{
						// Bracket openings need to go to bracket context
						this.nodeInstance.getBracketContext('in', port, this.scope, idx).push({
							ip: ip,
							ports: [],
							source: port,
						});
					}
				case _:
			}
		}

		// Add current bracket context to the result so that when we send
		// to ports we can also add the surrounding brackets
		if (this.result.__bracketContext != null) {
			this.result.__bracketContext = new BracketContext();
		}
		this.result.__bracketContext[port] = this.nodeInstance.getBracketContext('in', port, this.scope, idx).slice(0);
		// Bracket closings that were in buffer after the data packet need to
		// be added to result for done() to read them from

		return dataIp;
	}

	/***
		Fetches `data` property of IP object(s) for given port(s)
	**/
	public function getData(...params:Dynamic):Dynamic {
		var args = params.toArray();
		if (args.length == 0) {
			args = ['in'];
		}

		/** @type {Array<any>} */
		final datas:Array<Any> = [];

		for (index => port in args) {
			var packet:IP = /** @type {IP} */ (this.get(port));
			if (packet == null) {
				// we add the null packet to the array so when getting
				// multiple ports, if one is null we still return it
				// so the indexes are correct.
				datas.push(packet);
				return null;
			}

			while (packet.type != DATA) {
				packet = /** @type {IP} */ (this.get(port));
				if (packet == null) {
					break;
				}
			}

			datas.push(packet.data);
		}

		if (args.length == 1) {
			return datas.pop();
		}
		return datas;
	}

	/**
		Fetches a complete data stream from the buffer.
	**/
	public function getStream(...params:Dynamic):Dynamic {
		var args = params.toArray();

		if (args.length == 0) {
			args = ['in'];
		}

		/** @type {Array<Array<IP>|void>} */
		final datas:Array<Dynamic> = [];

		for (i in 0...args.length) {
			final port = args[i];
			final portBrackets = [];

			/** @type {Array<IP>} */
			var portPackets:Array<IP> = [];

			var hasData = false;
			var ip:IP = /** @type {IP} */ (this.get(port));
			if (ip == null) {
				datas.push(null);
			}

			while (ip != null) {
				switch ip.type {
					case OpenBracket:
						{
							if (portBrackets.length == 0) {
								// First openBracket in stream, drop previous
								portPackets = [];
								hasData = false;
							}
							portBrackets.push(ip.data);
							portPackets.push(ip);
						}
					case DATA:
						{
							portPackets.push(ip);
							hasData = true;
							// Unbracketed data packet is a valid stream
							if (portBrackets.length == 0) {
								break;
							}
						}
					case CloseBracket:
						{
							portPackets.push(ip);
							portBrackets.pop();
							if (hasData && portBrackets.length == 0) {
								// Last close bracket finishes stream if there was data inside
								break;
							}
						}
				}

				ip = /** @type {IP} */ (this.get(port));
			}
			datas.push(portPackets);
		}

		if (args.length == 1) {
			return datas[0];
		}
		return datas;
	}
}
