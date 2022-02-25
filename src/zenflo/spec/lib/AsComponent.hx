package zenflo.spec.lib;

import zenflo.lib.loader.ManifestLoader;
import haxe.io.Path;
import equals.Equal;
import zenflo.lib.Macros.asComponent;
import zenflo.lib.Macros.asCallback;
import equals.Equal;
import tink.core.Error;
import zenflo.lib.Utils.deflate;

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
						final component = (metadata) -> asComponent(deflate(func), metadata);

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
										Equal.equals(instance.inPorts.ports.keys(), ['hello']).should.be(true);
										Equal.equals(instance.outPorts.ports.keys(), ['out', 'error']).should.be(true);
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
							final component = (_) -> asComponent(deflate(func), {});
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
							function fun(hello) {
								throw new Error('Hello ${hello}');
							}
							final component = (meta) -> asComponent(deflate(fun), meta);
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
							wrapped('Error', (err, res) -> {
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
						function func(greeting:String, name:String) {
							return '${greeting} ${name}';
						}
						it('should be possible to componentize', (done) -> {
							final component = (meta) -> asComponent(deflate(func), meta);
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
						it('should contain correct ports', (done) -> {
							loader.load('ascomponent.sync-two').handle(cb -> {
								switch cb {
									case Success(instance): {
											Equal.equals(instance.inPorts.ports.keys(), ['name', 'greeting']).should.be(true);
											Equal.equals(instance.outPorts.ports.keys(), ['out', 'error']).should.be(true);
											done();
										}
									case Failure(err): {
											if (err != null) {
												fail(err);
												return;
											}
										}
								}
							});
						});
						it('should send to OUT port', (done) -> {
							final wrapped = asCallback('ascomponent.sync-two', {loader: loader});
							wrapped({
								greeting: 'Hei',
								name: 'Maailma',
							}, (err, res) -> {
								if (err != null) {
									fail(err);
									return;
								}
								Equal.equals(res, {out: 'Hei Maailma'}).should.be(true);
								done();
							});
						});
					});
					describe('with a default value', () -> {
						// before(function () {
						//   if (isBrowser) { return this.skip(); }
						// }); // Browser runs with ES5 which didn't have defaults
						it('should be possible to componentize', (done) -> {
							final component = (meta) -> asComponent(deflate((name, greeting = 'Hello') -> '${greeting} ${name}'), meta);
							loader.registerComponent('ascomponent', 'sync-default', component, (e) -> done());
						});
						it('should be loadable', (done) -> {
							loader.load('ascomponent.sync-default').handle(cb -> done());
						});
						it('should contain correct ports', (done) -> {
							loader.load('ascomponent.sync-default').handle(cb -> {
								switch cb {
									case Success(instance): {
											Equal.equals(instance.inPorts.ports.keys(), ['name', 'greeting']);
											Equal.equals(instance.outPorts.ports.keys(), ['out', 'error']);

											final name:InPort = cast instance.inPorts["name"];
											final greeting:InPort = cast instance.inPorts["greeting"];
											name.isRequired().should.be(true);
											name.hasDefault().should.be(false);
											greeting.isRequired().should.be(false);
											greeting.hasDefault().should.be(true);

											done();
										}
									case Failure(err): {
											fail(err);
										}
								}
							});
						});
						it('should send to OUT port', (done) -> {
							final wrapped = asCallback('ascomponent.sync-default', {loader: loader});
							wrapped({name: 'Maailma'}, (err, res) -> {
								if (err != null) {
									fail(err);
									return;
								}
								Equal.equals(res, {out: 'Hello Maailma'}).should.be(true);
								done();
							});
						});
					});
				});
			});
			describe('with a function returning a Promise', () -> {
				describe('with a resolved promise', () -> {
					//   before(function () {
					// 	if (isBrowser && (typeof window.Promise === 'undefined')) { return this.skip(); }
					//   });
					function func(hello) {
						return new tink.core.Promise((resolve, _) -> {
							haxe.Timer.delay(() -> resolve('Hello ${hello}'), 5);
							return null;
						});
					}
					it('should be possible to componentize', (done) -> {
						final component = (meta) -> asComponent(deflate(func), meta);
						loader.registerComponent('ascomponent', 'promise-one', component, (e) -> done());
					});
					it('should send to OUT port', (done) -> {
						final wrapped = asCallback('ascomponent.promise-one', {loader: loader});
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
				describe('with a rejected promise', () -> {
					function func(hello) {
						return new tink.core.Promise((_, reject) -> {
							haxe.Timer.delay(() -> reject(new Error('Hello ${hello}')), 5);
							return null;
						});
					}
					it('should be possible to componentize', (done) -> {
						final component = (meta) -> asComponent(deflate(func), meta);
						loader.registerComponent('ascomponent', 'sync-throw', component, (e) -> done());
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
			describe('with a synchronous function taking zero parameters', () -> {
				describe('with returned value', () -> {
					function func() {
						return 'Hello there';
					}
					it('should be possible to componentize', (done) -> {
						final component = (meta) -> asComponent(deflate(func), {});
						loader.registerComponent('ascomponent', 'sync-zero', component, (e) -> done());
					});
					it('should contain correct ports', (done) -> {
						loader.load('ascomponent.sync-zero').handle(cb -> {
							switch cb {
								case Success(instance): {
										
										Equal.equals(instance.inPorts.ports.keys(), ['in']).should.be(true);
										Equal.equals(instance.outPorts.ports.keys(), ['out', 'error']).should.be(true);
										done();
									}
								case Failure(err): {
										fail(err);
									}
							}
						});
					});
					it('should send to OUT port', (done) -> {
						final wrapped = asCallback('ascomponent.sync-zero', {loader: loader});
						wrapped('bang', (err, res) -> {
							if (err != null) {
								fail(err);
								return;
							}
							new buddy.Should(res).be('Hello there');
							done();
						});
					});
				});
				describe('with a built-in function', () -> {
					it('should be possible to componentize', (done) -> {
						final component = (meta) -> asComponent(deflate(Math.random), {});
						loader.registerComponent('ascomponent', 'sync-zero', component, (e) -> done());
					});
					it('should contain correct ports', (done) -> {
						loader.load('ascomponent.sync-zero').handle(cb -> {
							switch cb {
								case Success(instance): {
										Equal.equals(instance.inPorts.ports.keys(), ['in']).should.be(true);
										Equal.equals(instance.outPorts.ports.keys(), ['out', 'error']).should.be(true);
										done();
									}
								case Failure(err): {
										fail(err);
										return;
									}
							}
						});
					});
					it('should send to OUT port', (done) -> {
						final wrapped = asCallback('ascomponent.sync-zero', {loader: loader});
						wrapped('bang', (err, res) -> {
							if (err != null) {
								fail(err);
								return;
							}
							new buddy.Should(res).beType(Float);
							done();
						});
					});
				});
			});
			// Haxe has no standard callback methodology like NodeJS
			// describe('with an asynchronous function taking a single parameter and callback', () -> {
			// 	describe('with successful callback', () -> {

			// 	});
			// });
		});
	}
}
