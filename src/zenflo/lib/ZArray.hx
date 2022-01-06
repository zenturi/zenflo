package zenflo.lib;

import polygonal.ds.ArrayList;


@:forward
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

    @:to 
    public function toArr():Array<T> {
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
