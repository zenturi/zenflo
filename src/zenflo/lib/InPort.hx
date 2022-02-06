package zenflo.lib;

import haxe.DynamicAccess;
import tink.core.Error;
import zenflo.lib.BasePort.BaseOptions;
import haxe.ds.IntMap;

/**
	Input Port (inport) implementation for ZenFlo components. These
	ports are the way a component receives Information Packets.
**/
typedef InPortOptions = {
	> BaseOptions,
	@:optional var Default:Null<Any>;
	@:optional var values:Array<Any>;
	@:optional var control:Null<Bool>;
	@:optional var triggering:Null<Bool>;
}

typedef HasValidationCallback = (ip:IP) -> Bool;

@:const
class InPort extends BasePort {
	public function new(?options:InPortOptions) {
		final opts = options;
		if(opts != null){
			if (opts.control == null) {
				opts.control = false;
			}
			if (opts.scoped == null) {
				opts.scoped = true;
			}
			if (opts.triggering == null) {
				opts.triggering = true;
			}
		}
		
		super(opts);

		final baseOptions = options;
		this.options = /** @type {PortOptions} */ (baseOptions);

		/** @type {import("./Component").Component|null} */
		this.nodeInstance = null;

		this.prepareBuffer();
	}

	override public function attachSocket(socket:InternalSocket, ?localId:Int) {
		// have a default value.
		
		if (this.hasDefault()) {
			final ops:Dynamic = this.options;
			socket.setDataDelegate(() -> ops.Default);
		}
		
	
		socket.on('connect', (_) -> this.handleSocketEvent('connect', socket, localId));
		socket.on('begingroup', (group) -> this.handleSocketEvent('begingroup', group[0], localId));
		socket.on('data', (data) -> {
			this.validateData(data[0]);
			return this.handleSocketEvent('data', data[0], localId);
		});
		socket.on('endgroup', (group) -> this.handleSocketEvent('endgroup', group[0], localId));
		socket.on('disconnect', (_) -> this.handleSocketEvent('disconnect', socket, localId));
		
		socket.on('ip', (ip) -> {
			this.handleIP(ip[0], localId);
		});
	}

	public function hasDefault():Bool {
		final op:Dynamic = this.options;
		return op != null && op.Default != null;
	}

	public function handleSocketEvent(event:String, payload:Dynamic, id:Null<Int>) {
		// Emit port event
		if (this.isAddressable()) {
			return this.emit(event, payload, id);
		}
		return this.emit(event, payload);
	}

	function validateData(data:Any) {
		final op:Dynamic = this.options;
		if (op != null && op.values == null) {
			return;
		}
		var values = [];
		if (op != null){
			values = op.values;
		}
		if (op != null && values.indexOf(data) == -1) {
			throw new Error('Invalid data=\'${data}\' received, not in [${op.values}]');
		}
	}

	public function handleIP(packet:IP, ?index:Int) {
		final op:Dynamic = this.options;
		if (op != null && op.control && (packet.type != DATA)) {
			return;
		}
		
		final ip = packet;
		ip.owner = this.nodeInstance;
		if (this.isAddressable()) {
			ip.index = index;
		}
		if (ip.dataType == 'all') {
			// Stamp non-specific IP objects with port datatype
			ip.dataType = this.getDataType();
		}
		if (this.getSchema() != null && ip.schema == null) {
			// Stamp non-specific IP objects with port schema
			ip.schema = this.getSchema();
		}

		final buf = this.prepareBufferForIP(ip);
		buf.push(ip);
		if (op != null && op.control && (buf.length > 1)) {
			buf.shift();
		}

		this.emit('ip', ip, index);
	}

	public function getBuffer(scope:String, index:Int, initial = false) {
		if (this.isAddressable()) {
			if ((scope != "null" || scope != null) && this.options.scoped) {
				if (!(this.indexedScopedBuffer.exists(scope))) {
					return null;
				}
				if (!(this.indexedScopedBuffer[scope].exists(index))) {
					return null;
				}
				return this.indexedScopedBuffer[scope].get(index);
			}
			if (initial) {
				if (!(this.indexedIipBuffer.exists(index))) {
					return null;
				}
				return this.indexedIipBuffer.get(index);
			}
			if (!(this.indexedBuffer.exists(index))) {
				return null;
			}
			return this.indexedBuffer.get(index);
		}
		if ((scope != "null" || scope != null) && this.options.scoped) {
			if (!(this.scopedBuffer.exists(scope))) {
				return null;
			}
			return this.scopedBuffer[scope];
		}
		if (initial) {
			return this.iipBuffer;
		}
		return this.buffer;
	}

	public function prepareBufferForIP(ip:IP):Array<IP> {
		if (this.isAddressable()) {
			if ((ip.scope != null || ip.scope != "null") && this.options.scoped) {
				if (!(this.indexedScopedBuffer.exists(ip.scope))) {
					this.indexedScopedBuffer.set(ip.scope, new IntMap());
				}
				if (!(this.indexedScopedBuffer[ip.scope].exists(ip.index))) {
					this.indexedScopedBuffer[ip.scope].set(ip.index, []);
				}
				return this.indexedScopedBuffer[ip.scope].get(ip.index);
			}
			if (ip.initial) {
				if (!(this.indexedIipBuffer.exists(ip.index))) {
					this.indexedIipBuffer.set(ip.index, []);
				}
				return this.indexedIipBuffer.get(ip.index);
			}
			if (!(this.indexedBuffer.exists(ip.index))) {
				this.indexedBuffer.set(ip.index, []);
			}
			return this.indexedBuffer.get(ip.index);
		}
		if (ip != null && (ip.scope != null || ip.scope != "null") && (this.options != null && this.options.scoped)) {
			if (!(this.scopedBuffer.exists(ip.scope))) {
				this.scopedBuffer[ip.scope] = [];
			}
			return this.scopedBuffer[ip.scope];
		}
		if (ip.initial) {
			return this.iipBuffer;
		}
		return this.buffer;
	}

	public function prepareBuffer() {
		if (this.isAddressable()) {
			if (this.options.scoped) {
				/** @type {Object<string,Object<number,Array<import("./IP").default>>>} */
				this.indexedScopedBuffer = {};
			}
			/** @type {Object<number,Array<import("./IP").default>>} */
			this.indexedIipBuffer = new IntMap();
			/** @type {Object<number,Array<import("./IP").default>>} */
			this.indexedBuffer = new IntMap();
			return;
		}
		if (this.options != null && this.options.scoped) {
			/** @type {Object<string,Array<import("./IP").default>>} */
			this.scopedBuffer = {};
		}
		/** @type {Array<import("./IP").default>} */
		this.iipBuffer = [];
		/** @type {Array<import("./IP").default>} */
		this.buffer = [];
	}

	public function getFromBuffer(scope:String, index:Int, initial = false) {
		final buf = this.getBuffer(scope, index, initial);
		if (!(buf != null ? buf.length != 0 : false)) {
			return null;
		}
		final op:Dynamic = this.options;

		if (op != null && op.control != null && op.control) {
			return buf[buf.length - 1];
		}
		return buf.shift();
	}

	/**
	 * Fetches a packet from the port
	 */
	public function get(scope:String, ?index:Int) {
		final res = this.getFromBuffer(scope, index);

		if (res != null) {
			return res;
		}
		// Try to find an IIP instead
		return this.getFromBuffer(null, index, true);
	}

	/**
	 * Fetches a packet from the port
	 */
	public function hasIPinBuffer(scope:String, ?index:Int, validate:HasValidationCallback, initial = false) {
		final buf = this.getBuffer(scope, index, initial);
		if (!(buf != null ? buf.length != 0 : false)) {
			return false;
		}
		for (i in 0...buf.length) {
			if (validate(buf[i])) {
				return true;
			}
		}
		return false;
	}

	public function hasIIP(?index:Int, validate:HasValidationCallback) {
		return this.hasIPinBuffer(null, index, validate, true);
	}

	/**
	 * Returns true if port contains packet(s) matching the validator
	 * @param {string|null} scope
	 * @param {number|null|HasValidationCallback} index
	 * @param {HasValidationCallback} [validate]
	 */
	public function has(scope:String, index:Dynamic, ?validate:HasValidationCallback) {
		
		var valid = validate;

		/** @type {number|null} */
		var idx:Null<Int> = null;

		if (Reflect.isFunction(index)) {
			valid = /** @type {HasValidationCallback} */ (index);
			idx = null;
		} else {
			idx = index;
		}
		
		final checkBuf = this.hasIPinBuffer(scope, idx, valid);
		if (checkBuf) {
			return true;
		}
		final checkIIP =  this.hasIIP(idx, valid);
		if (checkIIP) {
			return true;
		}
		return false;
	}

	var indexedScopedBuffer(default, null):DynamicAccess<IntMap<Array<IP>>>;

	var scopedBuffer(default, null):DynamicAccess<Array<IP>>;

	var indexedIipBuffer(default, null):IntMap<Array<IP>>;

	var indexedBuffer(default, null):IntMap<Array<IP>>;

	var iipBuffer(default, null):Null<Array<IP>>;

	var buffer(default, null):Null<Array<IP>>;

	/**
	 * Returns the number of data packets in an inport
	 * @param {string|null} scope
	 * @param {number|null} [index]
	 * @returns {number}
	 */
	public function length(scope:String, ?index:Int) {
		final buf = this.getBuffer(scope, index);
		if (buf == null) {
			return 0;
		}
		return buf.length;
	}

	/**
	 * Tells if buffer has packets or not
	 * @param {string|null} scope
	 */
	public function ready(scope:String) {
		return this.length(scope) > 0;
	}

	// Clears inport buffers
	public function clear() {
		return this.prepareBuffer();
	}
}
