package zenflo.lib.loader;

import zenflo.lib.ComponentLoader.ComponentSources;
import zenflo.lib.Component.ErrorableCallback;







class RegisterLoader {
    public static var getLanguages:()->Array<String>;
    public static var setSource:(loader:ComponentLoader, packageId:String, name:String, source:String, language:String, callback:ErrorableCallback)->Void;
    public static dynamic function register(loader:ComponentLoader, callback:(err:tink.core.Error)->Void) {
    
    }

    public static dynamic function dynamicLoad(name:String, cpath:String, metadata:Dynamic, callback:(err:tink.core.Error, component:Component)->Void) {
    
    }

	public static var getSource:(loader:ComponentLoader, name:String, callback:(error:tink.core.Error, source:ComponentSources)->Void)->Void;
}