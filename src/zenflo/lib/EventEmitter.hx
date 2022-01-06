package zenflo.lib;

// import hx.concurrent.Future.FutureResult;
import haxe.ds.Map;
// import tink.core.Callback;
import tink.core.Callback.CallbackLink;
// import tink.core.Pair.MPair;
// import tink.core.Signal;
// import tink.core.Signal.SignalTrigger;
// import hx.concurrent.event.AsyncEventDispatcher;
// import hx.concurrent.event.SyncEventDispatcher;
// import hx.concurrent.executor.Executor;

// import rx.Subject;
// import rx.Observer;

using StringTools;



// class EventEmitter {
// 	final subjects:Map<String, Subject<haxe.Rest<Any>>>;


// 	function createName (name:String) {
// 		return '$ ${name}';
// 	}

// 	public function new() {
// 		this.subjects = new Map();
// 	}

// 	public function emit(name:String, ...v:Any) {
// 		final fnName = createName(name);
// 		if(!subjects.exists(fnName)) this.subjects.set(fnName, new Subject());
// 		this.subjects.get(fnName).on_next(...v);
// 	}

// 	public function on(name:String, callback:(...v:Any) -> Void) {
// 		final fnName = createName(name);
// 		if(!subjects.exists(fnName)) this.subjects.set(fnName, new Subject());
// 		return this.subjects.get(fnName).subscribe(Observer.create(callback));
// 	}

// 	public function once(name:String, callback:(...v:Any) -> Void) {
// 		this.on(name, callback).unsubscribe();
// 	}

// 	public function dispose(){
// 		var subjects = this.subjects;
// 		for(prop in subjects){
// 			prop.unsubscribe();
// 		}

// 		this.subjects.clear();
// 	}

// 	function setMaxListeners(arg0:Int) {}
// }

// class EventEmitter {
// 	final signals:Map<String, SyncEventDispatcher<haxe.Rest<Any>>>;
// 	final one_signals:Map<String, MPair<SyncEventDispatcher<haxe.Rest<Any>>, Array<() -> Bool>>>;
// 	final one_listeners:Map<String, Array<(...v:Any) -> Void>>;

// 	// static final executor:Executor = Executor.create(2);

// 	public function new() {
// 		signals = new Map();
// 		one_signals = new Map();
// 		one_listeners = new Map();
// 	}

// 	public function setMaxListeners(count:Int) {
// 		// maxListeners = count;
// 	}

// 	public function on(name:String, callback:(...v:Any) -> Void) {
// 		var asyncDispatcher = new SyncEventDispatcher<haxe.Rest<Any>>();
// 		if (signals.exists(name)) {
// 			signals.get(name).subscribe(callback);
// 		} else {
// 			asyncDispatcher.subscribe(callback);
// 			signals.set(name, asyncDispatcher);
// 		}
// 	}

// 	public function once(name:String, callback:(...v:Any) -> Void) {
// 		var asyncDispatcher = new SyncEventDispatcher<haxe.Rest<Any>>();
// 		asyncDispatcher.subscribe(callback);
// 		if (one_signals.exists(name)) {
// 			var s = one_signals.get(name);
// 			s.a.subscribe(callback);
// 			s.b.unshift(s.a.unsubscribe.bind(callback));
// 			one_signals.set(name, s);
// 		} else {
// 			asyncDispatcher.subscribe(callback);
// 			one_signals.set(name, new MPair(asyncDispatcher, [asyncDispatcher.unsubscribe.bind(callback)]));
// 		}
// 	}

// 	public function emit(name:String, ...v:Any) {
// 		if (signals.exists(name)) {
// 			final signal = signals.get(name);
// 			signal.fire(...v);
// 		}
// 		if (one_signals.exists(name)) {
// 			final one_signal = one_signals.get(name);
// 			var s = one_signal.a.fire(...v);
// 			s.onResult = (res:FutureResult<Int>)->
// 			{
// 				switch res {
// 					case SUCCESS(result, time, future):
// 						{
// 							one_signal.a.unsubscribeAll();
// 							// trace(name, 1);
// 							// final f = one_signal.b.pop();
// 							// if(f != null){
// 							// 	f();
// 							// 	one_signal.b.remove(f);
// 							// }
// 						}
// 					case FAILURE(ex, _):
// 						trace('Event could not be delivered because of: $ex');
// 					case _:
// 				}
// 			}
// 			// switch s.result {
// 			// 	case SUCCESS(result, time, future): {
// 			// 			// trace(name, 1);
// 			// 			// final f = one_signal.b.pop();
// 			// 			// if(f != null){
// 			// 			// 	f();
// 			// 			// 	one_signal.b.remove(f);
// 			// 			// }
// 			// 		}
// 			// 	case FAILURE(ex, _): trace('Event could not be delivered because of: $ex');
// 			// 	case _:
// 			// }
// 			// s.onResult = (result:FutureResult<Int>) -> {

// 			// };
// 		}
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
