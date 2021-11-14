package zenflo.lib;

import haxe.ds.Map;
import tink.core.Callback;
import tink.core.Callback.CallbackLink;
import tink.core.Pair.MPair;
import tink.core.Signal;
import tink.core.Signal.SignalTrigger;

using StringTools;

// class EventEmitter {
// 	final signals:Map<String, AsyncEventDispatcher<haxe.Rest<Any>>>;
//     final one_signals:Map<String, AsyncEventDispatcher<haxe.Rest<Any>>>;
//     final one_listeners:Map<String, Array<(...v:Any) -> Void>>;
//     final executor:Executor;
// 	public function new() {
//         executor = Executor.create(2);
// 		signals = new Map();
//         one_signals = new Map();
//         one_listeners = new Map();
// 	}
// 	public function on(name:String, callback:(...v:Any) -> Void) {
// 		var asyncDispatcher = new AsyncEventDispatcher<haxe.Rest<Any>>(executor);
// 		if (signals.exists(name)) {
// 			signals.get(name).subscribe(callback);
// 		} else {
//             asyncDispatcher.subscribe(callback);
// 			signals.set(name, asyncDispatcher);
// 		}
// 	}
// 	public function once(name:String, callback:(...v:Any) -> Void) {
// 		var asyncDispatcher = new AsyncEventDispatcher<haxe.Rest<Any>>(executor);
// 		asyncDispatcher.subscribe(callback);
// 		if (one_signals.exists(name)) {
//             var s = one_signals.get(name);
// 			s.subscribe(callback);
// 		} else {
//             asyncDispatcher.subscribe(callback);
// 			one_signals.set(name, asyncDispatcher);
// 		}
//         if(one_listeners.exists(name)){
//             var l = one_listeners.get(name);
//             l.push(callback);
//         } else {
//             one_listeners.set(name, [callback]);
//         }
// 	}
// 	public function emit(name:String, ...v:Any) {
// 		if (signals.exists(name)) {
// 			final signal = signals.get(name);
//             signal.fire(...v);
// 		}
//         if(one_signals.exists(name)){
//             final one_signal = one_signals.get(name);
//             var s = one_signal.fire(...v);
//             s.onResult = (result:FutureResult<Int>)->{
//                 switch result {
//                     case SUCCESS(result, time, future):{
//                         haxe.Timer.delay(()->{
//                             one_signal.unsubscribe(one_listeners[name][result]);
//                             one_signals.remove(name);
//                         }, 0);
//                     }
//                     case FAILURE(ex, _): trace('Event could not be delivered because of: $ex');
//                     case _:
//                 }
//             };
//         }
// 	}
// }
class EventEmitter {
	final types:Map<String, Array<(...args:Any) -> Void>> = new Map();
	var busyCount = 0;
	var maxListeners = 10;

	public function new() {}

	public function setMaxListeners(count:Int) {
		maxListeners = count;
	}

	public function addListener(type:String, listener:(...args:Any) -> Void)
		switch types[type] {
			case null:
				types[type] = [listener];
			case v:
				v.push(listener);
		}

	public function removeListener(type:String, listener:(...args:Any) -> Void)
		switch types[type] {
			case null:
			case listeners:
				if (busyCount > 0) // if we're currently busy, we'll just null the listener
					switch listeners.indexOf(listener) {
						case -1:
						case index: listeners[index] = null;
					}
				else
					listeners.remove(listener);
		}

	public function emit(type, ...args:Any)
		switch types[type] {
			case null:
			case listeners:
				busyCount++;
                Lambda.foreach(listeners, (h)->{
                    if (h != null)
                        h(...args);
                    return true;
                });
			
				if (--busyCount == 0) // time to take out the trash
					switch listeners.indexOf(null) {
						case -1:
						case start:
							var target = start;
							for (index in start...listeners.length)
								switch listeners[index] {
									case null:
									case listener:
										listeners[target++] = listener;
								}
							listeners.resize(target);
					}
		}

	public function on(type, listener):CallbackLink {
		addListener(type, listener);
		return removeListener.bind(type, listener);
	}

	public function once(type, listener:(...args:Any) -> Void):CallbackLink {
        // trace(types[type] != null ? types[type].length : '-1');
		return on(type, function callAndRemove(...args:Any) {
			removeListener(type, callAndRemove);
            listener(...args);
		});
	}
}
