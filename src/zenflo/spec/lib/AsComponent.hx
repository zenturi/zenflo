package zenflo.spec.lib;

import zenflo.lib.loader.ManifestLoader;
import haxe.io.Path;
import equals.Equal;
import zenflo.lib.Macros.asComponent;
import zenflo.lib.Macros.asCallback;
import equals.Equal;
import tink.core.Error;

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
						final wrapped = asCallback('ascomponent.sync-one', {loader: loader});
						wrapped('World', (err, res) -> {
							if (err != null) {
								fail(err);
								return;
							}
							new buddy.Should(res).be('Hello World');
							done();
						});
					});
					it('should forward brackets to OUT port', (done) -> {
						loader.load('ascomponent.sync-one').handle(cb -> {
							switch cb {
								case Success(instance): {
										final ins = InternalSocket.createSocket();
										final out = InternalSocket.createSocket();
										final error = InternalSocket.createSocket();
										instance.inPorts["hello"].attach(ins);
										instance.outPorts["out"].attach(out);
										instance.outPorts["error"].attach(error);
										final received = [];
										final expected = [
											'openBracket a',
											'data Hello Foo',
											'data Hello Bar',
											'data Hello Baz',
											'closeBracket a',
										];
										error.once('data', (vals) -> {
											final data = vals[0];
											fail(data);
										});
										out.on('ip', (vals) -> {
											final ip:IP = vals[0];
											received.push('${ip.type} ${ip.data}');
											if (received.length != expected.length) {
												return;
											}
											Equal.equals(received, expected).should.be(true);

											done();
										});
										ins.post(new IP('openBracket', 'a'));
										ins.post(new IP('data', 'Foo'));
										ins.post(new IP('data', 'Bar'));
										ins.post(new IP('data', 'Baz'));
										ins.post(new IP('closeBracket', 'a'));
									}
								case Failure(err): {
										fail(err);
										return;
									}
							}
						});
					});
					describe('with returned NULL', () -> {
						final func = () -> null;
						it('should be possible to componentize', (done) -> {
							final component = (_) -> asComponent(() -> func(), {});
							loader.registerComponent('ascomponent', 'sync-null', component, (e) -> {
								if (e != null) {
									fail(e);
									return;
								}
								done();
							});
						});
						it('should send to OUT port', (done) -> {
							final wrapped = asCallback('ascomponent.sync-null', {loader: loader});
							wrapped('World', (err, res) -> {
								if (err != null) {
									fail(err);
									return;
								}
								new buddy.Should(res).be(null);
								done();
							});
						});
					});
					describe('with a thrown exception', () -> {
						it('should be possible to componentize', (done) -> {
							final component = (meta) -> asComponent(function(hello) {
								throw new Error('Hello ${hello}');
							}, meta);
							loader.registerComponent('ascomponent', 'sync-throw', component, (e) -> {
								if (e != null) {
									fail(e);
									return;
								}
								done();
							});
						});
						it('should send to ERROR port', (done) -> {
							final wrapped = asCallback('ascomponent.sync-throw', {loader: loader});
							wrapped('Error', (err, _) -> {
								if (err != null) {
									err.should.not.be(null);
									err.should.beType(Error);
									err.toString().should.contain('Hello Error');
									done();
								}
							});
						});
					});
				});
				describe('with a synchronous function taking a multiple parameters', {
					describe('with returned value', {
						it('should be possible to componentize', (done) -> {
							function func(greeting:String, name:String)
								return '${greeting} ${name}';
							final component = (meta) -> asComponent(func, meta);
							loader.registerComponent('ascomponent', 'sync-two', component, (e) -> {
								if (e != null) {
									fail(e);
									return;
								}
								done();
							});
						});
						it('should be loadable', (done) -> {
							loader.load('ascomponent.sync-two').handle((cb) -> {
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
					});
				});
			});
		});
	}
}
