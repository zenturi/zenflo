package zenflo.lib;

import haxe.ds.Either;
import zenflo.lib.InPort.InPortOptions;
import haxe.DynamicAccess;

typedef InPortsOptions = DynamicAccess<InPortOptions>;

class InPorts extends Ports {
    public function new(?_ports:InPortsOptions) {
        if(_ports == null){
            ports = {};
        }
        super(cast _ports, "zenflo.lib.InPort");
    }
}