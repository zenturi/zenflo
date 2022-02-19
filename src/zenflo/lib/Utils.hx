package zenflo.lib;

import haxe.Rest;

// import thx.Timer;
function debounce(func:() -> Void, wait:Int, immediate:Bool = false) {
	var timeout:haxe.Timer = null;
	var timestamp:Float = 0;

	var result = null;

	function later() {
		var last = haxe.Timer.stamp() - timestamp;
		if ((last < wait) && (last >= 0)) {
			timeout = haxe.Timer.delay(later, Std.int(wait - (last/1000)));
		} else {
			timeout = null;
			if (!immediate) {
				func();
			}
		}
	}

	return function after() {
		timestamp = haxe.Timer.stamp();
		final callNow = immediate && timeout == null;
		if (timeout == null) {
			timeout = haxe.Timer.delay(later, wait);
		}
		if (callNow != null) {
			func();
		}
	};
}
