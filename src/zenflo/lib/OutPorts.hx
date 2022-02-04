package zenflo.lib;

import tink.core.Error;
import haxe.ds.Either;
import zenflo.lib.OutPortOptions;
import haxe.DynamicAccess;

typedef OutPortsOptions = DynamicAccess</**Outport | OutPortOptions **/ Any>;

@:forward
abstract OutPorts(Ports) {
	public function new(?_ports:OutPortsOptions) {
		if (_ports == null) {
			_ports = new DynamicAccess<OutPortOptions>();
		}

		this = new Ports(cast _ports, "zenflo.lib.OutPort");
		final basePorts = this.ports;
		this.ports = basePorts;
	}

  @:from
  public static function fromOptions(options:OutPortsOptions):OutPorts {
    return new OutPorts(options);
  }

	public function connect(name:String, ?socketId:Int) {
		final port:OutPort = /** @type {OutPort} */ cast(this.ports[name]);
		if (port == null) {
			throw new Error('Port ${name} not available');
		}
		port.connect(socketId);
	}

	public function beginGroup(name:String, ?group:String, ?socketId:Int) {
		final port:OutPort = /** @type {OutPort} */ cast(this.ports[name]);
		if (port == null) {
			throw new Error('Port ${name} not available');
		}
		port.beginGroup(group, socketId);
	}

	public function send(name:String, ?data:Any, ?socketId:Int) {
		final port:OutPort = /** @type {OutPort} */ cast(this.ports[name]);
		if (port == null) {
			throw new Error('Port ${name} not available');
		}
		port.send(data, socketId);
	}

	public function endGroup(name:String, ?socketId:Int) {
		final port:OutPort = /** @type {OutPort} */ cast(this.ports[name]);
		if (port == null) {
			throw new Error('Port ${name} not available');
		}
		port.endGroup(socketId);
	}

	public function disconnect(name:String, ?socketId:Int) {
		final port:OutPort = /** @type {OutPort} */ cast(this.ports[name]);
		if (port == null) {
			throw new Error('Port ${name} not available');
		}
		port.disconnect(socketId);
	}

	@:arrayAccess
	public function get(name:String):BasePort {
		if (!this.ports.exists(name)) {
			throw new Error('Port ${name} not defined');
		}
		return Reflect.field(this, name);
	}
}
