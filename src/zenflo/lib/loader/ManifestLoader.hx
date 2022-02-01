package zenflo.lib.loader;

import zenflo.lib.runtimes.HScriptRuntime;
import tink.core.Future;
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
	type:String,
	addressible:Bool,
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

	function register(loader:ComponentLoader, callback:(err:tink.core.Error) -> Void) {
		if (loader.options != null ? loader.options.cache != null : false) {}
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

		return Lambda.fold(options.runtimes,
			(runtime,
					chain:Promise<Array<ManifestModule>>) -> chain.next((currentList) -> runtimes.get(runtime)
					.list(baseDir, options)
					.next((result) -> currentList.concat(result))),
			Promise.resolve([]))
			.next((results) -> {
				// Flatten
				var modules:Array<ManifestModule> = [];
				for (r in results)
					modules.concat([r]);

				if (!options.recursive) {
					return Promise.resolve(modules);
				}

				return Lambda.fold(options.runtimes,
					(runtime,
							chain:Promise<Array<String>>) -> chain.next((currentList) -> runtimes.get(runtime)
							.listDependencies(baseDir, options)
							.next((result) -> currentList.concat(result))),
					Promise.resolve([]))
					.next((deps) -> Lambda.fold(deps,
						(dep,
								depChain:Promise<Array<ManifestModule>>) -> depChain.next((currentList) -> manifestlist(dep,
								options).next((subDeps) -> currentList.concat(subDeps))),
						Promise.resolve([])))
					.next((subDeps) -> {
						var subs = [];
						for (s in subDeps)
							subs.concat([s]);
						modules = modules.concat(subs);
						return modules;
					});
			});
	}

	function list(loader:ComponentLoader, options:ManifestOptions, callback:(err:tink.core.Error, modules:Array<ManifestModule>) -> Void):Void {
		final opts = options;
		opts.discover = true;
		manifestlist(loader.baseDir, opts).next((modules) -> new Promise((resolve, reject) -> {
			registerModules(loader, modules, (err) -> {
				if (err != null) {
					reject(err);
					return;
				}

				resolve(modules);
			});
			return null;
		}).handle((cb) -> {
			switch cb {
				case Success(modules): {
						callback(null, modules);
					}
				case Failure(failure): {
						callback(failure, null);
					}
			}
		}));
	}

	function registerModules(loader:ComponentLoader, modules:Array<ManifestModule>, callback:(err:Error) -> Void):Void {
		Promise.inParallel(modules.map((m) -> {
			if (m.icon != null) {
				loader.setLibraryIcon(m.name, m.icon);
			}
			// if(m.zenflo != null && m.zenflo["loader"] != null){
			// Todo: 3rd party custom loaders
			// }
			return Promise.inParallel(m.components.map((c) -> new Promise((resolve, reject) -> {
				final language = Path.extension(c.path);
				if (language == "hscript" /* && language == "wren" && language == "lua" && language == "cppia"*/) {
					#if sys
					final source = File.getContent(Path.join([loader.baseDir, c.path]));
					return loadAndRegisterModuleSource(loader, m, c, source, language).handle((cb) -> {
						switch cb {
							case Success(data): {
									resolve(modules);
								}
							case Failure(err): {
									reject(err);
								}
						}
					});
					#end
					// Todo, browser loader for components
				}
				reject(new Error("Unsupported component language"));
				return null;
			})));
		}));
	}

	function readCache(loader:ComponentLoader, manifestOptions:ManifestOptions):Promise<ManifestDocument> {
		manifestOptions.discover = true;
		return load(loader.baseDir, manifestOptions);
	}

	function writeCache(loader:ComponentLoader, options:ManifestOptions, manifestContents:ManifestDocument):Promise<ManifestDocument> {
		final manifestName = options.manifest != null ? options.manifest : 'fbp.json';
		final contents = Json.stringify(manifestContents, null, "  ");
		#if sys
		try {
			final filePath = Path.join([loader.baseDir, manifestName]);
			final writer = File.write(filePath, false);
			writer.writeString(contents, Encoding.UTF8);
		} catch (e) {
			final log = new DebugComponent("zenflo:io");
			log.Error('Unable to write manifest cache : $e');
		}
		return Promise.resolve(manifestContents);
		#elseif js.Syntax.code
		("localStorage.setItem('zenflo-manifest-cache', {0})", contents);
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
		final c = new Component({
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
		var interp = new hscript.Interp();
		final exp = parser.parseString(source);

		c.process((input, output, _) -> {
			var proc = {
				"input": input,
				"output": output
			};

			interp.variables.set("Process", proc);
			interp.variables.set("Array", Array);
			interp.variables.set("DateTools", DateTools);
			interp.variables.set("Math", Math);
			interp.variables.set("StringTools", StringTools);
			#if sys
			interp.variables.set("Sys", Sys);
			#end
			interp.variables.set("Xml", Xml);
			#if sys
			interp.variables.set("sys", {
				"FileSystem": sys.FileSystem,
				"io": {
					"File": sys.io.File
				},
				"net": {
					"Host": sys.net.Host
				}
			});
			#end
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
		});

		loader.registerComponent(module.name, component.name, (_) -> c, (err) -> {
			if (err != null) {
				reject(err);
				return;
			}
			resolve(Noise);
		});
	}
}
