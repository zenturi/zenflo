package zenflo.spec.lib;

import haxe.Rest;
import tink.core.Error;
import equals.Equal;
import buddy.BuddySuite;

using buddy.Should;

@colorize
class Outport extends BuddySuite {
	public function new() {
		describe('Outport Port', {
			describe('with addressable ports', {
				var s1:InternalSocket = null;
				var s2:InternalSocket = null;
				var s3:InternalSocket = null;
				beforeEach({
					s1 = new InternalSocket();
					s2 = new InternalSocket();
					s3 = new InternalSocket();
				});

				it('should be able to send to a specific port', {
					final p = new OutPort({addressable: true});
					p.attach(s1);
					p.attach(s2);
					p.attach(s3);
					Equal.equals(p.listAttached(), [0, 1, 2]).should.be(true);
					// chai.expect(p.listAttached()).to.eql([0, 1, 2]);
					s1.on('data', (_) -> {
						true
						.should.be(false);
					});
					s2.on('data', (datas) -> {
						final data:IP = datas[0];
						data.should.be("some-data");
					});
					s3.on('data', (_) -> {
						true
						.should.be(false);
					});
					p.send('some-data', 1);
				});
				it('should be able to send to index 0', (done) -> {
					final p = new OutPort({addressable: true});
					p.attach(s1);
					s1.on('data', (datas) -> {
						final data:IP = datas[0];
						data.should.be('my-data');
						done();
					});
					p.send('my-data', 0);
				});
				it('should throw an error when sent data without address', () -> {
					final p = new OutPort();
					try {
						(() -> p.send('some-data'))();
					} catch (e:Error) {
						e.should.not.be(null);
						e.should.beType(Error);
					}
				});
				it('should throw an error when a specific port is requested with non-addressable port', {
					final p = new OutPort();
					p.attach(s1);
					p.attach(s2);
					p.attach(s3);
					try {
						(() -> p.send('some-data', 1))();
					} catch (e:Error) {
						e.should.not.be(null);
						e.should.beType(Error);
					}
				});
				it('should give correct port index when detaching a connection', (done) -> {
					final p = new OutPort({addressable: true});
					p.attach(s1, 3);
					p.attach(s2, 1);
					p.attach(s3, 5);
					final expectedSockets = [s2, s3];
					final expected = [1, 5];
					final expectedAttached = [[3, 5], [3],];
					p.on('detach', (vals:Array<Any>) -> {
						final socket:IP = vals[0];
						final index:Int = vals[1];
						socket.should.be(expectedSockets.shift());
						index.should.be(expected.shift());
						p.isAttached(index).should.be(false);

						final atts = expectedAttached.shift();
						Equal.equals(p.listAttached(), atts).should.be(true);

						for (att in atts) {
							p.isAttached(att).should.be(true);
						}
						if (expected.length == 0) {
							done();
						}
					});
					p.detach(s2);
					p.detach(s3);
				});
			});
			describe('with caching ports', {
				var s1:InternalSocket = null;
				var s2:InternalSocket = null;
				var s3:InternalSocket = null;
				beforeEach({
					s1 = new InternalSocket();
					s2 = new InternalSocket();
					s3 = new InternalSocket();
				});

				it('should repeat the previously sent value on attach event', (done) -> {
					final p = new OutPort({caching: true});
					s1.once('data', (datas) -> {
						final data = datas[0];
						data.should.be('foo');
					});
					s2.once('data', (datas) -> {
						final data = datas[0];
						data.should.be('foo');
						// Next value should be different
						s2.once('data', (vals:Array<Any>) -> {
							final d = vals[0];
							// failing because of race condition
							d.should.be('bar');
							done();
						});
					});
					p.attach(s1);
					p.send('foo');
					p.disconnect();

					p.attach(s2);

					p.send('bar');
					p.disconnect();
				});
				it('should support addressable ports', (done) -> {
					final p = new OutPort({
						addressable: true,
						caching: true,
					});

					p.attach(s1);
					p.attach(s2);

					s1.on('data', (_) -> {
						true
						.should.be(false);
					});
					s2.on('data', (datas) -> {
						final data = datas[0];
						data.should.be('some-data');
					});
					s3.on('data', (datas) -> {
						final data = datas[0];
						data.should.be('some-data');
						done();
					});

					p.send('some-data', 1);
					p.disconnect(1);
					p.detach(s2);
					p.attach(s3, 1);
				});
			});

			describe('with IP objects', {
				var s1:InternalSocket = null;
				var s2:InternalSocket = null;
				var s3:InternalSocket = null;
				beforeEach({
					s1 = new InternalSocket();
					s2 = new InternalSocket();
					s3 = new InternalSocket();
				});

				it('should send data IPs and substreams', (done) -> {
					final p = new OutPort();
					p.attach(s1);

					final expectedEvents = ['data', 'openBracket', 'data', 'closeBracket',];

					var count = 0;

					s1.on('ip', (datas) -> {
						final data:IP = datas[0];
						count++;
						Reflect.isObject(data).should.be(true);
						data.type.should.be(expectedEvents.shift());

						if (data.type == "data") {
							data.data.should.be('my-data');
						}
						if (count == 4) {
							done();
						}
					});
					p.data('my-data');
					p.openBracket().data('my-data').closeBracket();
				});
				it('should send non-clonable objects by reference', (done) -> {
					final p = new OutPort();
					p.attach(s1);
					p.attach(s2);
					p.attach(s3);

					final obj = {
						foo: 123,
						bar: {
							boo: 'baz',
						},
						func: null
					};

					obj.func = () -> {
						return obj.foo = 456;
					};

					s1.on('ip', (datas) -> {
						final data:IP = datas[0];
						Reflect.isObject(data).should.be(true);
						data.data.should.be(obj);
						Reflect.isFunction(data.data.func).should.be(true);

						s2.on('ip', (datas) -> {
							final data:IP = datas[0];
							Reflect.isObject(data).should.be(true);
							data.data.should.be(obj);
							Reflect.isFunction(data.data.func).should.be(true);
							s3.on('ip', (datas) -> {
								final data:IP = datas[0];
								Reflect.isObject(data).should.be(true);
								data.data.should.be(obj);
								Reflect.isFunction(data.data.func).should.be(true);
								done();
							});
						});
					});

					p.data(obj, {clonable: false}); // default
				});
				it('should clone clonable objects on fan-out', (done) -> {
					final p = new OutPort();
					p.attach(s1);
					p.attach(s2);
					p.attach(s3);

					final obj = {
						foo: 123,
						bar: {
							boo: 'baz',
						},
						func: null
					};

					obj.func = () -> {
						return obj.foo = 456;
					};

					s1.on('ip', (vals) -> {
						final data:IP = vals[0];
						// First send is non-cloning
						Reflect.isObject(data).should.be(true);
						data.data.should.be(obj);
						Reflect.isFunction(data.data.func).should.be(true);

						s2.on('ip', (vals) -> {
							final data:IP = vals[0];
							Reflect.isObject(data).should.be(true);
							data.data.should.not.be(obj);
							data.data.foo.should.be(obj.foo);
							Equal.equals(data.data.bar, obj.bar).should.be(true);
							data.data.func.should.be(null);

							s3.on('ip', (vals) -> {
								final data:IP = vals[0];
								Reflect.isObject(data).should.be(true);
								data.data.should.not.be(obj);
								data.data.foo.should.be(obj.foo);
								Equal.equals(data.data.bar, obj.bar).should.be(true);
								data.data.func.should.be(null);
								done();
							});
						});
					});

					p.data(obj, {clonable: true});
				});
				it('should stamp an IP object with the port\'s datatype', (done) -> {
					final p = new OutPort({dataType: 'string'});
					p.attach(s1);
					s1.on('ip', (vals) -> {
						final data:IP = vals[0];
						Reflect.isObject(data).should.be(true);
						data.type.should.be('data');
						data.data.should.be('Hello');
						data.dataType.should.be('string');
						done();
					});
					p.data('Hello');
				});
                it('should keep an IP object\'s datatype as-is if already set', (done) -> {
                    final p = new OutPort({ dataType: 'string' });
                    p.attach(s1);
                    s1.on('ip', (vals) -> {
                        final data:IP = vals[0];
						Reflect.isObject(data).should.be(true);
                        data.type.should.be('data');
                        data.data.should.be(123);
                        data.dataType.should.be('integer');
                        done();
                    });
                    p.sendIP(Either.Left(new IP(DATA, 123, { dataType: 'integer' })));
                });
                it('should stamp an IP object with the port\'s schema', (done) -> {
                    final p = new OutPort({
                        dataType: 'string',
                        schema: 'text/markdown',
                    });
                    p.attach(s1);
                    s1.on('ip', (vals) -> {
                        final data:IP = vals[0];
						Reflect.isObject(data).should.be(true);
                        data.type.should.be('data');
                        data.data.should.be('Hello');
                        data.dataType.should.be('string');
                        data.schema.should.be('text/markdown');
                        done();
                    });
                    p.data('Hello');
                });
                it('should keep an IP object\'s schema as-is if already set', (done) -> {
                    final p = new OutPort({
                        dataType: 'string',
                        schema: 'text/markdown',
                    });
                    p.attach(s1);
                    s1.on('ip', (vals) -> {
                        final data:IP = vals[0];
						Reflect.isObject(data).should.be(true);
                        data.type.should.be('data');
                        data.data.should.be('Hello');
                        data.dataType.should.be('string');
                        data.schema.should.be('text/plain');
                        done();
                    });
                    p.sendIP(Either.Left(new IP('data', 'Hello', {
                        dataType: 'string',
                        schema: 'text/plain',
                    })));
                });
			});
		});
	}
}
