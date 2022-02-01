package zenflo.lib;

import haxe.DynamicAccess;
import haxe.ds.Either;
import zenflo.lib.BasePort;
import zenflo.lib.BasePort.BaseOptions;
import tink.core.Error;

using StringTools;


class Ports extends EventEmitter {
	public final model:String;

	public var ports:DynamicAccess<BasePort> = new DynamicAccess<BasePort>();

	public function new(ports:DynamicAccess<Dynamic>, type:String) {
		super();
		this.model = type;
		for (name in ports.keys()) {
			final options = ports[name];
			this.add(name, options);
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
			this.remove(name);
		}

		final maybePort = /** @type {import("./BasePort").default} */ (options);
		
		if (Std.isOfType(maybePort, BasePort) && maybePort.canAttach != null) {
			this.ports[name] = cast maybePort;
		} else {
			if (model == 'zenflo.lib.InPort'){
				this.ports[name] = cast new zenflo.lib.InPort(cast options);
			}
			if (model == 'zenflo.lib.OutPort'){
				this.ports[name] = cast new zenflo.lib.OutPort(cast options);
			}
		}

		this.emit('add', name);

		return this;
	}

	public function remove(name:String) {
		if (!this.ports.exists(name)) {
			throw new Error('Port ${name} not defined');
		}
		this.ports.remove(name);

		this.emit('remove', name);

		return this;
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
