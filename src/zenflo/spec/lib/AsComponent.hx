package zenflo.spec.lib;

import zenflo.lib.loader.ManifestLoader;
import haxe.io.Path;
import equals.Equal;
import zenflo.lib.Macros.asComponent;
import zenflo.lib.Macros.asCallback;

using buddy.Should;

// Todo: Implement way to register component on Haxe (hscript, hl, eval, cppia)
@colorize
class AsComponent extends buddy.BuddySuite {
	public function new() {
		describe('asComponent interface', {
			var loader:ComponentLoader = null;
			beforeAll((done) -> {
				ManifestLoader.init();
				loader = new ComponentLoader(Path.join([Sys.getCwd(), "spec/"]));
				loader.listComponents().handle((cb) -> {
					switch cb {
						case Success(data): {
								done();
							}
						case Failure(f): {
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
						final component = (metadata) -> asComponent((?hello:String) -> func(hello), metadata);

						loader.registerComponent('ascomponent', 'sync-one', component, (?e) -> done());
					});

					it('should be loadable', (done) -> {
						loader.load('ascomponent.sync-one').handle((cb) -> {
							switch cb {
								case Success(s): {
										done();
									}
								case Failure(f): {
										fail(f);
									}
							}
						});
					});
					it('should contain correct ports', (done) -> {
						loader.load('ascomponent.sync-one').handle((cb) -> {
							switch cb {
								case Success(instance): {
										Equal.equals(Reflect.fields(instance.inPorts.ports), ['hello']).should.be(true);
										Equal.equals(Reflect.fields(instance.outPorts.ports), ['out', 'error']).should.be(true);
										done();
									}
								case Failure(err): {
										fail(err);
									}
							}
						});
					});
					it('should send to OUT port', (done) -> {
						final wrapped = asCallback('ascomponent.sync-one', {loader:loader});
						wrapped('World', (err, res) -> {
							if (err != null) {
								fail(err);
								return;
							}
							new buddy.Should(res).be('Hello World');
							done();
						});
					});
				});
			});
		});
	}
}
