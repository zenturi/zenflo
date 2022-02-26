package zenflo.spec.lib;

import zenflo.lib.loader.ManifestLoader;
import zenflo.lib.Macros.asCallback;
import tink.core.Error;
import haxe.Constraints.Function;
import equals.Equal;
import haxe.DynamicAccess;

using buddy.Should;

class AsCallback extends buddy.BuddySuite {
	public function new() {
		describe('asCallback interface', {
			var loader = null;
			ManifestLoader.init();
			final processAsync = function(_) {
				final c = new zenflo.lib.Component();
				c.inPorts.add('in', {dataType: 'string'});
				c.outPorts.add('out', {dataType: 'string'});

				return c.process((input, output, _) -> {
					final data = input.getData('in');
					haxe.Timer.delay(() -> output.sendDone(data), 1);
					return null;
				});
			};

			final processError = function(_) {
				final c = new zenflo.lib.Component();
				c.inPorts.add('in', {dataType: 'string'});
				c.outPorts.add('out', {dataType: 'string'});
				c.outPorts.add('error');
				return c.process((input, output, _) -> {
					final data = input.getData('in');
					output.done(new Error('Received ${data}'));
					return null;
				});
			};

			final processValues = function(_) {
				final c = new zenflo.Component();
				c.inPorts.add('in', {
					dataType: 'string',
					values: ['green', 'blue'],
				});
				c.outPorts.add('out', {dataType: 'string'});
				return c.process((input, output, _) -> {
					final data = input.getData('in');
					output.sendDone(data);
					return null;
				});
			};

			final neverSend = function(_) {
				final c = new zenflo.lib.Component();
				c.inPorts.add('in', {dataType: 'string'});
				c.outPorts.add('out', {dataType: 'string'});
				return c.process((input, _, _) -> {
					input.getData('in');
					return null;
				});
			};

			final streamify = function(_) {
				final c = new zenflo.lib.Component();
				c.inPorts.add('in', {datatype: 'string'});
				c.outPorts.add('out', {datatype: 'string'});
				c.process((input, output, _) -> {
					final data = input.getData('in');
					final words = data.split(' ');
					for (idx in 0...words.length) {
						final word = words[idx];
						output.send(new IP('openBracket', idx));
						final chars:Array<String> = word.split('');
						for (char in chars) {
							output.send(new IP('data', char));
						}
						output.send(new IP('closeBracket', idx));
					}
					output.done();
					return null;
				});
				return c;
			};

			beforeAll(() -> {
				loader = new zenflo.lib.ComponentLoader(Sys.getCwd());
				return loader.listComponents().handle((_) -> {
					loader.registerComponent('process', 'Async', processAsync);
					loader.registerComponent('process', 'Error', processError);
					loader.registerComponent('process', 'Values', processValues);
					loader.registerComponent('process', 'NeverSend', neverSend);
					loader.registerComponent('process', 'Streamify', streamify);
				});
			});

			describe('with a non-existing component', () -> {
				var wrapped = null;
				beforeAll(() -> {
					wrapped = asCallback('foo.Bar', {loader: loader});
				});
				it('should be able to wrap it', (done) -> {
					Reflect.isFunction(wrapped).should.be(true);
					done();
				});
				it('should fail execution', (done) -> {
					wrapped(1, (err, res) -> {
						err.should.beType(Error);
						done();
					});
				});
			});
			describe('with simple asynchronous component', () -> {
				var wrapped = null;
				beforeAll(() -> {
					wrapped = asCallback('process.Async', {loader: loader});
				});

				it('should be able to wrap it', (done) -> {
					Reflect.isFunction(wrapped).should.be(true);
					done();
				});
				it('should execute network with input map and provide output map', (done) -> {
					final expected = {hello: 'world'};

					wrapped({"in": expected}, (err, out) -> {
						if (err != null) {
							fail(err);
							return;
						}
						Equal.equals(out.out, expected).should.be(true);
						done();
					});
				});
				it('should execute network with simple input and provide simple output', (done) -> {
					final expected = {hello: 'world'};

					wrapped(expected, (err, out) -> {
						if (err != null) {
							fail(err);
							return;
						}
						Equal.equals(out, expected).should.be(true);
						done();
					});
				});
				it('should not mix up simultaneous runs', (done) -> {
					var received = 0;
					for (idx in 0...101) {
						wrapped(idx, (err, out) -> {
							if (err != null) {
								fail(err);
								return;
							}

							received += 1;
							if (received == 101) {
								done();
								return;
							}
							new buddy.Should(out).be(idx);
						});
					}
				});
				it('should execute a network with a sequence and provide output sequence', (done) -> {
					final sent:Array<Dynamic> = [{"in": 'hello'}, {"in": 'world'}, {"in": 'foo'}, {"in": 'bar'}];
                  
					final expected:Array<Dynamic> = sent.map((portmap) -> ({out: Reflect.field(portmap, "in")}));
					wrapped(sent, (err, out:Array<Dynamic>) -> {
						if (err != null) {
							fail(err);
							return;
						}
                        
						Equal.equals(out, expected).should.be(true);
						done();
					});
				});
                describe('with the raw option', () -> {
                    it('should execute a network with a sequence and provide output sequence', (done) -> {
                        final wrappedRaw = asCallback('process.Async', {
                          loader:loader,
                          raw: true,
                        });
                        final sent:Array<Dynamic> = [
                          { "in": new IP('openBracket', 'a') },
                          { "in": 'hello' },
                          { "in": 'world' },
                          { "in": new IP('closeBracket', 'a') },
                          { "in": new IP('openBracket', 'b') },
                          { "in": 'foo' },
                          { "in": 'bar' },
                          { "in": new IP('closeBracket', 'b') },
                        ];
                        wrappedRaw(sent, (err, out) -> {
                          if (err != null) {
                            fail(err);
                            return;
                          }
                          final types = out.map((map) -> '${map.out.type} ${map.out.data}');
                          Equal.equals(types, [
                            'openBracket a',
                            'data hello',
                            'data world',
                            'closeBracket a',
                            'openBracket b',
                            'data foo',
                            'data bar',
                            'closeBracket b',
                          ]).should.be(true);
                          done();
                        });
                      });
                });
			});
		});
	}
}
