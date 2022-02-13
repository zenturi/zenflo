package zenflo.spec.lib;

import zenflo.lib.loader.ManifestLoader;
import haxe.io.Path;

using buddy.Should;


// Todo: Implement way to register component on Haxe (hscript, hl, eval, cppia)
@colorize
class AsComponent extends buddy.BuddySuite {
    public function new() {
        describe('asComponent interface', {
            var loader:ComponentLoader = null;
            beforeAll((done)->{
                ManifestLoader.init();
                loader = new ComponentLoader(Path.join([Sys.getCwd(), "spec/"]));
                loader.listComponents().handle((cb)->{
                    switch cb {
                        case Success(data):{
                            done();
                        }
                        case Failure(f):{
                            trace(f);
                            fail(f);
                        }
                    }
                });
            });
            describe('with a synchronous function taking a single parameter', {
                describe('with returned value', {
                    var func = (?hello) -> 'Hello ${hello}';
                    it('should be possible to componentize', (done) -> {
                        final component = (metadata) -> zenflo.lib.Macros.asComponent((?hello:String)->func(hello), metadata);
                        
                        loader.registerComponent('ascomponent', 'sync-one', component, (?e)-> done());
                    });

                    it('should be loadable', (done) -> {
                        loader.load('ascomponent.sync-one').handle((cb)->{
                            switch cb {
                                case Success(s):{
                                    done();
                                }
                                case Failure(f):{
                                    fail(f);
                                }
                            }
                        });
                    });
                });
            });
        });
    }
}