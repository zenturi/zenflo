package zenflo.lib.loader;

import zenflo.lib.runtimes.HScriptRuntime;
import tink.core.Future;
import tink.core.Promise;
import tink.core.Noise;
import tink.core.Noise.Never;
import zenflo.lib.Component.ErrorableCallback;
import zenflo.lib.runtimes.Default;
import zenflo.lib.loader.Loaders.RegisterLoader;
import tink.core.Error;
import haxe.io.Encoding;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import haxe.io.Path;
import haxe.DynamicAccess;
import zenflo.lib.Component.DebugComponent;

typedef ManifestModule = {
	?name:String,
	?description:String,
	?runtime:String,
	?base:String,
	?icon:String,
	?components:Array<ManifestComponent>,
	?graphs:Array<ManifestComponent>,
	?zenflo:DynamicAccess<Dynamic>
}

typedef ManifestComponent = {
	name:String,
	?description:String,
	?runtime:String,
	?path:String,
	?source:String,
	?tests:String,
	?exec:String,
	?elementary:Bool,
	?inports:Array<ManifestPort>,
	?outports:Array<ManifestPort>
}

typedef ManifestPort = {
	name:String,
	?description:String,
	?type:String,
	?dataType:String,
	?addressible:Bool,
	?control:Bool,
	?required:Bool
}

typedef ManifestOptions = {
	?runtimes:Array<String>,
	?root:String,
	?manifest:String,
	?baseDir:String,
	?subdirs:Bool,
	?recursive:Bool,
	?discover:Bool,
	?silent:Bool
}

typedef ManifestDocument = {
	version:Int,
	modules:Array<ManifestModule>
}

final runtimes:Map<String, Runtime> = ["zenflo" => new DefaultRuntime()];

class ManifestLoader {
	function new() {
		RegisterLoader.register = this.register;
	}

	public static function init():ManifestLoader {
		return new ManifestLoader();
	}

	function register(loader:ComponentLoader, callback:(err:tink.core.Error, modules:Array<Dynamic>) -> Void) {
		final manifestOptions = prepareManifestOptions(loader);
		if (loader.options != null ? loader.options.cache != null : false) {
			this.listComponents(loader, manifestOptions, (err, modules) -> {
				if (err != null) {
					callback(err, []);
					return;
				}
				zenflo.lib.loader.Loaders.registerSubgraph(loader);
				callback(null, modules);
			});
		}

		
		list(loader, manifestOptions, (err, modules) -> {
			if (err != null) {
				callback(err, []);
				return;
			}
			
			zenflo.lib.loader.Loaders.registerSubgraph(loader);
			callback(null, modules);
		});
	}

	function prepareManifestOptions(loader:ComponentLoader) {
		final l = loader;
		if (l.options == null) {
			l.options = {};
		}
		final options:ManifestOptions = {
			runtimes: new Array<String>(),
			recursive: false,
			manifest: ""
		};
		options.runtimes = l.options.runtimes != null ? l.options.runtimes : [];

		if (options.runtimes.indexOf('zenflo') == -1) {
			options.runtimes.push('zenflo');
		}
		options.recursive = l.options.recursive == null ? true : l.options.recursive;
		options.manifest = l.options.manifest != null ? l.options.manifest : 'fbp.json';

		return options;
	}

	function load(baseDir:String, options:ManifestOptions):Promise<ManifestDocument> {
		if (options.discover == null) {
			options.discover = true;
		}
		if (options.manifest == null) {
			options.manifest = 'fbp.json';
		}

		#if sys
		try {
			final manifestPath = Path.join([baseDir, options.manifest]);
			final contents = File.getContent(manifestPath);
			return Promise.resolve(Json.parse(contents));
		} catch (e) {
			final log = new DebugComponent("zenflo:io");
			log.Error('Unable to load manifest : $e');
			return Promise.reject(new Error('Unable to load manifest : $e'));
		}
		#end
		return null;
	}

	function manifestlist(baseDir:String, options:ManifestOptions):Promise<Array<ManifestModule>> {
		if (options.root == null) {
			options.root = baseDir;
		}

		if (options.subdirs == null) {
			options.subdirs = true;
		}

		if (!(options.runtimes != null ? options.runtimes.length > 0 : false)) {
			return Promise.reject(new Error('No runtimes specified'));
		}

		final missingRuntimes = options.runtimes.filter((r) -> !runtimes.exists(r));
		if (missingRuntimes.length > 0) {
			return Promise.reject(new Error('Unsupported runtime types: ${missingRuntimes.join(', ')}'));
		}

		return new Promise((resolve, reject) -> {
			final currentList = [];
			for (runtime in options.runtimes) {
				runtimes[runtime].list(baseDir, options).next((result) -> {
					return currentList.concat(result);
				}).handle((cb) -> {
					switch (cb) {
						case Success(results): {
								// Flatten
								var modules:Array<ManifestModule> = [];
								for (r in results)
									modules = modules.concat([r]);

								if (!options.recursive) {
									resolve(modules);
									return;
								}

								final currentList = [];
								for (runtime in options.runtimes) {
									runtimes[runtime].listDependencies(baseDir, options).next((result) -> {
										return currentList.concat(result);
									}).handle((cb) -> {
										switch cb {
											case Success(deps): {
													if(deps.length == 0){
														resolve(modules);
														return;
													}
													final currentList = [];
													for (dep in deps) {
														manifestlist(dep, options).next((subDeps) -> currentList.concat(subDeps)).handle((cb) -> {
															switch cb {
																case Success(subDeps): {
																		var subs = [];
																		for (s in subDeps)
																			subs.concat([s]);
																		modules = modules.concat(subs);
																
																		resolve(modules);
																	}
																case Failure(err): {
																		reject(err);
																	}
															}
														});
													}
												}
											case Failure(err): {
													reject(err);
												}
										}
									});
								}
							}
						case Failure(err): {
								reject(err);
							}
					}
				});
			}

			return null;
		});
	}

	function list(loader:ComponentLoader, options:ManifestOptions, callback:(err:tink.core.Error, modules:Array<ManifestModule>) -> Void):Void {
		final opts = options;
		opts.discover = true;
		manifestlist(loader.baseDir, opts).handle((cb) -> {
			switch cb {
				case Success(modules): {
						registerModules(loader, modules, (err) -> {
							if (err != null) {
								callback(err, null);
								return;
							}
							callback(null, modules);
						});
					}
				case Failure(err): {
						callback(err, null);
					}
			}
		});
	}

	function registerModules(loader:ComponentLoader, modules:Array<ManifestModule>, callback:(err:Error) -> Void):Void {
		final componentLoaders = [];
		if(modules.length == 0) {
			callback(null);
			return;
		}
		Promise.inParallel(modules.map((m) -> {
			if (m.icon != null) {
				loader.setLibraryIcon(m.name, m.icon);
			}
			if (m.zenflo != null && m.zenflo["loader"] != null) {
				final loaderPath = Path.join([loader.baseDir, m.base, m.zenflo["loader"]]);
				componentLoaders.push(loaderPath);
			}
			return Promise.inParallel(m.components.map((c) -> new Promise((resolve, reject) -> {
				final language = Path.extension(c.path);
				if (language == "hscript" /* && language == "wren" && language == "lua" && language == "cppia"*/) {
					#if (sys || hxnodejs)
					#if sys
					final source = File.getContent(Path.join([loader.baseDir, c.path]));
					#else
					final source = js.node.Fs.readFileSync(Path.join([loader.baseDir, c.path]), 'utf8');
					#else
					throw new Error('no support for module on this target');
					#end
					return loadAndRegisterModuleSource(loader, m, c, source, language).handle((cb) -> {
						switch cb {
							case Success(data): {
									resolve(modules);
									callback(null);
								}
							case Failure(err): {
									reject(err);
									callback(err);
								}
						}
					});
					#end
					// Todo, browser loader for components
				}

				// reject(new Error("Unsupported component language"));
				return null;
			})));
		})).handle((cb) -> {
			switch cb {
				case Success(_): {
						registerCustomLoaders(loader, componentLoaders, callback);
					}
				case Failure(err): {
						callback(err);
					}
			}
		});
	}

	function registerCustomLoaders(loader:ComponentLoader, componentLoaders:Array<String>, callback:(err:Error) -> Void) {
		Lambda.fold(componentLoaders, (componentLoader:String, chain:Promise<Any>) -> {
			return chain.next((_) -> {
				return new Promise((resolve, reject) -> {
					if (Path.extension(componentLoader) == 'hscript') {
						#if (sys || hxnodejs)
						#if sys
						final source = File.getContent(Path.join([loader.baseDir, componentLoader]));
						#else
						final source = js.node.Fs.readFileSync(Path.join([loader.baseDir, componentLoader]), 'utf8');
						#end
						#else
						throw new Error('no method supported for custom loader on this target');
						#end

						final parser = new hscript.Parser();
						parser.allowJSON = true;
						var interp = new hscript.Interp();
						final exp = parser.parseString(source);

						final loaderFunction = (loader:ComponentLoader, callback:(err:Error) -> Void) -> {
							interp.variables.set("Loader", loader);
							interp.variables.set("done", callback);
							interp.variables.set("Array", Array);
							interp.variables.set("DateTools", DateTools);
							interp.variables.set("Math", Math);
							interp.variables.set("StringTools", StringTools);
							#if (sys || hxnodejs)
							interp.variables.set("Sys", Sys);
							#end
							interp.variables.set("Xml", Xml);
							interp.variables.set("Json", haxe.Json);
							interp.variables.set("Http", haxe.Http);
							interp.variables.set("Serializer", haxe.Serializer);
							interp.variables.set("Unserializer", haxe.Unserializer);
							final log = new DebugComponent('zenflo:CustomLoader');
							interp.variables.set("log", log);

							interp.execute(exp);
						};

						loader.registerLoader(loaderFunction, (err) -> {
							if (err != null) {
								reject(err);
								return;
							}
							resolve(Noise);
						});
					}

					return null;
				});
			});
		}, Promise.resolve(null));
	}

	function readCache(loader:ComponentLoader, manifestOptions:ManifestOptions):Promise<ManifestDocument> {
		manifestOptions.discover = true;
		return load(loader.baseDir, manifestOptions);
	}

	function writeCache(loader:ComponentLoader, options:ManifestOptions, manifestContents:ManifestDocument):Promise<ManifestDocument> {
		final manifestName = options.manifest != null ? options.manifest : 'fbp.json';
		final contents = Json.stringify(manifestContents, null, "  ");
		#if (sys || hxnodejs)
		try {
			final filePath = Path.join([loader.baseDir, manifestName]);
			#if sys
			final writer = File.write(filePath, false);
			writer.writeString(contents, Encoding.UTF8);
			#else
			js.node.Fs.writeFileSync(filePath, contents);
			#end
		} catch (e) {
			final log = new DebugComponent("zenflo:io");
			log.Error('Unable to write manifest cache : $e');
		}
		return Promise.resolve(manifestContents);
		#elseif (!sys || !hxnodejs)
		js.Syntax.code("localStorage.setItem('zenflo-manifest-cache', {0})", contents);
		return Promise.resolve(manifestContents);
		#end

		return Promise.reject(new Error("Cache write not supported on this platform"));
	}

	function listComponents(loader:ComponentLoader, manifestOptions:ManifestOptions, callback:(err:tink.core.Error, modules:Array<ManifestModule>) -> Void) {
		this.readCache(loader, manifestOptions)
			.recover((err) -> {
				if (!loader.options.discover) {
					return null;
				}

				return cast new Promise<Array<ManifestModule>>((resolve, reject) -> {
					list(loader, manifestOptions, (err2, modules) -> {
						if (err2 != null) {
							reject(err2);
							return;
						}
						resolve(modules);
					});
					return null;
				}).next((modules) -> {
					final manifestContents:ManifestDocument = {
						version: 1,
						modules: modules,
					};

					return this.writeCache(loader, manifestOptions, manifestContents).next((_) -> manifestContents);
				});
			})
			.next((manifestContents) -> {
				registerModules(loader, manifestContents.modules, (err) -> {
					if (err != null) {
						callback(err, null);
						return;
					}
					callback(null, manifestContents.modules);
				});

				return null;
			})
			.mapError((err) -> {
				callback(err, null);
				return err;
			});
	}

	function loadAndRegisterModuleSource(loader:ComponentLoader, module:ManifestModule, component:ManifestComponent, source:String,
			language:String):Promise<Noise> {
		if (language == "hscript") {
			return new Promise((resolve, reject) -> {
				loader.sourcesForComponents.set('${module.name}/${component.name}', {
					source: source,
					language: language
				});
				// if(component.tests != null && ) {
				//     loader.specsForComponents.set('${module.name}/${component.name}', {

				//     });
				// }
				hscriptSourceLoader(loader, module, component, source, resolve, reject);
				return null;
			});
		}

		return Promise.NOISE;
	}

	function hscriptSourceLoader(loader:ComponentLoader, module:ManifestModule, component:ManifestComponent, source:String, resolve:Noise->Void,
			reject:Error->Void) {
		final c = new zenflo.lib.Component({
			description: component.description,
			icon: module.icon
		});

		for (n in component.inports) {
			c.inPorts.add(n.name, n);
		}
		for (out in component.outports) {
			c.outPorts.add(out.name, out);
		}

		final parser = new hscript.Parser();
		parser.allowJSON = true;
		var interp = new hscript.Interp();
		final exp = parser.parseString(source);

		c.process((input, output, context) -> {
			var proc = {
				"input": input,
				"output": output,
				"context": context
			};

			interp.variables.set("Process", proc);
			interp.variables.set("Array", Array);
			interp.variables.set("DateTools", DateTools);
			interp.variables.set("Math", Math);
			interp.variables.set("StringTools", StringTools);
			#if (sys || hxnodejs)
			interp.variables.set("Sys", Sys);
			#end
			interp.variables.set("Xml", Xml);
			// #if (sys || hxnodejs)
			// interp.variables.set("sys", {
			// 	"FileSystem": sys.FileSystem,
			// 	"io": {
			// 		"File": sys.io.File
			// 	},
			// 	"net": {
			// 		"Host": sys.net.Host
			// 	}
			// });
			// #end
			interp.variables.set("Json", haxe.Json);
			interp.variables.set("Http", haxe.Http);
			interp.variables.set("Serializer", haxe.Serializer);
			interp.variables.set("Unserializer", haxe.Unserializer);
			final log = new DebugComponent('zenflo:{${module.name}/${component.name}}');
			interp.variables.set("log", log);

			for (k => v in HScriptRuntime.variables) {
				interp.variables.set(k, v);
			}

			interp.execute(exp);

			return null;
		});

		loader.registerComponent(module.name, component.name, (_)-> c, (err) -> {
			if (err != null) {
				reject(err);
				return;
			}
			resolve(Noise);
		});
	}
}
