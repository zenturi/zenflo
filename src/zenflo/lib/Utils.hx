package zenflo.lib;

import haxe.Rest;
import haxe.macro.Context;
import haxe.macro.Type;

using haxe.macro.ExprTools;

// import thx.Timer;
function debounce(func:() -> Void, wait:Int, immediate:Bool = false) {
	var timeout:haxe.Timer = null;
	var timestamp:Float = 0;

	var result = null;

	function later() {
		var last = (haxe.Timer.stamp() - timestamp) * 1000;
		if ((last < wait) && (last >= 0)) {
			timeout = haxe.Timer.delay(later, Std.int(wait - last));
		} else {
			timeout = null;
			if (!immediate) {
				func();
			}
		}
	}

	return function after() {
		timestamp = haxe.Timer.stamp();
		final callNow:Bool = immediate && timeout == null;
		if (timeout == null) {
			timeout = haxe.Timer.delay(later, wait);
		}
		if (callNow) {
			func();
		}
	};
}

macro function deflate(fun:haxe.macro.Expr) {
	var type = haxe.macro.Context.typeof(fun);
	final paramsAndRet = extractFunction(type);
	final paramNames:Array<Dynamic> = paramsAndRet[0];
	final isPromise = paramsAndRet[1];

    // extract default param values 
    switch  fun.expr {
        case EFunction(f, m):{
            for(a in m.args){
                for(p in paramNames){
                    if(p.name == a.name){
                        if(a.value != null){
                            switch (a.value.expr){
                                case EConst(c):{
                                    switch(c){
                                        case CString(v, _):{
                                            p.options.Default = v;
                                        }
                                        case CFloat(f): {
                                            p.options.Default = Std.parseFloat(f);
                                        }
                                        case CInt(i):{
                                            p.options.Default = Std.parseInt(i);
                                        }
                                        case _: throw "unsupported constant value for default parameter";
                                    }
                                }
                                case _:
                            }
                        }
                    }
                }
            }
        }
        case _:
    }

	return macro $a{[${fun}, $v{paramNames}, $v{isPromise}]};
}

function extractFunction(type):Array<Dynamic> {
	return switch type {
		case TFun(args, ret): {
				var paramNames:Array<Dynamic> = [];
				for (p in args) {
					final portOptions = {required: true, "Default": null};
					portOptions.required = !p.opt;
                    // portOptions.Default = p.opt;
					final pName = p.name;
					final v = {name: pName, options: portOptions};
					paramNames.push(v);
				}

				var resIsPromise = false;

				switch ret {
					case TInst(t, _): {
							final p = t.get();
							var pName = p.name;
							var pPath = p.pack.join(".");

							if (pPath + "." + pName == "tink.core.Promise") {
								// Result is a tink.core.Promise, resolve and handle
								resIsPromise = true;
							} else {
								resIsPromise = false;
							}
						}
					case TAbstract(t, _): {
							final p = t.get();
							var pName = p.name;
							var pPath = p.pack.join(".");

							if (pPath + "." + pName == "tink.core.Promise") {
								// Result is a tink.core.Promise, resolve and handle
								resIsPromise = true;
							} else {
								resIsPromise = false;
							}
						}
					case _: resIsPromise = false;
				};

				var body:Array<Dynamic> = [paramNames, resIsPromise];
				return body;
			}
		case _: {throw "unable to extract function information";};
	}
}
