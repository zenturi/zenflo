package zenflo.lib;

// import hx.concurrent.Future.FutureResult;
import haxe.CallStack;
import haxe.ds.Map;
// import tink.core.Callback;
// import tink.core.Callback.CallbackLink;
// import tink.core.Pair.MPair;
// import tink.core.Signal;
// import tink.core.Signal.SignalTrigger;
// import hx.concurrent.event.AsyncEventDispatcher;
// import hx.concurrent.event.SyncEventDispatcher;
// import hx.concurrent.executor.Executor;
// import rx.Subject;
import rx.subjects.Replay as Subject;
import rx.Observer;

using StringTools;

class EventEmitter {
	var subjects:Map<String, {subject:Subject<Array<Any>>, once:Bool}>;

	var listeners:Map<String, Array<Observer<Array<Any>>>>;

	public function new() {
		subjects = new Map<String, {subject:Subject<Array<Any>>, once:Bool}>();
		listeners = new Map();
	}

	function createName(name:String) {
		return '$ ${name}';
	}

	public function emit(name:String, data:haxe.Rest<Any>) {
		final fnName = createName(name);
		if (this.subjects.exists(fnName)) {
			final x = [for (v in data) v];
			final f = this.subjects.get(fnName);
			if (f != null && f.subject != null) {
				f.subject.on_next(x);
				if (f.once) {
					f.subject.unsubscribe();
					this.subjects.remove(fnName);
					this.listeners.clear();
				}
			}
		}
	}

	public function on(name:String, handler:(data:Array<Any>) -> Void, once:Bool = false) {
		final fnName = createName(name);
		if (!this.subjects.exists(fnName)) {
			this.subjects.set(fnName, {subject: new Subject(), once: once});
		}
		if(!this.listeners.exists(fnName)) listeners.set(fnName, []);
		final f = this.subjects.get(fnName);
		if (f != null && f.subject != null) {
			final o = Observer.create(null, null, handler);
			f.subject.subscribe(o);
			listeners.get(fnName).push(o);
		}
	}

	public function once(name:String, handler:(data:Array<Any>) -> Void) {
		return on(name, handler, true);
	}

	public function removeAllListeners() {
		for (k => v in this.subjects) {
			v.subject.unsubscribe();
			this.subjects.remove(k);
		}
	}
}
