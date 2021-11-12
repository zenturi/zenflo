package zenflo.lib;

import tink.core.Error;
import haxe.ds.Either;
import zenflo.lib.OutPort.OutPortOptions;

import haxe.DynamicAccess;

typedef OutPortsOptions = DynamicAccess<OutPortOptions>;

class OutPorts extends Ports<OutPort> {
	public function new(?_ports:OutPortsOptions) {
        if(_ports == null){
            _ports = new DynamicAccess<OutPortOptions>();
        }
        var model = new OutPort({});
        var np = Either.Right(_ports);
		super(cast np, model);
        final basePorts = this.ports;
        this.ports = basePorts;
	}

    public function connect(name:String, socketId:Int) {
        final port = /** @type {OutPort} */ (this.ports[name]);
        if (port == null) { throw new Error('Port ${name} not available'); }
        port.connect(socketId);
      }
    
      public function beginGroup(name:String, group:String, socketId:Int) {
        final port = /** @type {OutPort} */ (this.ports[name]);
        if (port == null) { throw new Error('Port ${name} not available'); }
        port.beginGroup(group, socketId);
      }
    
      public function send(name:String, data:Any, socketId:Int) {
        final port = /** @type {OutPort} */ (this.ports[name]);
        if (port == null) { throw new Error('Port ${name} not available'); }
        port.send(data, socketId);
      }
    
      public function endGroup(name:String, socketId:Int) {
        final port = /** @type {OutPort} */ (this.ports[name]);
        if (port == null) { throw new Error('Port ${name} not available'); }
        port.endGroup(socketId);
      }
    
      public function disconnect(name:String, socketId:Int) {
        final port = /** @type {OutPort} */ (this.ports[name]);
        if (port == null) { throw new Error('Port ${name} not available'); }
        port.disconnect(socketId);
      }
}
