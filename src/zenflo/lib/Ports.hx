package zenflo.lib;

import haxe.DynamicAccess;
import haxe.ds.Either;
import zenflo.lib.BasePort;
import zenflo.lib.BasePort.BaseOptions;
import tink.core.Error;

using StringTools;


typedef TPorts = {
	var model:String;
	var ports:DynamicAccess<BasePort>;
	var _events:EventEmitter;
}


@:forward
abstract Ports(TPorts) {
	public function new(ports:DynamicAccess<Dynamic>, type:String) {
		this = {
			_events: new EventEmitter(),
			model: type,
			ports: new DynamicAccess<BasePort>()
		};
		
		for (name in ports.keys()) {
			final options = ports[name];
			add(name, options);
		}
	}

	public function add(name:String, ?options:Dynamic) {
		if (options == null) {
			options = {};
		}
		if ((name == 'add') || (name == 'remove')) {
			throw new Error('Add and remove are restricted port names');
		}

		var re = ~/^[a-z0-9_\.\/]+$/;

		/* eslint-disable no-useless-escape */
		if (!re.match(name)) {
			throw new Error('Port names can only contain lowercase alphanumeric characters and underscores. \'${name}\' not allowed');
		}

		// Remove previous implementation
		if (this.ports.exists(name)) {
			remove(name);
		}

		final maybePort = /** @type {import("./BasePort").default} */ (options);
		
		if (Std.isOfType(maybePort, BasePort) && maybePort.canAttach != null) {
			this.ports[name] = cast maybePort;
		} else {
			if (this.model == 'zenflo.lib.InPort'){
				this.ports[name] = cast new zenflo.lib.InPort(cast options);
			}
			if (this.model == 'zenflo.lib.OutPort'){
				this.ports[name] = cast new zenflo.lib.OutPort(cast options);
			}
		}

		Reflect.setField(this, name, this.ports[name]);

		this._events.emit('add', name);

		return this;
	}

	public function remove(name:String) {
		if (!this.ports.exists(name)) {
			throw new Error('Port ${name} not defined');
		}
		this.ports.remove(name);
		Reflect.deleteField(this, name);
		this._events.emit('remove', name);

		return this;
	}

	@:arrayAccess
	public function get(name:String):BasePort {
		if (!this.ports.exists(name)) {
			throw new Error('Port ${name} not defined');
		}
		return Reflect.field(this, name);
	}


	public function on(port:String, event:String, handler:(data:Array<Any>) -> Void) {
		if (!this.ports.exists(port)) {
			throw new Error('Port ${port} not defined');
		}
		this.ports[port].on(event, handler, false);
		Reflect.field(this, port).on(event, handler, false);
	}

	public function once(port:String, event:String, handler:(data:Array<Any>) -> Void) {
		if (!this.ports.exists(port)) {
			throw new Error('Port ${port} not defined');
		}
		this.ports[port].once(event, handler);
		Reflect.field(this, port).once(event, handler);
	}
}


function normalizePortName(name:String) {
	final port = {name: name, index: ""};
	// Regular port
	if (name.contains('[')) {
		return port;
	}
	// Addressable port with index
	final re = ~/(.*)\[([0-9]+)\]/;
	final matched = re.match(name);

	if (!matched) {
		return port;
	}
	return {
		name: re.matched(1),
		index: re.matched(2),
	};
}
