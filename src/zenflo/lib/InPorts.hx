package zenflo.lib;

import haxe.ds.Either;
import zenflo.lib.InPort.InPortOptions;
import haxe.DynamicAccess;

typedef InPortsOptions = DynamicAccess<InPortOptions>;

class InPorts extends Ports<InPort> {
    public function new(_ports:InPortsOptions) {
        if(_ports == null){
            ports = {};
        }
        var nP = Either.Right(_ports);
        var model = new InPort({});
        super(cast nP, model);
    }
}