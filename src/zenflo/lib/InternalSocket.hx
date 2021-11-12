package zenflo.lib;

import haxe.Constraints.Function;
import haxe.Timer;
import tink.core.Error;
import zenflo.lib.IP.IPType;

typedef InternalSocketOptions = {
	debug:Bool,
	async:Bool
}

@:structInit
class SocketError {
	public var error:Null<Error>;
	public var id:Null<String>;
	public var metadata:Null<Dynamic>;
}

function legacyToIP(event:String, payload:Any):IP {
	// No need to wrap modern IP Objects
	if (IP.isIP(payload)) {
		return payload;
	}

	// Wrap legacy events into appropriate IP objects
	switch (event) {
		case 'begingroup':
			return new IP(OpenBracket, payload);
		case 'endgroup':
			return new IP(CloseBracket);
		case 'data':
			return new IP(DATA, payload);
		default:
			return null;
	}
}

function ipToLegacy(ip:IP) {
	switch (ip.type) {
		case OpenBracket:
			return {
				event: 'begingroup',
				payload: ip.data,
			};
		case DATA:
			return {
				event: 'data',
				payload: ip.data,
			};
		case CloseBracket:
			return {
				event: 'endgroup',
				payload: ip.data,
			};
		default:
			return null;
	}
}

class InternalSocket extends EventEmitter {
	public var metadata:Null<Dynamic>;

	public var brackets:Array<Any>;

	public var connected:Bool;

	public var dataDelegate:Dynamic;

	public var debug:Bool;

	public var async:Bool;

	public var from:Link;

	public var to:Link;

	public function new(?metadata:Dynamic, ?options:InternalSocketOptions) {
		super();
		this.metadata = metadata;
		this.brackets = [];
		this.connected = false;
		this.dataDelegate = null;
		this.debug = options.debug || false;
		this.async = options.async || false;
		this.from = null;
		this.to = null;
	}

	function regularEmitEvent(event:String, data:Any) {
		this.emit(event, data);
	}

	function debugEmitEvent(event:String, data:Any) {
		try {
			this.emit(event, data);
		} catch (error:SocketError) {
			if (error.id != null && error.metadata != null && error.error != null) {
				// Wrapped debuggable error coming from downstream, no need to wrap
				if (this.listeners('error').length == 0) {
					throw error.error;
				}
				this.emit('error', error);
				return;
			}

			if (this.listeners('error').length == 0) {
				throw error;
			}

			this.emit('error', {
				id: this.to != null ? this.to.process.id : null,
				error: error,
				metadata: this.metadata,
			});
		}
	}

	public function emitEvent(event:String, data:Any) {
		if (this.debug) {
			if (this.async) {
				Timer.delay(() -> this.debugEmitEvent(event, data), 0);
				return;
			}
			this.debugEmitEvent(event, data);
			return;
		}
		if (this.async) {
			Timer.delay(() -> this.regularEmitEvent(event, data), 0);
			return;
		}
		this.regularEmitEvent(event, data);
	}

	/**
		## Socket connections

		Sockets that are attached to the ports of processes may be
		either connected or disconnected. The semantical meaning of
		a connection is that the outport is in the process of sending
		data. Disconnecting means an end of transmission.

		This can be used for example to signal the beginning and end
		of information packets resulting from the reading of a single
		file or a database query.

		Example, disconnecting when a file has been completely read:
			
		```
			function readBuffer(fd, position, size, buffer){
				// Send data. The first send will also connect if not
				// already connected.
				outPorts.out.send(buffer.slice(0, bytes))
				position += buffer.length;

				// Disconnect when the file has been completely read
				if (position >= size) return outPorts.out.disconnect();

				// Otherwise, call same method recursively
				readBuffer(fd, position, size, buffer);
			}
			
		```
	**/
	public function connect() {
		if (this.connected) {
			return;
		}
		this.connected = true;
		this.emitEvent('connect', null);
	}

	public function disconnect() {
		if (!this.connected) {
			return;
		}
		this.connected = false;
		this.emitEvent('disconnect', null);
	}

	public function isConnected():Bool {
		return this.connected;
	}

	/***
		## Sending information packets

		The _send_ method is used by a process's outport to
		send information packets. The actual packet contents are
		not defined by ZenFlo, and may be any valid Haxe data
		structure.

		The packet contents however should be such that may be safely
		serialized or deserialized via JSON. This way the ZenFlo networks
		can be constructed with more flexibility, as file buffers or
		message queues can be used as additional packet relay mechanisms.
	**/
	public function send(?data:Any) {
		if (data == null && Reflect.isFunction(this.dataDelegate)) {
			this.handleSocketEvent('data', this.dataDelegate());
			return;
		}
		this.handleSocketEvent('data', data);
	}

	public function post(packet:Any, autoDisconnect = true) {
		var ip = packet;
		if ((ip == null) && Reflect.isFunction(this.dataDelegate)) {
			ip = this.dataDelegate();
		}
		// Send legacy connect/disconnect if needed
		if (!this.isConnected() && (this.brackets.length == 0)) {
			(this.connect)();
		}
		this.handleSocketEvent('ip', ip, false);
		if (autoDisconnect && this.isConnected() && (this.brackets.length == 0)) {
			(this.disconnect)();
		}
	}

	/**
		## Information Packet grouping

		Processes sending data to sockets may also group the packets
		when necessary. This allows transmitting tree structures as
		a stream of packets.

		For example, an object could be split into multiple packets
		where each property is identified by a separate grouping:

		```
		// Group by object ID
		outPorts.out.beginGroup(object.id);
		for(property => value in object){
			outPorts.out.beginGroup(property);
			outPorts.out.send(value);
			outPorts.out.endGroup();
		}
		outPorts.out.endGroup();
		```

		This would cause a tree structure to be sent to the receiving
		process as a stream of packets. So, an article object may be
		as packets like:

		* `/<article id>/title/Lorem ipsum`
		* `/<article id>/author/Henri Bergius`

		Components are free to ignore groupings, but are recommended
		to pass received groupings onward if the data structures remain
		intact through the component's processing.
	**/
	public function beginGroup(group:Any) {
		this.handleSocketEvent('begingroup', group);
	}

	public function endGroup() {
		this.handleSocketEvent('endgroup');
	}

	/**
		## Socket data delegation

		Sockets have the option to receive data from a delegate function
		should the `send` method receive undefined for `data`.  This
		helps in the case of defaulting values.
	**/
	public function setDelegate(delegate:Dynamic) {
		if (Reflect.isFunction(delegate)) {
			throw new Error(InternalError, 'A data delegate must be a function.');
		}
		this.dataDelegate = delegate;
	}

	/**
		## Socket debug mode

		Sockets can catch exceptions happening in processes when data is
		sent to them. These errors can then be reported to the network for
		notification to the developer.
	**/
	public function setDebug(active:Bool) {
		this.debug = active;
	}

	/**
		## Socket identifiers

		Socket identifiers are mainly used for debugging purposes.
		Typical identifiers look like _ReadFile:OUT -> Display:IN_,
		but for sockets sending initial information packets to
		components may also loom like _DATA -> ReadFile:SOURCE_.
	**/
	public function getId() {
		final fromStr = (from:Link) -> '${from.process.id}() ${from.port.toUpperCase()}';
		final toStr = (to:Link) -> '${to.port.toUpperCase}() ${to.process.id}';

		if (this.from == null && this.to == null) {
			return 'UNDEFINED';
		}
		if (this.from == null && this.to == null) {
			return '${fromStr(this.from)} -> ANON';
		}
		if (this.from == null) {
			return 'DATA -> ${toStr(this.to)}';
		}
		return '${fromStr(this.from)} -> ${toStr(this.to)}';
	}

	public function handleSocketEvent(event:String, ?payload:Dynamic, autoConnect = true) {
		final isIP = (event == 'ip') && IP.isIP(payload);
		final ip = isIP ? payload : legacyToIP(event, payload);
		if (ip == null) {
			return;
		}

		if (!this.isConnected() && autoConnect && (this.brackets.length == 0)) {
			// Connect before sending
			this.connect();
		}

		if (event == 'begingroup') {
			this.brackets.push(payload);
		}
		if (isIP && (ip.type == OpenBracket)) {
			this.brackets.push(ip.data);
		}

		if (event == 'endgroup') {
			// Prevent closing already closed groups
			if (this.brackets.length == 0) {
				return;
			}
			// Add group name to bracket
			ip.data = this.brackets.pop();
			payload = ip.data;
		}
		if (isIP && (payload.type == IPType.CloseBracket)) {
			// Prevent closing already closed brackets
			if (this.brackets.length == 0) {
				return;
			}
			this.brackets.pop();
		}

		// Emit the IP Object
		this.emitEvent('ip', ip);

		// Emit the legacy event
		if (ip == null || ip.type == null) {
			return;
		}

		if (isIP) {
			final legacy = ipToLegacy(ip);
			event = legacy.event;
			payload = legacy.payload;
		}

		if (event == 'connect') {
			this.connected = true;
		}
		if (event == 'disconnect') {
			this.connected = false;
		}
		this.emitEvent(event, payload);
	}

	/**
		## Socket data delegation

		 Sockets have the option to receive data from a delegate function
		 should the `send` method receive undefined for `data`.  This
		 helps in the case of defaulting values.
	**/
	public function setDataDelegate(delegate:Function) {
		this.dataDelegate = delegate;
	}
}

function createSocket(?metadata:Dynamic, options:Any) {
	return new InternalSocket(metadata, options);
}
