package zenflo.lib;

import haxe.Rest;
import zenflo.lib.Ports.normalizePortName;
import zenflo.lib.InPort.InPortOptions;
import tink.core.Error;
import zenflo.lib.ProcessContext;
import zenflo.lib.ProcessOutput;
import zenflo.lib.ProcessInput;
import zenflo.lib.OutPorts.OutPortsOptions;
import zenflo.lib.InPorts.InPortsOptions;
import haxe.ds.Either;
import haxe.DynamicAccess;
import zenflo.lib.ProcessContext.ProcessResult;
import tink.core.Promise;

typedef ErrorableCallback = (e:Error) -> Void;

// typedef TBracketContext =  DynamicAccess<Dynamic>;

@:forward
abstract BracketContext(Dynamic) from Dynamic to Dynamic {
	public inline function new() {
		this = {
			"in": {},
			"out": {}
		};
	}

	@:arrayAccess
	public function setField(key:String, value:Any) {
		Reflect.setField(this, key, value);
	}

	@:arrayAccess
	public function getField(key:String):Any {
		return Reflect.field(this, key);
	}
}

typedef ProcessingFunction = (input:ProcessInput, output:ProcessOutput, context:ProcessContext) -> Any /*Promise<Dynamic>*/;

@:structInit
class ComponentOptions {
	/**
		Inports for the component
	**/
	public var inPorts:InPorts = null;

	/**
		Outports for the component
	**/
	public var outPorts:OutPorts = null;

	public var icon:String = null;
	public var description:String = null;

	/**
		Component processsing function
	**/
	public var process:ProcessingFunction = null;

	/**
		Whether component should send
		 		packets in same order it received them
	**/
	public var ordered:Null<Bool> = null;

	public var autoOrdering:Null<Bool> = null;

	/**
		Whether component should
		  activate when it receives packets
	**/
	public var activateOnInput:Bool = true;

	/**
		Mappings of forwarding ports
	**/
	public var forwardBrackets:DynamicAccess<Array<String>> = null;
}

class Component extends EventEmitter {
	public var inPorts:InPorts;
	public var outPorts:OutPorts;
	public var network:Network;
	public var load:Int;
	public var __openConnections:Null<Int>;
	public var nodeId:String;
	public var bracketContext:BracketContext;

	var componentDebug = new DebugComponent("zenflo:component");
	var bracketsDebug = new DebugComponent('zenflo:component:brackets');
	var sendDebug = new DebugComponent('zenflo:component:send');

	function debugComponent(msg:String) {
		componentDebug.Debug(msg);
	}

	function debugSend(msg:String) {
		sendDebug.Debug(msg);
	}

	function debugBrackets(msg:String) {
		bracketsDebug.Debug(msg);
	}

	public function new(?options:ComponentOptions) {
		super();
		final opts:ComponentOptions = options != null ? options : {};
		// Prepare inports, if any were given in options.
		// They can also be set up imperatively after component
		// instantiation by using the `component.inPorts.add`
		// method.
		if (opts.inPorts == null) {
			opts.inPorts = new InPorts();
		}
		this.inPorts = opts.inPorts;

		// Prepare outports, if any were given in opts.
		// They can also be set up imperatively after component
		// instantiation by using the `component.outPorts.add`
		// method.
		if (opts.outPorts == null) {
			opts.outPorts = new OutPorts();
		}
		this.outPorts = opts.outPorts;

		// Set the default component icon and description
		this.icon = opts.icon != null ? opts.icon : '';
		this.description = opts.description != null ? opts.description : '';

		/** @type {string|null} */
		this.componentName = null;
		/** @type {string|null} */
		this.baseDir = null;

		// Initially the component is not started
		this.started = false;
		this.load = 0;

		// Whether the component should keep send packets
		// out in the order they were received
		this.ordered = opts.ordered != null ? opts.ordered : false;
		this.autoOrdering = opts.autoOrdering != null ? opts.autoOrdering : null;

		// Queue for handling ordered output packets
		/** @type {ProcessResult[]} */
		this.outputQ = [];

		// Context used for bracket forwarding
		this.bracketContext = new BracketContext();

		// Whether the component should activate when it
		// receives packets
		this.activateOnInput = opts.activateOnInput;

		// Bracket forwarding rules. By default we forward
		// brackets from `in` port to `out` and `error` ports.
		if (opts.forwardBrackets == null) {
			opts.forwardBrackets = new DynamicAccess<Array<String>>();
			opts.forwardBrackets["in"] = ['out', 'error'];
		} 

		this.forwardBrackets = opts.forwardBrackets;

		// The component's process function can either be
		// passed in opts, or given imperatively after
		// instantation using the `component.process` method.
		if (opts.process != null) {
			this.process(opts.process);
		}

		// Placeholder for the ID of the current node, populated
		// by ZenFlo network
		//
		/** @type string | null */
		this.nodeId = null;

		// Deprecated legacy component connection counter
		this.__openConnections = 0;
	}

	public function isSubgraph():Bool {
		return false;
	}

	/**
		### Shutdown

		Called when network is shut down. This sets calls the
		tearDown method and sets the component back to a
		non-started state.

		The callback is called when tearDown finishes and
		all active processing contexts have ended.
	**/
	public function shutdown():Promise<Any> {
		return this.tearDown().next((_) -> new Promise((resolve, _) -> {
			if (this.load > 0) {
				// Some in-flight processes, wait for them to finish

				/**
				 * @param {number} load
				 */
				var checkLoad:(loads:Array<Any>) -> Void = null;

				checkLoad = (loads:Array<Any>) -> {
					final load:Int = loads[0];
					if (load > 0) {
						return;
					}
					this.removeListener('deactivate', checkLoad);
					resolve(null);
				};
				this.on('deactivate', checkLoad);
				return null;
			} else {
				resolve(null);
			}
			return null;
		})).next((_) -> {
			final inPorts = this.inPorts.ports;
			for (portName in inPorts.keys()) {
				final inPort:InPort = /** @type {InPort} */ cast(inPorts[portName]);
				inPort.clear();
			}

			this.bracketContext = new BracketContext();

			if (!this.isStarted()) {
				return Promise.resolve(null);
			}
			this.started = false;
			this.emit('end');

			return Promise.resolve(null);
		});
	}

	public function getDescription() {
		return this.description;
	}

	public function isReady():Bool {
		return true;
	}

	public function getIcon():String {
		return this.icon;
	}

	/**
		@param icon - Updated icon for the component
	**/
	public function setIcon(icon:String) {
		this.icon = icon;
		this.emit('icon', this.icon);
	}

	/**
		### Start

		Called when network starts. This sets calls the setUp
		method and sets the component to a started state.

	**/
	public function start():Promise<Any> {
		var promise = new Promise(null);
		if (this.isStarted()) {
			promise = Promise.resolve(null);
		} else {
			promise = new Promise((resolve, reject)->{
				this.setUp().handle((_) -> {
					switch(_){
						case Success(_):{
							this.started = true;
							this.emit('start');
							resolve(null);
						}
						case Failure(err):{
							resolve(err);
						}
					}
				});
				return null;
			});
		}
		return promise;
	}

	/**
		### Error emitting helper

		If component has an `error` outport that is connected, errors
		are sent as IP objects there. If the port is not connected,
		errors are thrown.
	**/
	public function error(e:Error, ?groups:Array<String>, errorPort = 'error', scope:String = null) {
		final outPort:OutPort = /** @type {OutPort} */ cast(this.outPorts.ports[errorPort]);
		if (outPort != null && (outPort.isAttached() || !outPort.isRequired())) {
			if (groups != null) {
				for (group in groups) {
					outPort.openBracket(group, new IP(DATA, null, {scope: scope}));
				}
			}
			outPort.data(e, new IP(DATA, null, {scope: scope}));
			if (groups != null) {
				for (group in groups) {
					outPort.closeBracket(group, new IP(DATA, null, {scope: scope}));
				}
			}
			return;
		}
		throw e;
	}

	/**
		## Setup

		The setUp method is for component-specific initialization.
		Called at network start-up.

		Override in component implementation to do component-specific
		setup work.
	**/
	public function setUp():Promise<Dynamic> {
		return Promise.resolve(null);
	}

	/**
		### Teardown

		The tearDown method is for component-specific cleanup. Called
		at network shutdown

		Override in component implementation to do component-specific
		cleanup work, like clearing any accumulated state.
	**/
	public function tearDown():Promise<Dynamic> {
		return Promise.resolve(null);
	}

	/**
		Ensures bracket forwarding map is correct for the existing ports
	**/
	public function prepareForwarding() {
		for (inPort in this.forwardBrackets.keys()) {
			final outPorts = this.forwardBrackets[inPort];
	
			if (!(this.inPorts.ports.exists(inPort))) {
				this.forwardBrackets.remove(inPort);
				continue;
			}

			final tmp:Array<String> = [];

			for (outPort in outPorts) {
				if (this.outPorts.ports.exists(outPort)) {
					tmp.push(outPort);
				}
			}

			if (tmp.length == 0) {
				this.forwardBrackets.remove(inPort);
			} else {
				this.forwardBrackets[inPort] = tmp;
			}
		}

	}

	/**
		Signal that component has activated. There may be multiple
		activated contexts at the same time
	**/
	public function activate(context:ProcessContext) {
		if (context.activated) {
			return;
		} // prevent double activation
		context.activated = true;
		context.deactivated = false;
		this.load += 1;
		this.emit('activate', this.load);
		if (this.ordered || this.autoOrdering) {
			this.outputQ.push(context.result);
		}
	}

	/**
		Signal that component has deactivated. There may be multiple
		activated contexts at the same time
	**/
	public function deactivate(context:ProcessContext) {
		if (context.deactivated) {
			return;
		} // prevent double deactivation
		context.deactivated = true;
		context.activated = false;

		if (this.isOrdered()) {
			this.processOutputQueue();
		}
		this.load -= 1;
		this.emit('deactivate', this.load);
	}

	public var outputQ:Array<ProcessResult>;

	/**
		Method for checking whether the component sends packets
		in the same order they were received.
	**/
	public function isOrdered():Bool {
		if (this.ordered) {
			return true;
		}
		if (this.autoOrdering) {
			return true;
		}
		return false;
	}

	/**
		Get the current bracket forwarding context for an IP object
	**/
	public function getBracketContext(type:String, port:String, ?scope:Any, ?idx:Int):Array<BracketContext> {
		final x = normalizePortName(port);

		var name = x.name;
		var index = x.index;
		if (idx != null) {
			index = '${idx}';
		}
		final portsList:Ports = type == 'in' ? cast this.inPorts : cast this.outPorts;

		if (portsList.ports[name].isAddressable()) {
			name = '${name}[${index}]';
		} else {
			name = port;
		}

		if (scope == null)
			scope = "null";

		// Ensure we have a bracket context for the current scope
		if (!Reflect.hasField(this.bracketContext[type], name)) {
			Reflect.setField(this.bracketContext[type], name, {});
		}

		if (!Reflect.hasField(Reflect.field(this.bracketContext[type], name), scope)) {
			Reflect.setField(Reflect.field(this.bracketContext[type], name), scope, []);
		}

		return Reflect.field(Reflect.field(this.bracketContext[type], name), scope);
	}

	/**
		Add an IP object to the list of results to be sent in
		order
	**/
	public function addToResult(result:ProcessResult, port:String, packet:IP, before:Bool = false) {
		final res = result;
		final ip = packet;
		final x = normalizePortName(port);
		var name = x.name;
		var index = x.index;

		if (this.outPorts.ports[name].isAddressable()) {
			final idx = /** @type {number} */ (index != null && index.length != 0 ? Std.parseInt(index) : ip.index);
			if (!Reflect.hasField(res, name)) {
				Reflect.setField(res, name, {});
			}
			if (!Reflect.hasField(Reflect.field(res, name), '$idx')) {
				Reflect.setField(Reflect.field(res, name), '$idx', []);
			}

			ip.index = idx;
			if (before) {
				Reflect.field(Reflect.field(res, name), '$idx').unshift(ip);
			} else {
				Reflect.field(Reflect.field(res, name), '$idx').push(ip);
			}
			return;
		}
		if (!Reflect.hasField(res, name)) {
			Reflect.setField(res, name, []);
		}

		if (before) {
			Reflect.field(res, name).unshift(ip);
		} else {
			Reflect.field(res, name).push(ip);
		}
	}

	/**
		Get contexts that can be forwarded with this in/outport
		pair.
	**/
	public function getForwardableContexts(inport:Dynamic, outport:Dynamic, contexts:Array<ProcessContext>):Array<ProcessContext> {
		var x = normalizePortName(outport);
		var index = x.index;
		var name = x.name;

		final forwardable = [];
		
		for (idx => ctx in contexts) {
			// No forwarding to this outport
			if (!this.isForwardingOutport(inport, name)) {
				continue;
			}
			// We have already forwarded this context to this outport
			final _ports:Array<Dynamic> =  ctx["ports"];
			if (_ports.indexOf(outport) != -1) {
				continue;
			}
			// See if we have already forwarded the same bracket from another
			// inport
			final outContext:BracketContext = this.getBracketContext('out', name, ctx.ip.scope, Std.parseInt(index))[idx];
			if (outContext != null) {
				final ip:IP = outContext["ip"];
				final ports:Array<Any> = outContext["ports"];
				if ((ip.data == ctx.ip.data) && (ports.indexOf(outport) != -1)) {
					continue;
				}
			}
			forwardable.push(ctx);
		}
		return forwardable;
	}

	public var icon:String;

	public var description:String;

	public var componentName:String;

	public var baseDir:String;

	public var started:Bool;

	public var ordered:Bool = false;

	public var autoOrdering:Null<Bool>;

	public var activateOnInput:Bool;

	public var forwardBrackets:DynamicAccess<Array<String>>;

	public function process(handle:ProcessingFunction) {
		if (this.inPorts == null) {
			throw new Error('Component ports must be defined before process function');
		}

		this.prepareForwarding();
		this.handle = handle;
		Lambda.iter(this.inPorts.ports.keys(), (name)->{
			final port:InPort = cast /** @type {InPort} */ (this.inPorts.ports[name]);
			if (port.name == null) {
				port.name = name;
			}
			port.on('ip', (vals) -> {
				final ip:IP = vals[0];
				this.handleIP(ip, port);
			});
		});
	
		return this;
	}

	/**
		Method for checking if a given inport is set up for
		automatic bracket forwarding
	**/
	public function isForwardingInport(port:Dynamic) {
		var portName:String = null;
		if (Std.isOfType(port, String)) {
			portName = port;
		} else {
			portName = port.name;
		}
		if (portName != null && this.forwardBrackets.exists(portName)) {
			return true;
		}
		return false;
	}

	/**
		Method for checking if a given outport is set up for
		automatic bracket forwarding
	**/
	public function isForwardingOutport(inport:Dynamic, outport:Dynamic) {
		var inportName:String = null;
		var outportName:String = null;
		if (Std.isOfType(inport, String)) {
			inportName = inport;
		} else {
			inportName = inport.name;
		}
		if (Std.isOfType(outport, String)) {
			outportName = outport;
		} else {
			outportName = outport.name;
		}
		if (inportName == null || outportName == null) {
			return false;
		}

		if (!this.forwardBrackets.exists(inportName)) {
			return false;
		}
		if (this.forwardBrackets[inportName].indexOf(outportName) != -1) {
			return true;
		}
		return false;
	}

	public function isStarted():Bool {
		return this.started;
	}

	var handle:ProcessingFunction;

	/**
		### Handling IP objects

		The component has received an Information Packet. Call the
		processing function so that firing pattern preconditions can
		be checked and component can do processing as needed.
	**/
	public function handleIP(ip:IP, port:Null<InPort>) {
		final op:Dynamic = port.options;
	
		if (op != null && !op.triggering) {
			// If port is non-triggering, we can skip the process function call
			return;
		}

		if (ip.type == OpenBracket && this.autoOrdering == null && !this.ordered) {
			// Switch component to ordered mode when receiving a stream unless
			// auto-ordering is disabled
			debugComponent('${this.nodeId} port \'${port.name}\' entered auto-ordering mode');
			this.autoOrdering = true;
		}

		// Initialize the result object for situations where output needs
		// to be queued to be kept in order

		/** @type {ProcessResult} */
		var result:ProcessResult = {};

	
		if (this.isForwardingInport(port)) {
			
			// For bracket-forwarding inports we need to initialize a bracket context
			// so that brackets can be sent as part of the output, and closed after.
			if (ip.type == OpenBracket) {
				// For forwarding ports openBrackets don't fire
				return;
			}

			if (ip.type == CloseBracket) {
				// For forwarding ports closeBrackets don't fire
				// However, we need to handle several different scenarios:
				// A. There are closeBrackets in queue before current packet
				// B. There are closeBrackets in queue after current packet
				// C. We've queued the results from all in-flight processes and
				//    new closeBracket arrives
				final buf = port.getBuffer(ip.scope, ip.index);
				final dataPackets = buf.filter((p) -> p.type == DATA);
				if ((this.outputQ.length >= this.load) && (dataPackets.length == 0)) {
					if (buf[0] != ip) {
						return;
					}
					if (port.name == null) {
						return;
					}
					// Remove from buffer
					port.get(ip.scope, ip.index);
					final bracketCtx = this.getBracketContext('in', port.name, ip.scope, ip.index).pop();
					bracketCtx.closeIp = ip;
					debugBrackets('${this.nodeId} closeBracket-C from \'${bracketCtx.source}\' to ${bracketCtx.ports}: \'${ip.data}\'');
					result = {
						__resolved: true,
						__bracketClosingAfter: [bracketCtx],
					};
					this.outputQ.push(result);
					this.processOutputQueue();
				}
				// Check if buffer contains data IPs. If it does, we want to allow
				// firing
				if (dataPackets.length == 0) {
					return;
				}
			}
		}

		// Prepare the input/output pair
		final context:ProcessContext = new ProcessContext({
			ip: ip,
			nodeInstance: this,
			port: port,
			result: result
		});

	
		final input = new ProcessInput(this.inPorts, context);
		final output = new ProcessOutput(this.outPorts, context);
		try {
			// Call the processing function
			if (this.handle == null) {
				throw new Error('Processing function not defined');
			}
			final res:Dynamic = this.handle(input, output, context);
			if (res != null && res.handle != null) {
				// Processing function is a Promise
				final _res:Promise<Any> = cast res;
				_res.handle((c) -> {
					switch c {
						case Success(data): {
								output.sendDone(data);
							}
						case Failure(failure): {
								output.done(failure);
							}
					}
				});
			}
		} catch (e:Error) {
			this.deactivate(context);
			output.sendDone(e);
		}


		if (context.activated) {
			return;
		}
		// If receiving an IP object didn't cause the component to
		// activate, log that input conditions were not met
		if (port.isAddressable()) {
			debugComponent('${this.nodeId} packet on \'${port.name}[${ip.index}]\' didn\'t match preconditions: ${ip.type}');
			return;
		}
		debugComponent('${this.nodeId} packet on \'${port.name}\' didn\'t match preconditions: ${ip.type}');
	}

	/**
		Whenever an execution context finishes, send all resolved
		output from the queue in the order it is in.
	**/
	function processOutputQueue() {
		while (this.outputQ.length > 0) {
			if (!this.outputQ[0].__resolved) {
				break;
			}

			final result = this.outputQ.shift();
			// trace(result);
			this.addBracketForwards(result);
			Lambda.iter( Reflect.fields(result), (port)->{
				var portIdentifier = null;
				final ips:Dynamic = Reflect.field(result, port);
				if (port.indexOf('__') == 0) {
					return;
				}

				if (this.outPorts.ports[port].isAddressable()) {
					Lambda.iter( Reflect.fields(ips), (index)->{
						final idxIps:Array<IP> = Reflect.field(ips, index);
						final idx = Std.parseInt(index);
						if (!this.outPorts.ports[port].isAttached(idx)) {
							return;
						}
						Lambda.iter(idxIps, (packet)->{
							final ip = packet;
							portIdentifier = '${port}[${ip.index}]';
							if (ip.type == OpenBracket) {
								debugSend('${this.nodeId} sending ${portIdentifier} < \'${ip.data}\'');
							} else if (ip.type == CloseBracket) {
								debugSend('${this.nodeId} sending ${portIdentifier} > \'${ip.data}\'');
							} else {
								debugSend('${this.nodeId} sending ${portIdentifier} DATA');
							}
							if (this.outPorts.ports[port].options.scoped) {
								ip.scope = null;
							}
							final out:OutPort = cast this.outPorts.ports[port];
							out.sendIP(Either.Left(ip));
						});
					});
					return;
				}
				if (!this.outPorts.ports[port].isAttached()) {
					return;
				}

				if (Std.isOfType(ips, Array)) {
					var _ips:Array<IP> = cast ips;
					Lambda.iter(_ips, (packet)->{
						final ip = packet;
						portIdentifier = port;
						if (ip.type == OpenBracket) {
							debugSend('${this.nodeId} sending ${portIdentifier} < \'${ip.data}\'');
						} else if (ip.type == CloseBracket) {
							debugSend('${this.nodeId} sending ${portIdentifier} > \'${ip.data}\'');
						} else {
							debugSend('${this.nodeId} sending ${portIdentifier} DATA');
						}
						if (!this.outPorts.ports[port].options.scoped) {
							ip.scope = null;
						}
						final out:OutPort = cast this.outPorts.ports[port];
						out.sendIP(Either.Left(ip));
					});
				}
			});
		
		}
	}

	/**
		Add any bracket forwards needed to the result queue
	**/
	function addBracketForwards(result:Null<ProcessResult>) {
		final res = result;

		if (res.__bracketClosingBefore != null &&  res.__bracketClosingBefore.length != 0) {
			for (context in res.__bracketClosingBefore) {
				debugBrackets('${this.nodeId} closeBracket-A from \'${context["source"]}\' to ${context["ports"]}: \'${context.closeIp.data}\'');
				if (context["ports"].length == 0) {
					continue;
				}
				final _ports:Array<Dynamic> = context["ports"];
				for (port in _ports) {
					final ipClone = context.closeIp.clone();
					this.addToResult(res, port, ipClone, true);
					this.getBracketContext('out', port, ipClone.scope).pop();
				}
			}
		}
		if (res.__bracketContext != null) {
			// First see if there are any brackets to forward. We need to reverse
			// the keys so that they get added in correct order
			var keys = Reflect.fields(res.__bracketContext);
			keys.reverse();
			Lambda.iter(keys, (inport) -> {
				if (!Std.isOfType(res.__bracketContext[inport], Array))
					return;
				var context:Array<ProcessContext> = cast res.__bracketContext[inport];
				if (context.length == 0) {
					return;
				}
				Lambda.iter(Reflect.fields(res), (outport) -> {
					var datas:Array<IP> = null;
					var forwardedOpens = null;
					var unforwarded:Array<ProcessContext> = [];
					var ips:Dynamic = Reflect.field(res, outport);
					if (outport.indexOf('__') == 0) {
						return;
					}
					if (this.outPorts.ports[outport].isAddressable()) {
						Lambda.iter(Reflect.fields(ips), (idx)-> {
							// Don't register indexes we're only sending brackets to
							final idxIps:Array<IP> = Reflect.field(ips, idx);

							datas = idxIps.filter((ip) -> ip.type == DATA);
							if (datas.length == 0) {
								return;
							}
							final portIdentifier = '${outport}[${idx}]';
							unforwarded = this.getForwardableContexts(inport, portIdentifier, context);
							if (unforwarded.length == 0) {
								return;
							}
							forwardedOpens = [];

							for (ctx in unforwarded) {
								debugBrackets('${this.nodeId} openBracket from \'${inport}\' to \'${portIdentifier}\': \'${ctx.ip.data}\'');
								final ipClone = ctx.ip.clone();
								ipClone.index = Std.parseInt(idx);
								forwardedOpens.push(ipClone);
								ctx["ports"].push(portIdentifier);
								this.getBracketContext('out', outport, ctx.ip.scope, ipClone.index).push(ctx);
							}
							forwardedOpens.reverse();
							for (ip in forwardedOpens) {
								this.addToResult(res, outport, ip, true);
							}
						});
						return;
					}
					if (Std.isOfType(ips, Array)) {
						// Don't register ports we're only sending brackets to
						datas = ips.filter((ip) -> ip.type == 'data');
						if (datas.length == 0) {
							return;
						}
						unforwarded = this.getForwardableContexts(inport, outport, context);
						if (unforwarded.length == 0) {
							return;
						}
						forwardedOpens = [];
						for (ctx in unforwarded) {
							debugBrackets('${this.nodeId} openBracket from \'${inport}\' to \'${outport}\': \'${ctx.ip.data}\'');
							forwardedOpens.push(ctx.ip.clone());
							ctx["ports"].push(outport);
							this.getBracketContext('out', outport, ctx.ip.scope).push(ctx);
						}
						forwardedOpens.reverse();
						for (ip in forwardedOpens) {
							this.addToResult(res, outport, ip, true);
						}
					}
				});
			});
		}

		if (res.__bracketClosingAfter != null ? res.__bracketClosingAfter.length != 0 : false) {
			for (context in res.__bracketClosingAfter) {
				debugBrackets('${this.nodeId} closeBracket-B from \'${context.source}\' to ${context["ports"]}: \'${context.closeIp.data}\'');
				final _ports:Array<Dynamic> = context["ports"];
				if (_ports.length == 0) {
					continue;
				}
				var bp:Array<String> = context["ports"];
				for (port in bp) {
					final closeIp:IP = context.closeIp;
					final ipClone:IP = closeIp.clone();
					this.addToResult(res, port, ipClone, false);
					this.getBracketContext('out', port, ipClone.scope).pop();
				}
			}
		}

		res.__bracketClosingBefore = null;
		res.__bracketContext = null;
		res.__bracketClosingAfter = null;
	}
}

class DebugComponent #if !cpp extends sneaker.tag.Tagged #end {
	#if (cpp && debug)
	private var tag:String;
	#end

	public function new(tag:String) {
		#if !cpp
		super();
		#end
		#if !cpp
		this.tag = new sneaker.tag.Tag(tag);
		#end
		#if (cpp && debug)
		this.tag = tag;
		#end
	}

	public function Debug(message:String) {
		#if !cpp
		this.debug(message);
		#end
		#if (cpp && debug)
		Sys.println('[$tag] => $message');
		#end
	}

	public function Error(message:String) {
		#if !cpp
		this.error(message);
		#end
		#if (cpp && debug)
		Sys.println('[$tag] => $message');
		#end
	}
}
