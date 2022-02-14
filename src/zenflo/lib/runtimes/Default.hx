package zenflo.lib.runtimes;

import zenflo.lib.runtimes.Utils.parsePlatform;
import zenflo.lib.runtimes.Utils.parseId;
import sys.FileSystem;
import haxe.Json;
import tink.core.Error;
import sys.io.File;
import haxe.io.Path;
import zenflo.lib.loader.ManifestLoader;
import tink.core.Option;
import haxe.DynamicAccess;

using StringTools;

interface Runtime {
	public function list(componentDir:String, options:ManifestOptions):Promise<Array<ManifestModule>>;
	public function listDependencies(componentDir:String, options:ManifestOptions):Promise<Array<String>>;
}

class DefaultRuntime implements Runtime {
	public function new() {}

	final supportedRuntimes = [
		'zenflo',
		// 'zenflo-browser',
		// 'zenflo-android',
		// 'zenflo-ios',
		// 'zenflo-openfl',
		// 'zenflo-clay',
		// 'zenflo-heaps',
		// 'zenflo-kha',
	];

	function getModuleInfo(baseDir:String, options:ManifestOptions):ManifestModule {
		final packageFile = Path.join([baseDir, 'package.json']);
		var packageData:ManifestModule = {};
		final f = File.getContent(packageFile);
		packageData = Json.parse(f);

		if (packageData == null) {
			packageData = {
				name: Path.withoutDirectory(baseDir),
				description: null,
			};
		}

		final module:ManifestModule = packageData;

		if (packageData.zenflo != null ? packageData.zenflo["icon"] != null : false) {
			module.icon = packageData.zenflo["icon"];
		}

		if (packageData.zenflo != null ? packageData.zenflo["loader"] != null : false) {
			if (module.zenflo == null) {
				module.zenflo = {};
			}
			module.zenflo["loader"] = packageData.zenflo["loader"];
		}

		if (module.name == 'zenflo') {
			module.name = '';
		}
		if (module.name.charAt(0) == '@') {
			final re = ~/@[a-z-]+\//;
			module.name = re.replace(module.name, '');
		}
		module.name = module.name.replace('zenflo-', '');
		return module;
	}

	function listComponents(componentDir:String, options:ManifestOptions):Promise<Array<ManifestComponent>> {
		if(!FileSystem.exists(componentDir)) return Promise.resolve([]);
		final entries = FileSystem.readDirectory(componentDir);

		final potentialComponents = entries.filter((c) -> ['hscript', 'wren', 'lua', 'cppia'].contains(Path.extension(c)));
		// final directoryComponents = entries.filter((entry) -> FileSystem.isDirectory(Path.join([componentDir, entry])));
		return Promise.inParallel(potentialComponents.map((p) -> new Promise((resolve, reject) -> {
			final componentPath = Path.join([componentDir, p]);
			if (!FileSystem.isDirectory(componentPath)) {
				resolve(componentPath);
				return null;
			}
			reject(null);
			return null;
		})))
			.next((potential) -> {
				return potential.filter((p) -> Std.isOfType(p, String));
			})
			.next((potential) -> {
				final components = Lambda.fold(potential, (localPath, current:Array<ManifestComponent>) -> {
					final p = /** @type {string} */ (localPath);
					final componentPath = p;

					final root = (options.root != null ? options.root : '').replace(Sys.getCwd(), "");

					final directory = Path.directory(localPath);

					final script = p.replace(Sys.getCwd(), "").replace(root, "");

					var component:ManifestComponent = {
						name: null,
						path: script,
						source: script,
						elementary: true,
					};

					if (FileSystem.exists(Path.join([directory, 'package.json']))) {
						final packageFile = Path.join([directory, 'package.json']);
						var packageData:ManifestComponent = null;
						final f = File.getContent(packageFile);
						packageData = Json.parse(f);
						component = packageData;
					}

					try {
						final source = File.getContent(componentPath);
						component.name = parseId(source, componentPath);
						component.runtime = parsePlatform(source);
					} catch (e) {
						throw new Error("IO Error");
					}

					if (['all', null].contains(component.runtime)) {
						// Default to ZenFlo on any platform
						component.runtime = 'zenflo';
					}
					return current.concat([component]);
				}, []);

				final potentialDirs = entries.filter((entry) -> !potentialComponents.contains(entry));
				
				if (potentialDirs.length == 0) {
					return Promise.resolve(components);
				}

				if (options.subdirs == null) {
					return Promise.resolve(components);
				}

				// Seek from subdirectories
				final flat = potentialDirs.map((d) -> {
					if (!FileSystem.isDirectory(Path.join([componentDir, d]))) {
						return Promise.resolve(components);
					}
					return listComponents(Path.join([componentDir, d]), options);
				});

				var f = Promise.iterate(flat, (p) -> {
					return Some(p);
				}, Promise.resolve(components));

				return f;
			})
			.next((components) -> components.filter((c) -> supportedRuntimes.contains(c.runtime)))
			.mapError((err) -> {
				if (err.message == "IO Error") {
					return null;
				}
				return err;
			});
	}

	public function list(componentDir:String, options:ManifestOptions):Promise<Array<ManifestModule>> {
		final module = getModuleInfo(componentDir, options);
		return Promise.inParallel([
			listComponents(Path.join([componentDir, "components/"]), options).next((components) -> components),
			listGraphs(Path.join([componentDir, "components/"]), options).next((graphs) -> graphs)
		]).next((stack) -> {
			final components = stack[0];
			final graphs = stack[1];

			return {
				module: module,
				components: components,
				graphs: graphs
			};
		}).next(manifest -> {
			final module = manifest.module;
			if (module == null) {
				return [];
			}
			final graphs = manifest.graphs;
			final components = manifest.components;
			final runtimes:DynamicAccess<Array<ManifestComponent>> = {};

			Lambda.iter(components, (component) -> {
				if (runtimes[component.runtime] == null) {
					runtimes[component.runtime] = [];
				}
				runtimes[component.runtime].push(component);
				// component.runtime = null;
			});
			Lambda.iter(graphs, (component) -> {
				if (runtimes[component.runtime] == null) {
					runtimes[component.runtime] = [];
				}
				runtimes[component.runtime].push(component);
				// component.runtime = null;
			});
			final modules:Array<ManifestModule> = [];

			Lambda.iter(runtimes.keys(), (k) -> {
				final v = runtimes[k];
				modules.push({
					name: module.name,
					description: module.description,
					runtime: k,
					zenflo: module.zenflo,
					base: componentDir,
					icon: module.icon,
					components: v,
				});
			});

			if ((graphs.length == 0) && (components.length == 0) && (module.zenflo != null ? module.zenflo["loader"] != null : false)) {
				// Component that only provides a custom loader, register for "noflo"
				modules.push({
					name: module.name,
					description: module.description,
					runtime: 'zenflo',
					zenflo: module.zenflo,
					base: componentDir,
					icon: module.icon,
					components: [],
				});
			}
			return modules;
			// Todo: listSpecs
		});
	}

	function listGraphs(componentDir:String, options:ManifestOptions):Promise<Array<ManifestComponent>> {
		return Promise.resolve([]);
	}

	public function listDependencies(componentDir:String, options:ManifestOptions):Promise<Array<String>> {
		return Promise.resolve([]);
	}
}
