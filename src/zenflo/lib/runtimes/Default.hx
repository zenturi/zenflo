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

	function getModuleInfo(baseDir:String, options:ManifestOptions):Promise<ManifestModule> {
		final packageFile = Path.join([baseDir, 'package.json']);
		var packageData:ManifestModule = {};
		try {
			final f = File.getContent(packageFile);
			packageData = Json.parse(f);
		} catch (e) {
			return Promise.reject(new Error(e.toString()));
		}

		if (packageData == null) {
			packageData = {
				name: Path.withoutDirectory(baseDir),
				description: null,
			};
		}

		final module:ManifestModule = {
			name: packageData.name,
			description: packageData.description,
		};

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

		return Promise.resolve(module);
	}

	function listComponents(componentDir:String, options:ManifestOptions):Promise<Array<ManifestComponent>> {
		final entries = FileSystem.readDirectory(componentDir);
		final potentialComponents = entries.filter((c) -> ['.hscript', '.wren', '.lua', '.cppia'].contains(Path.extension(c)));

		return Promise.inParallel(potentialComponents.map((p) -> new Promise((resolve, reject) -> {
			final componentPath = Path.join([componentDir, p]);
			if (FileSystem.isDirectory(componentPath)) {
				resolve(componentPath);
			}
			reject(null);
			return null;
		}))).next((potential) -> {
			return potential.filter((p) -> Std.isOfType(potential, String));
		}).next((potential) -> {
			final components = Lambda.fold(potential, (localPath, current:Array<ManifestComponent>) -> {
				final p = /** @type {string} */ (localPath);
				final componentPath = Path.join([componentDir, p]);
				final component:ManifestComponent = {
					name: null,
					path: Path.join([Path.directory(options.root != null ? options.root : ''), componentPath]),
					source: Path.join([Path.directory(options.root != null ? options.root : ''), componentPath]),
					elementary: true,
				};
                try {
                    final source = File.getContent(componentPath);
                    component.name = parseId(source, componentPath);
                    component.runtime = parsePlatform(source);
                } catch (e){
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
				if (!FileSystem.isDirectory(d)) {
					return Promise.resolve([]);
				}
				return listComponents(componentDir, options);
			});

			var f = Promise.iterate(flat, (p) -> {
				return Some(p);
			}, Promise.resolve(components));

			return f;
		})
        .next((components)-> components.filter((c)-> supportedRuntimes.contains(c.runtime)))
        .mapError((err)->{
            if(err.message == "IO Error"){
                return null;
            }
            return err;
        });
	}

	public function list(componentDir:String, options:ManifestOptions):Promise<Array<ManifestModule>> {
		throw new haxe.exceptions.NotImplementedException();
	}

	public function listDependencies(componentDir:String, options:ManifestOptions):Promise<Array<String>> {
		throw new haxe.exceptions.NotImplementedException();
	}
}
