package zenflo.lib;

// import hx.concurrent.Future.FutureResult;
import haxe.CallStack;
import haxe.ds.Map;

import rx.Subject;
import rx.Observer;

using StringTools;


/**
 * Todo: This Event emitter implementation is not perfect. It doesn't work for nested listeners. 
 * [NEED A FIX]
 */


typedef SubjectMap = {subject:Subject<Array<Any>>, once:Bool,  handler:(data:Array<Any>) -> Void};



class EventEmitter {
	var subjects:Map<String, Array<SubjectMap>>;

	var listeners:Map<String, Array<(data:Array<Any>) -> Void>>;

	public function new() {
		subjects = new Map<String, Array<SubjectMap>>();
		listeners = new Map();
	}

	function createName(name:String) {
		return '$ ${name}';
	}

	public function emit(name:String, data:haxe.Rest<Any>) {
		final fnName = createName(name);
		if (this.subjects.exists(fnName)) {
			final x = [for (v in data) v];
			final fs = this.subjects.get(fnName);

			for(f in fs){
				if (f != null && f.subject != null) {
					f.subject.on_next(x);
				}
			}

			Lambda.iter(fs, (f)->{
				if (f.once) {
					f.subject.unsubscribe();
					for(l in this.listeners.get(fnName)){
						if(l == f.handler){
							this.listeners.get(fnName).remove(l);
						}
					}
				}
			});
			
		}
	}

	public function on(name:String, handler:(data:Array<Any>) -> Void, once:Bool = false) {
		final fnName = createName(name);
		if (!this.subjects.exists(fnName)) {
			this.subjects.set(fnName, [{subject: Subject.create(), once: once, handler: handler}]);
		}
		if(!this.listeners.exists(fnName)) listeners.set(fnName, []);
		final fs = this.subjects.get(fnName);
		final sub = Subject.create();
		sub.subscribe(Observer.create(null, null, handler));
		fs.push({subject: sub, once: once, handler: handler});
		listeners.get(fnName).push(handler);
	}

	public function once(name:String, handler:(data:Array<Any>) -> Void) {
		return on(name, handler, true);
	}

	public function removeAllListeners() {
		for (k => v in this.subjects) {
			Lambda.iter(v, (f)->{
				f.subject.unsubscribe();
			});
			this.subjects.remove(k);
		}
	}

	public function removeListener(name:String, handler:(data:Array<Any>) -> Void){
		final fnName = createName(name);
		if(this.subjects.exists(fnName)){
			final fs = this.subjects[fnName];
			Lambda.iter(fs, (f)->{
				if(f.handler == handler){
					f.subject.unsubscribe();
					fs.remove(f);
				}
			});
		}
	}
}
