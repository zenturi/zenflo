package;

import zenflo.lib.*;
import haxe.io.Path;
import zenflo.lib.Macros.asComponent;
import zenflo.lib.Macros.asCallback;
import zenflo.lib.loader.ManifestLoader;
using zenflo.lib.Utils;

class AsComponentTest {
	public static function main() {
        ManifestLoader.init();
        final loader = new ComponentLoader(Path.join([Sys.getCwd(), "spec/"]));
		loader.listComponents();

		

		final component = (meta) -> asComponent(zenflo.lib.Utils.deflate(function func(greeting:String = 'Hello', name:String) {
			return '${greeting} ${name}';
		}), meta);
		loader.registerComponent('ascomponent', 'sync-default', component, (e) -> {
			if (e != null) {
				throw e;
			}

            loader.load('ascomponent.sync-default').handle((cb) -> {
                switch cb {
                    case Success(s): {
                            final wrapped = asCallback('ascomponent.sync-default', {loader: loader});
                            wrapped({
                                name: 'Maailma',
                            }, (err, res) -> {
                                if (err != null) {
                                    throw err;
                                }
    
                                trace(res);
                            });
                        }
                    case Failure(f): {
                            throw f;
                        }
                }
            });
		});

		
	}
}
