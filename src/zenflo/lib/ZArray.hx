package zenflo.lib;

import polygonal.ds.tools.GrowthRate;
import polygonal.ds.ArrayList;
import haxe.ds.List;
// using polygonal.ds.tools.NativeArrayTools;

@:forward
@:arrayAccess
abstract ZArray<T>(ArrayList<T>) from ArrayList<T> to ArrayList<T> {
    public function new() {
        this = new ArrayList<T>(1024, [], false);
        this.growthRate = GrowthRate.DOUBLE;
    }

    @:from
    public static inline function fromArray<T>(a:Array<T>):ZArray<T> {
        var ret = (new ArrayList<T>(a.length * 2, a));
        // ret.addArray(a);
        ret.growthRate = GrowthRate.DOUBLE;
        return ret;
    }

    @:from
    public static inline function fromList<T>(a:List<T>):ZArray<T> {
        var ret = (new ArrayList<T>(a.length * 2));
        for(x in a) ret.add(x);
        ret.growthRate = GrowthRate.DOUBLE;
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
