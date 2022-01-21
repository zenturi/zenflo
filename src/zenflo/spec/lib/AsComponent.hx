package zenflo.spec.lib;

using buddy.Should;


// Todo: Implement way to register component on Haxe (hscript, hl, eval, cppia)
@colorize
class AsComponent extends buddy.BuddySuite {
    public function new() {
        describe('asComponent interface', {
            var loader:ComponentLoader = null;
            trace("HERE");
            beforeAll((done)->{
                loader = new ComponentLoader("./");
                loader.listComponents().handle((cb)->{
                    trace("HERE");
                    switch cb {
                        case Success(data):{
                            done();
                        }
                        case Failure(f):{
                            fail(f);
                        }
                    }
                });
            });
            // describe('with a synchronous function taking a single parameter', {
            //     describe('with returned value', {
            //         var func = (?hello) -> 'Hello ${hello}';
            //         it('should be possible to componentize', (done) -> {
            //             #if macro
            //             final component = (_) ->  zenflo.lib.Macros.asComponent((?hello:String)->func(hello), {});
            //             loader.registerComponent('ascomponent', 'sync-one', component, (?e)-> done());
            //             #end
            //         });

            //         it('should be loadable', (done) -> {
            //             loader.load('ascomponent/sync-one', {}).handle((cb)->{
            //                 switch cb {
            //                     case Success(s):{
            //                         done();
            //                     }
            //                     case Failure(f):{
            //                         fail(f);
            //                     }
            //                 }
            //             });
            //         });
            //     });
            // });
        });
    }
}