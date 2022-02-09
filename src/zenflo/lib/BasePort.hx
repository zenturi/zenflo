package zenflo.lib;

import tink.CoreApi.Ref;
import haxe.DynamicAccess;
import zenflo.lib.BaseNetwork.NetworkProcess;
import tink.core.Error;

/**
	The list of valid datatypes for ports.
**/
final validTypes = [
	'all', 'string', 'number', 'int', 'object', 'array', 'boolean', 'color', 'date', 'bang', 'function', 'buffer', 'stream',
];

/**
	Options for configuring all types of ports
**/
typedef BaseOptions = {
	@:optional var description:Null<String>;
	@:optional var addressable:Null<Bool>;
	@:optional var buffered:Null<Bool>;
	@:optional var dataType:Null<String>;
	@:optional var schema:Null<String>;
	@:optional var type:Null<String>;
	@:optional var required:Null<Bool>;
	@:optional var scoped:Null<Bool>;
}

function handleOptions(options:BaseOptions):BaseOptions {
	// We default to the `all` type if no explicit datatype
	// was provided
	var datatype = options.dataType != null ? options.dataType : 'all';
	// Normalize the legacy `integer` type to `int`.
	if (datatype == 'integer') {
		datatype = 'int';
	}

	// By default ports are not required for graph execution
	final required = options.required != null ? options.required : false;

	// Ensure datatype defined for the port is valid
	if (validTypes.indexOf(datatype) == -1) {
		throw new Error(InternalError, 'Invalid port datatype \'${datatype}\' specified, valid are ${validTypes.join(', ')}');
	}

	// Ensure schema defined for the port is valid
	final schema = options.schema != null ? options.schema : options.type;

	if (schema != null && (schema.indexOf('/') == -1)) {
		throw new Error(InternalError, 'Invalid port schema \'${schema}\' specified. Should be URL or MIME type');
	}

	// Scoping
	final scoped = options.scoped;

	// Description
	final description = options.description != null ? options.description : '';

	final ret:BaseOptions = Reflect.copy(options);
	if (ret != null) {
		ret.description = description;
		ret.dataType = datatype;
		ret.required = required;
		ret.schema = schema;
		ret.scoped = scoped;
	}

	return ret;
}

@:const
class BasePort extends EventEmitter {
	public var process:NetworkProcess;
	public var options:BaseOptions;

	public var sockets:Array<InternalSocket>;

	public var nodeInstance:Component;

	public var name:String;

	public var node:String;

	public function new(?options:BaseOptions) {
		super();

		// Options holds all options of the current port
		if (options != null)
			this.options = handleOptions(options);
		// Sockets list contains all currently attached
		// connections to the port
		/** @type {Array<import("./InternalSocket").InternalSocket|void>} */
		this.sockets = [];
		// Name of the graph node this port is in
		/** @type {string|null} */
		this.node = null;
		/** @type {import("./Component").Component|null} */
		this.nodeInstance = null;
		// Name of the port
		/** @type {string|null} */
		this.name = null;
	}

	public function getId():String {
		if (this.node == null || this.name == null) {
			return 'Port';
		}
		return '${this.node} ${this.name.toUpperCase()}';
	}

	public function getDataType():String {
		return this.options != null && this.options.dataType != null ? this.options.dataType : 'all';
	}

	public function getSchema():String {
		return this.options != null && this.options.schema != null ? this.options.schema : null;
	}

	public function getDescription():String {
		return this.options != null ? this.options.description : "";
	}

	public function attach(socket:InternalSocket, ?index:Int) {
		var idx = /** @type {number} */ (index);
		if (!this.isAddressable() || (index == null)) {
			idx = this.sockets.length;
		}

		if (this.sockets == null)
			this.sockets = [];
		this.sockets[idx] = socket;
		
		this.attachSocket(socket, idx);

		if (this.isAddressable()) {
			this.emit('attach', socket, idx);
			return;
		}
		this.emit('attach', socket);
	}

	public function attachSocket(socket:InternalSocket, ?index:Int) {}

	public function detach(socket:InternalSocket) {
		final index = this.sockets.indexOf(socket);
		if (index == -1) {
			return;
		}
		this.sockets[index] = null;
		if (this.isAddressable()) {
			this.emit('detach', socket, index);
			return;
		}
		this.emit('detach', socket);
	}

	public function isAddressable() {
		if (this.options != null && this.options.addressable) {
			return true;
		}
		return false;
	}

	public function isBuffered() {
		if (this.options != null && this.options.buffered) {
			return true;
		}
		return false;
	}

	public function isRequired() {
		if (this.options != null && this.options.required) {
			return true;
		}
		return false;
	}

	public function isAttached(?socketId:Int):Bool {
		if (this.isAddressable() && (socketId != null)) {
			if (this.sockets[socketId] != null) {
				return true;
			}
			return false;
		}
		if (this.sockets.length != 0) {
			return true;
		}
		return false;
	}

	public function listAttached() {
		final attached = [];
		for (idx in 0...this.sockets.length) {
			final socket = this.sockets[idx];
			if (socket != null) {
				attached.push(idx);
			}
		}
		return attached;
	}

	public function isConnected(?socketId:Int):Bool {
		if (this.isAddressable()) {
			if (socketId == null) {
				throw new Error(InternalError, '${this.getId()}: Socket ID required');
			}
			if (this.sockets[socketId] == null) {
				throw new Error(InternalError, '${this.getId()}: Socket ${socketId} not available');
			}
			// eslint-disable-next-line max-len
			final socket = /** @type {import("./InternalSocket").InternalSocket} */ (this.sockets[socketId]);
			return socket.isConnected();
		}

		var connected = false;
		for (socket in this.sockets) {
			if (socket == null) {
				break;
			}
			if (socket.isConnected()) {
				connected = true;
			}
		}

		return connected;
	}

	public function canAttach() {
		return true;
	}

	// public function hasDefault():Bool {
	// 	throw new haxe.exceptions.NotImplementedException();
	// }
}
