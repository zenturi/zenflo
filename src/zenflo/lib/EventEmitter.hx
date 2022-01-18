package zenflo.lib;

// import hx.concurrent.Future.FutureResult;
import haxe.ds.Map;
// import tink.core.Callback;
// import tink.core.Callback.CallbackLink;
// import tink.core.Pair.MPair;
// import tink.core.Signal;
// import tink.core.Signal.SignalTrigger;
// import hx.concurrent.event.AsyncEventDispatcher;
// import hx.concurrent.event.SyncEventDispatcher;
// import hx.concurrent.executor.Executor;
import rx.Subject;
import rx.Observer;

using StringTools;

class EventEmitter {
	var subjects:Map<String, {subject:Subject<haxe.Rest<Any>>, once:Bool}>;

	public function new() {
		subjects = new Map<String, {subject:Subject<haxe.Rest<Any>>, once:Bool}>();
	}

	function createName(name:String) {
		return '$ ${name}';
	}

	public function emit(name:String, data:haxe.Rest<Any>) {
		final fnName = createName(name);
		if (this.subjects.exists(fnName)) {
			this.subjects.get(fnName).subject.on_next(...data);
			if (this.subjects.get(fnName).once) {
				this.subjects.get(fnName).subject.unsubscribe();
				this.subjects.remove(fnName);
			}
		}
	}

	public function on(name:String, handler:(data:haxe.Rest<Any>) -> Void) {
		final fnName = createName(name);
		if (!this.subjects.exists(fnName)) {
			this.subjects.set(fnName, {subject: new Subject(), once: false});
		}
		this.subjects.get(fnName).subject.subscribe(Observer.create(null, null, handler));
	}

	public function once(name:String, handler:(data:haxe.Rest<Any>) -> Void) {
		final fnName = createName(name);
		if (!this.subjects.exists(fnName)) {
			this.subjects.set(fnName, {subject: new Subject(), once: true});
		}
		this.subjects.get(fnName).subject.subscribe(Observer.create(null, null, handler));
	}

	public function removeAllListeners() {
		for(k=>v in this.subjects){
			v.subject.unsubscribe();
			this.subjects.remove(k);
		}
	}
}
