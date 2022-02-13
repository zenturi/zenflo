package zenflo.lib;

using haxe.macro.ExprTools;

/**
	## asComponent generator API

	asComponent is a macro for turning Haxe functions into
	ZenFlo components.

	All input arguments become input ports, and the function's
	result will be sent to either `out` or `error` port.

	```
		using zenflo.lib.Macros.*;

		final random = asComponent(Math.random, {
			description: 'Generate a random number'
		});
	```
**/

macro function asComponent(fun:haxe.macro.Expr, ?options:haxe.macro.Expr) {
	return switch fun.expr {
		case EFunction(kind, f): {
				var args = f.args;
				var paramNames:Array<Dynamic> = [];
				for (p in args) {
					final portOptions = {required: true};
					portOptions.required = !p.opt;

					final pName = p.name;
					final v = {name: pName, options: portOptions};
					paramNames.push(v);
				}

			
				var resIsPromise = macro false;

				switch f.ret {
					case TPath(p): {
							var pName = p.name;
							var pPath = p.pack.join(".");

							trace(pPath);

							if (pPath + "." + pName == "tink.core.tink.core.Promise") {
								// Result is a tink.core.Promise, resolve and handle
								resIsPromise = macro true;
							} else {
								resIsPromise = macro false;
							}
						}
					case _: resIsPromise = macro false;
				};

				var body = macro {
					final pNames = $v{paramNames}; // [for(x in ) {name:${x.name}, options: ${x.options}}];
					var c = new zenflo.lib.Component($options);

					for (p in pNames) {
						c.inPorts.add(p.name, p.options);
						c.forwardBrackets[p.name] = ['out', 'error'];
					}
					if (pNames.length == 0) {
						c.inPorts.add('in', {datatype: 'bang'});
					}
					c.outPorts.add('out');
					c.outPorts.add('error');

					c.process((input:zenflo.lib.ProcessInput, output:zenflo.lib.ProcessOutput, _) -> {
						var values:Array<String> = [];
						if (pNames.length != 0) {
							var params:haxe.Rest<String> = [for(p in pNames) p.name];
							if (!input.hasData(params)) {
								return null;
							}
							values = pNames.map((p) -> input.getData(p));
						} else {
							if (!input.hasData('in')) {
								return null;
							}
							input.getData('in');
							values = [];
						}

						// var isPromise = ${resIsPromise};

						// switch values.length
						var func:Dynamic = ${fun}.bind();

						var res:Dynamic = Reflect.callMethod(func, func, values);
						if (Type.getClassName(Type.getClass(res)) == "tink.core.FutureTrigger") {
							res.handle(_c -> {
								switch _c {
									case tink.core.Outcome.Success(v): {
											output.sendDone(v);
										}
									case tink.core.Outcome.Failure(err): {
											output.done(err);
										}
								}
							});
						} else {
							output.sendDone(res);
						}

						return null;
					});
					return c;
				};
				// trace(body.toString());
				return body;
			}
		case _: macro {throw "unable to generate Component from Function";};
	}
}


function asPromise(component:Dynamic, options:Dynamic):tink.core.Promise<Dynamic> {
	return null;
}
