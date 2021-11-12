package zenflo.lib;

import haxe.Rest;
import thx.Timer;

function debounce(func:()->Void, wait:Int, immediate:Bool = false) {
    return Timer.debounce(func, wait, immediate);
}