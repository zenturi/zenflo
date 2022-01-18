package zenflo.lib;

import zenflo.lib.Component;
import haxe.Constraints.Function;
import haxe.ds.Either;
import zenflo.lib.Component.ErrorableCallback;
import haxe.ds.StringMap;
import haxe.DynamicAccess;
import tink.core.Promise;
import zenflo.graph.GraphNodeMetadata;
import tink.core.Error;
import zenflo.lib.loader.Loaders.RegisterLoader;
import zenflo.graph.Graph;

typedef ComponentList = DynamicAccess<Dynamic>;

@:structInit
class ComponentSources {
	public var name:String = null;
	public var library:String = null;
	public var code:String = null;
	public var language:String = null;
	public var tests:String = null;
}

typedef ComponentLoaderOptions = {
	?cache:Bool,
	?discover:Bool,
	?recursive:Bool,
	?runtimes:Array<String>,
	?manifest:String
};

typedef ComponentLoadCallback = (err:Error, component:Component) -> Void;

/**
	## The ZenFlo Component Loader

	The Component Loader is responsible for discovering components
	available in the running system, as well as for instantiating
	them.

	Internally the loader uses a registered, platform-specific
	loader. ZenFlo discovers
	components from the current project's `components/` and
	`graphs/` folders. For browsers it would attempt to fetch the components from a network.
**/
class ComponentLoader {
	public function new(baseDir:String, ?options:ComponentLoaderOptions) {
		this.baseDir = baseDir;
		this.options = options;
		/** @type {ComponentList|null} */
		this.components = null;
		/** @type {Object<string, string>} */
		this.libraryIcons = new StringMap<String>();
		/** @type {Object<string, Object>} */
		this.sourcesForComponents = new StringMap<Dynamic>();
		/** @type {Object<string, string>} */
		this.specsForComponents = new StringMap<String>();
		/** @type {Promise<ComponentList> | null}; */
		this.processing = null;
		this.ready = false;
	}

	public function listComponents():Promise<ComponentList> {
		var promise = null;
		
		if (this.processing != null) {
			promise = this.processing;
		} else if (this.ready && this.components != null) {
			promise = Promise.resolve(this.components);
		} else {
			this.components = new ComponentList();
			this.ready = false;
			this.processing = new Promise((resolve, reject) -> {
				RegisterLoader.register(this, (err:Error) -> {
					if (err != null) {
						// We keep the failed promise here in this.processing
						reject(err);
						return;
					}
					this.ready = true;
					this.processing = null;
					resolve(this.components);
				});

				return null;
			});
			
			promise = this.processing;
		}
		return promise;
	}

	/**
		Load an instance of a specific component. If the
		registered component is a JSON or FBP graph, it will
		be loaded as an instance of the ZenFlo subgraph
		component.
	**/
	public function load(name:String, meta:GraphNodeMetadata):Promise<Any> {
		var metadata = meta;
		
		if (!this.ready) {
			return this.listComponents().next((_) -> this.load(name, meta));
		}

		return new Promise((resolve, reject) -> {
			if (this.components == null) {
				reject(new Error('Component ${name} not available with base ${this.baseDir}'));
				return null;
			}
			var component = this.components[name];
			if (component == null) {
				// Try an alias
				final keys = this.components.keys();
				for (i in 0...keys.length) {
					final componentName = keys[i];
					if (componentName.split('/')[1] == name) {
						component = this.components[componentName];
						break;
					}
				}
				if (component == null) {
					// Failure to load
					reject(new Error('Component ${name} not available with base ${this.baseDir}'));
					return null;
				}
			}
			resolve(component);
			return null;
		}).next((component:Dynamic) -> {
			if (this.isGraph(component)) {
				return this.loadGraph(name, component, metadata);
			}

			return this.createComponent(name, component, metadata).next((instance) -> {
				if (instance == null) {
					return Promise.reject(new Error('Component ${name} could not be loaded.'));
				}

				final inst:Component = instance;
				if (name == 'Graph') {
					inst.baseDir = this.baseDir;
				}
				if (Std.isOfType(name, String)) {
					inst.componentName = name;
				}

				this.setIcon(name, inst);
				return cast inst;
			});
		});
	}

	/**
		Creates an instance of a component.
	**/
	public function createComponent(name:String, component:Dynamic, metadata:GraphNodeMetadata):Promise<Any> {
		final implementation:Dynamic = component;
		if (implementation == null) {
			return Promise.reject(new Error('Component ${name} not available'));
		}

		// If a string was specified, attempt to `require` it.
		if (Std.isOfType(component, String)) {
			return new Promise((resolve, reject) -> {
				RegisterLoader.dynamicLoad(name, implementation, metadata, (err, instance) -> {
					if (err != null) {
						reject(err);
						return;
					}
					resolve(instance);
				});
				return null;
			});

			return Promise.reject(new Error('Dynamic loading of ${implementation} for component ${name} not available on this platform.'));
		}

		// Attempt to create the component instance using the `getComponent` method.
		var instance:Component = null;
		final impl:ModuleComponent = /** @type ModuleComponent */ (implementation);
		if (impl.getComponent != null) {
			try {
				instance = impl.getComponent(metadata);
			} catch (error:Error) {
				return Promise.reject(error);
			}
			// Attempt to create a component using a factory function.
		} else if (Reflect.isFunction(implementation)) {
			try {
				instance = implementation(metadata);
			} catch (error:Error) {
				return Promise.reject(error);
			}
		} else {
			return Promise.reject(new Error('Invalid type ${Type.typeof(implementation)} for component ${name}.'));
		}
		return Promise.resolve(instance);
	}

	/**
		Check if a given filesystem path is actually a graph
	**/
	public function isGraph(cPath:Dynamic):Bool {
		// Live graph instance
		if (Std.isOfType(cPath, Graph)
			|| (Std.isOfType(cPath.nodes, Array) && Std.isOfType(cPath.edges, Array) && Std.isOfType(cPath.initializers, Array))) {
			return true;
		}

		// Graph JSON definition
		if ((Std.isOfType(cPath, Graph)) && cPath.processes && cPath.connections) {
			return true;
		}
		if (Std.isOfType(cPath, String)) {
			return false;
		}
		// Graph file path
		return (cPath.indexOf('.fbp') != -1) || (cPath.indexOf('.json') != -1);
	}

	/**
		Load a graph as a ZenFlo subgraph component instance
	**/
	public function loadGraph(name:String, component:zenflo.components.Graph, metadata:GraphNodeMetadata) {
		final graphComponent:ModuleComponent = /** @type {ModuleComponent} */ cast(this.components["Graph"]);
		return this.createComponent(name, graphComponent, metadata).next((graph) -> {
			final g:zenflo.components.Graph = /** @type {import("../components/Graph").Graph} */ cast (graph);
			g.loader = this;
			g.baseDir = this.baseDir;
			g.inPorts.remove('graph');
			this.setIcon(name, g);
			return g.setGraph(component).next((_) -> g);
		});
	}

	/**
		Set icon for the component instance. If the instance
		has an icon set, then this is a no-op. Otherwise we
		determine an icon based on the module it is coming
		from, or use a fallback icon separately for subgraphs
		and elementary components.
	**/
	public function setIcon(name:String, instance:Component) {
		// See if component has an icon
		if (instance.getIcon() != null) {
			return;
		}

		// See if library has an icon
		final x = name.split('/');
		var library = x[0];
		var componentName = x[1];
		if (componentName != null && this.getLibraryIcon(library) != null) {
			instance.setIcon(this.getLibraryIcon(library));
			return;
		}

		// See if instance is a subgraph
		if (instance.isSubgraph()) {
			instance.setIcon('sitemap');
			return;
		}

		instance.setIcon('gear');
	}

	public function getLibraryIcon(prefix:String):Null<String> {
		if (this.libraryIcons.exists(prefix)) {
			return this.libraryIcons.get(prefix);
		}
		return null;
	}

	public function setLibraryIcon(prefix:String, icon:String) {
		this.libraryIcons.set(prefix, icon);
	}

	public function normalizeName(packageId:String, name:String) {
		final prefix = packageId;
		var fullName = '${prefix}.${name}';
		if (packageId == null) {
			fullName = name;
		}
		return fullName;
	}

	/**
		### Registering components at runtime

		In addition to components discovered by the loader,
		it is possible to register components at runtime.

		With the `registerComponent` method you can register
		a ZenFlo Component constructor or factory method
		as a component available for loading.
	**/
	public function registerComponent(packageId:String, name:String, cPath:Dynamic, ?callback:ErrorableCallback) {
		final fullName = this.normalizeName(packageId, name);
		trace(fullName);
		this.components[fullName] = cPath;
		if (callback != null) {
			callback(null);
		}
	}

	/**
		With the `registerGraph` method you can register new
		graphs as loadable components.
	**/
	public function registerGraph(packageId:String, name:String, gPath:Graph, callback:ErrorableCallback) {
		this.registerComponent(packageId, name, gPath, callback);
	}

	/**
		With `registerLoader` you can register custom component
		loaders. They will be called immediately and can register
		any components or graphs they wish.
	**/
	public function registerLoader(loader:(loader:ComponentLoader, callback:ErrorableCallback) -> Void, callback:ErrorableCallback) {
		loader(this, callback);
	}

	/**
		With `setSource` you can register a component by providing
		a source code string. Supported languages and techniques
		depend on the runtime environment.
	**/
	public function setSource(packageId:String, name:String, source:String, language:String, callback:ErrorableCallback):Promise<Any> {
		if (!this.ready) {
			return this.listComponents().next((_) -> this.setSource(packageId, name, source, language, callback));
		}
		var promise = null;
		if (RegisterLoader.setSource == null) {
			promise = Promise.reject(new Error('setSource not allowed'));
		} else {
			promise = new Promise((resolve, reject) -> {
				RegisterLoader.setSource(this, packageId, name, source, language, (?err:Error) -> {
					if (err != null) {
						reject(err);
						return;
					}
					resolve(null);
				});

				return null;
			});
		}

		return promise;
	}

	/**
		`getSource` allows fetching the source code of a registered
		component as a string.
	**/
	public function getSource(name:String, callback:(error:Error, source:ComponentSources) -> Void):Promise<ComponentSources> {
		if (!this.ready) {
			return this.listComponents().next((_) -> this.getSource(name, callback));
		}
		var promise = null;
		if (RegisterLoader.getSource == null) {
			promise = Promise.reject(new Error('getSource not allowed'));
		} else {
			promise = new Promise((resolve, reject) -> {
				RegisterLoader.getSource(this, name, (err:Error, source) -> {
					if (err != null) {
						reject(err);
						return;
					}
					resolve(source);
				});

				return null;
			});
		}

		return promise;
	}

	/**
		`getLanguages` gets a list of component programming languages supported by the `setSource`
		method on this runtime instance.
	**/
	public function getLanguages() {
		if (RegisterLoader.getLanguages == null) {
			// This component loader doesn't support the method, default to normal hscript
			return ['hscript', 'hx'];
		}
		return RegisterLoader.getLanguages();
	}

	var baseDir:String;

	var options:ComponentLoaderOptions;
	var libraryIcons:StringMap<String>;

	var components:ComponentList;

	var sourcesForComponents:StringMap<Dynamic>;
	var specsForComponents:StringMap<String>;

	var processing:Promise<ComponentList>;

	var ready:Bool;


    public function clear() {
        this.components = null;
        this.sourcesForComponents = new StringMap();
        this.specsForComponents = new StringMap();
        this.ready = false;
        this.processing = null;
      }
}
