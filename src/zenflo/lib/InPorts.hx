package zenflo.lib;

import tink.core.Error;
import haxe.ds.Either;
import zenflo.lib.InPort.InPortOptions;
import haxe.DynamicAccess;

typedef InPortsOptions = DynamicAccess<InPortOptions>;

@:forward
abstract InPorts(Ports) {
    public function new(?_ports:InPortsOptions) {
        if(_ports == null){
            _ports = {};
        }
       this = new Ports(cast _ports, "zenflo.lib.InPort");
    }

    @:arrayAccess
	public function get(name:String):BasePort {
		if (!this.ports.exists(name)) {
			throw new Error('Port ${name} not defined');
		}
		return Reflect.field(this, name);
	}
}