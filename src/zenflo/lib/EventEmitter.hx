package zenflo.lib;

import tink.core.Callback;
import tink.core.Callback.CallbackLink;
import tink.core.Pair.MPair;
import tink.core.Signal;
import tink.core.Signal.SignalTrigger;
using StringTools;

class EventEmitter {
    final signals:haxe.ds.Map<String, Array<MPair<Bool, SignalTrigger<haxe.Rest<Any>>>>>;
    final __listeners:haxe.ds.Map<String, Array<Callback<haxe.Rest<Any>>>>;
    public function new() {
        signals = new Map();
        __listeners = new Map();
    }

    public function on(name:String, callback:(...v:Any)->Void):CallbackLink {
        final trigger = Signal.trigger();
        final signal = trigger.asSignal();
        var funcs = new Array<MPair<Bool, SignalTrigger<haxe.Rest<Any>>>>();

        if(signals.exists(name)){
            funcs = signals.get(name);
        }

        funcs.push(new MPair(false, trigger));
        signals.set(name, funcs);

        return signal.handle(callback); 
    }

    public function once(name:String, callback:(...v:Any)->Void):CallbackLink {
        final trigger = Signal.trigger();
        final signal = trigger.asSignal();
        var funcs = new Array<MPair<Bool, SignalTrigger<haxe.Rest<Any>>>>();

        if(signals.exists(name)){
            funcs = signals.get(name);
        }

        funcs.push(new MPair(true, trigger));
        signals.set(name, funcs);

        return signal.handle(callback); 
    }

    public function emit(name:String, ...v:Any) {
        var funcs = new Array<MPair<Bool, SignalTrigger<haxe.Rest<Any>>>>();
        if(signals.exists(name)){
            funcs = signals.get(name);
            for(f in funcs){
                f.b.trigger(...v);
                if(f.a){
                    f.b.dispose();
                }
            }
        }
    }

    public function addListener(name:String, callback:(...v:Any)->Void) {
        var funcs = new Array<MPair<Bool, SignalTrigger<haxe.Rest<Any>>>>();
        if(signals.exists(name)){
            funcs = signals.get(name);
            var _listeners = __listeners.exists(name) ? __listeners.get(name) : [];
            for(f in funcs){
                f.b.listen(callback);
                _listeners.push(callback); 
                if(_listeners.length == 0){
                    __listeners.set(name, _listeners);
                }
            }
        }
    }

    public function removeListener(name:String, callback:(...v:Any)->Void) {
        var listeners = this.listeners(name);
        if(listeners.contains(callback)){
            listeners.remove(callback);
        }
    }

    public function listeners(name:String) {
        return __listeners.get(name);
    }
}