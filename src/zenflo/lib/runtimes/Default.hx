package zenflo.lib.runtimes;

import zenflo.lib.loader.ManifestLoader;

interface Runtime {
    public function list(componentDir:String, options:ManifestOptions):Promise<Array<ManifestModule>>;
    public function listDependencies(componentDir:String, options:ManifestOptions):Promise<Array<String>>;
}

class DefaultRuntime implements Runtime {
    public function new() {
        
    }
	public function list(componentDir:String, options:ManifestOptions):Promise<Array<ManifestModule>> {
		throw new haxe.exceptions.NotImplementedException();
	}

    public function listDependencies(componentDir:String, options:ManifestOptions):Promise<Array<String>> {
        throw new haxe.exceptions.NotImplementedException();
    }
}