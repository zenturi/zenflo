package zenflo.lib;

import polygonal.ds.ArrayList;
import haxe.ds.List;
// using polygonal.ds.tools.NativeArrayTools;

@:forward
@:arrayAccess
abstract ZArray<T>(ArrayList<T>) from ArrayList<T> to ArrayList<T> {
    public function new() {
        this = new ArrayList<T>();
    }

    @:from
    public static inline function fromArray<T>(a:Array<T>):ZArray<T> {
        var ret = (new ArrayList<T>());
        ret.addArray(a);
        return ret;
    }

    @:from
    public static inline function fromList<T>(a:List<T>):ZArray<T> {
        var ret = (new ArrayList<T>());
        for(x in a) ret.add(x);
        return ret;
    }

    @:to 
    public inline function toArr():Array<T> {
        return this.toArray();
    }

    @:arrayAccess
    public function _get(i:Int):T {
        return this.get(i);
    }

    @:arrayAccess
    public function _set(i:Int, val:T) {
        this.set(i, val);
    }

    public function push(val:T) {
        this.add(val);
    }
}
