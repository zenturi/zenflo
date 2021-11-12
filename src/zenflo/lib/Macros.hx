package zenflo.lib;

import haxe.macro.Expr;
import tink.macro.Functions.*;
import tink.macro.Exprs.*;
import tink.macro.Types.*;

/**
	## asComponent generator API

	asComponent is a macro for turning Haxe functions into
	ZenFlo components.
**/
macro function asComponent(fun:haxe.Constraints.Function, options:ComponentOptions) {
	var fExpr:Expr = toExpr(fun);

	return switch fExpr.expr {
		case EFunction(kind, f): {
				var params = getArgIdents(f);
				var paramNames:Array<{name:String, options:{}}> = [];
				for (p in params) {
					final portOptions = {required: true};

					var pType = typeof(p);
					switch pType {
						case Success(data): {
								var complx = toComplex(data);
								switch complx {
									case TOptional(t): {
											portOptions.required = false;
										}
									case _:
								}
							}
						case _:
					}

					final pName = getName(p);
					switch pName {
						case Success(n): {
								paramNames.push({name: n, options: portOptions});
							}
						case _:
					}
				}
				var resIsPromise = false;
				switch f.ret {
					case TPath(p): {
							var pName = p.name;
							var pPath = p.pack.join(".");

							if (pPath + "." + pName == "tink.core.tink.core.Promise") {
								// Result is a tink.core.Promise, resolve and handle
								resIsPromise = true;
							} else {
								resIsPromise = false;
							}
						}
					case _: resIsPromise = false;
				};

				return macro {
					var c = new zenflo.lib.Component(options);

					for (p in paramNames) {
						c.inPorts.add(p.name, p.options);
						c.forwardBrackets[p.name] = ['out', 'error'];
					}
					if (params.length == 0) {
						c.inPorts.add('in', {datatype: 'bang'});
					}
					c.outPorts.add('out');
					c.outPorts.add('error');

					c.process((input, output, _) -> {
						var values:Array<String> = [];
						if (paramNames.length != 0) {
							for (p in paramNames) {
								if (!input.hasData(p.name)) {
									return tink.core.Promise.resolve(null);
								}
							}
							values = paramNames.map((p) -> input.getData(p));
						} else {
							if (!input.hasData('in')) {
								return tink.core.Promise.resolve(null);
							}
							input.getData('in');
							values = [];
						}

						var isPromise = $v{resIsPromise};
						

						if (isPromise){
							var res:tink.core.Promise<Dynamic> = $v{call(fExpr, params)};
							res.handle((_c)->{
								switch _c {
									case Success(v):{
										output.sendDone(v);
									}
									case Failure(err):{
										output.done(err);
									}
								}
							});
						} else {
							var res = $v{call(fExpr, params)};
							output.sendDone(res);
						}
					
						return tink.core.Promise.resolve(null);
					});
					return c;
				};
			}
		case _: macro { throw "unable to generate Component from Function"; };
	}
}



function asPromise(component:Dynamic, options:Dynamic):tink.core.Promise<Dynamic>{
	return null;
}