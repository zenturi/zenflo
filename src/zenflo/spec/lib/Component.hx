package zenflo.spec.lib;

import haxe.DynamicAccess;
import sinker.extensions.ArrayNullableExtension;
import haxe.ds.Either;
import equals.Equal;
import zenflo.lib.Component.ComponentOptions;
import zenflo.lib.InPorts.InPortsOptions;
import zenflo.lib.OutPorts.OutPortsOptions;
import haxe.Timer;
import zenflo.lib.InternalSocket;
import zenflo.spec.lib.MergeObjects.getComponent;
import tink.core.Error;

using buddy.Should;

@colorize
class Component extends buddy.BuddySuite {
	public function new() {
		describe('Component', {
			describe('with required ports', {
				it('should throw an error upon sending packet to an unattached required port', (done) -> {
					final s2 = new InternalSocket();
					final opts:OutPortsOptions = {
						required_port: {
							required: true,
						},
						optional_port: {},
					};

					final c = new zenflo.lib.Component({
						outPorts: opts,
					});

					c.outPorts["optional_port"].attach(s2);
					try {
						(() -> {
							final o:OutPorts = cast c.outPorts["required_port"];
							o.send('foo');
						})();
					} catch (e) {
						done();
					}
				});
				it('should be cool with an attached port', (done) -> {
					final s1 = new InternalSocket();
					final s2 = new InternalSocket();
					final i:InPortsOptions = {
						required_port: {
							required: true,
						},
						optional_port: {},
					};
					final c = new zenflo.lib.Component({
						inPorts: i,
					});
					c.inPorts["required_port"].attach(s1);
					c.inPorts["optional_port"].attach(s2);
					final f = function() {
						s1.send('some-more-data');
						s2.send('some-data');
					};
					try {
						f();
					} catch (e) {
						fail(e);
					}
					done();
				});
			});
			describe('with component creation shorthand', {
				it('should make component creation easy', (done) -> {
					final i:InPortsOptions = {
						"in": {
							dataType: 'string',
							required: true,
						},
						just_processor: {},
					};

					final c = new zenflo.lib.Component({
						inPorts: i,
						process: (input:ProcessInput, output:ProcessOutput, _:ProcessContext) -> {
							var packet:Any = null;
							if (input.hasData('in')) {
								packet = input.getData('in');
								packet.should.be('some-data');
								output.done();
								return null;
							}
							if (input.hasData('just_processor')) {
								packet = input.getData('just_processor');
								packet.should.be('some-data');
								output.done();
								done();
							}
							return null;
						}
					});
					final s1 = new InternalSocket();
					c.inPorts["in"].attach(s1);
					c.inPorts["in"].nodeInstance = c;
					final s2 = new InternalSocket();
					c.inPorts["just_processor"].attach(s1);
					c.inPorts["just_processor"].nodeInstance = c;
					s1.send('some-data');
					s2.send('some-data');
				});
				it('should throw errors if there is no error port', (done) -> {
					final i:InPortsOptions = {
						"in": {
							dataType: 'string',
							required: true,
						}
					};

					final c = new zenflo.lib.Component({
						inPorts: i,
						process: (input:ProcessInput, output:ProcessOutput, _:ProcessContext) -> {
							var packet:Any = input.getData('in');
							packet.should.be('some-data');

							try {
								(() -> output.error(new Error("")))();
							} catch (e) {
								done();
							}
							return null;
						}
					});

					final s1 = new InternalSocket();
					c.inPorts["in"].attach(s1);
					c.inPorts["in"].nodeInstance = c;
					s1.send('some-data');
				});
				it('should throw errors if there is a non-attached error port', (done) -> {
					final i:InPortsOptions = {
						"in": {
							dataType: 'string',
							required: true,
						}
					};
					final o:OutPortsOptions = {
						error: {
							dataType: 'object',
							required: true,
						},
					};
					final c = new zenflo.lib.Component({
						inPorts: i,
						outPorts: o,
						process: (input:ProcessInput, output:ProcessOutput, _:ProcessContext) -> {
							final packet:Any = input.getData('in');
							packet.should.be('some-data');
							try {
								(() -> output.error(new Error("")))();
							} catch (e) {
								done();
							}
							return null;
						}
					});
					final s1 = new InternalSocket();
					c.inPorts["in"].attach(s1);
					c.inPorts["in"].nodeInstance = c;
					s1.send('some-data');
				});
				it('should not throw errors if there is a non-required error port', (done) -> {
					final i:InPortsOptions = {
						"in": {
							dataType: 'string',
							required: true,
						},
					};
					final o:OutPortsOptions = {
						error: {
							required: false,
						},
					};

					final opts:ComponentOptions = {
						inPorts: new InPorts(i),
						outPorts: new OutPorts(o)
					};
					var c:zenflo.lib.Component = null;
					opts.process = (input:ProcessInput, _, _) -> {
						final packet:Any = input.getData('in');
						packet.should.be('some-data');
						c.error(new Error(""));
						done();

						return null;
					};

					c = new zenflo.lib.Component(opts);

					final s1 = new InternalSocket();
					c.inPorts["in"].attach(s1);
					c.inPorts["in"].nodeInstance = c;
					s1.send('some-data');
				});
				it('should send errors if there is a connected error port', (done) -> {
					final i:InPortsOptions = {
						"in": {
							dataType: 'string',
							required: true,
						}
					};
					final o:OutPortsOptions = {
						error: {
							dataType: 'object'
						},
					};

					final c = new zenflo.lib.Component({
						inPorts: new InPorts(i),
						outPorts: new OutPorts(o),
						process: (input:ProcessInput, output:ProcessOutput, ctx:ProcessContext) -> {
							if (!input.hasData('in')) {
								return null;
							}

							final packet:Any = input.getData('in');
							packet.should.be('some-data');
							output.done(new Error(""));
							return null;
						}
					});

					final s1 = new InternalSocket();
					final s2 = new InternalSocket();
					var groups = ['foo', 'bar'];

					s2.on('begingroup', (vals) -> {
						final grp = vals[0];
						grp.should.be(groups.shift());
					});
					s2.on('data', (vals) -> {
						final err = vals[0];
						Std.isOfType(err, Error).should.be(true);
						groups.length.should.be(0);
						done();
					});

					c.inPorts["in"].attach(s1);
					c.outPorts["error"].attach(s2);
					c.inPorts["in"].nodeInstance = c;
					s1.beginGroup('foo');
					s1.beginGroup('bar');
					s1.send('some-data');
				});
			});
			describe('defining ports with invalid names', {
				it('should throw an error with uppercase letters in inport', (done) -> {
					final i:InPortsOptions = {
						fooPort: {}
					};
					final shorthand = () -> new zenflo.lib.Component({
						inPorts: i
					});

					try {
						shorthand();
					} catch (e) {
						done();
					}
				});
				it('should throw an error with uppercase letters in outport', (done) -> {
					final o:OutPortsOptions = {
						BarPort: {}
					};
					final shorthand = () -> new zenflo.lib.Component({
						outPorts: o
					});

					try {
						shorthand();
					} catch (e) {
						done();
					}
				});
				it('should throw an error with special characters in inport', (done) -> {
					final i:InPortsOptions = {
						'$%^&*a': {},
					}
					final shorthand = () -> new zenflo.lib.Component({
						inPorts: i,
					});
					try {
						shorthand();
					} catch (e) {
						done();
					}
				});
			});
			describe('with non-existing ports', {
				final getComponent = () -> new zenflo.lib.Component({
					inPorts: new InPorts({
						"in": {}
					}),
					outPorts: new OutPorts({
						out: {}
					})
				});

				it('should throw an error when checking attached for non-existing port', (done) -> {
					final c = getComponent();
					c.process((input, output, _) -> {
						try {
							input.attached('foo');
						} catch (e:Error) {
							e.should.beType(Error);
							e.message.should.contain('foo');
							done();
							return null;
						}
						fail(new Error('Expected a throw'));
						return null;
					});
					final sin1 = InternalSocket.createSocket();
					c.inPorts["in"].attach(sin1);
					sin1.send('hello');
				});

				it('should throw an error when checking IP for non-existing port', (done) -> {
					final c = getComponent();
					c.process((input, output, _) -> {
						try {
							input.has('foo');
						} catch (e:Error) {
							e.should.beType(Error);
							e.message.should.contain('foo');
							done();
							return null;
						}
						fail(new Error('Expected a throw'));
						return null;
					});
					final sin1 = InternalSocket.createSocket();
					c.inPorts["in"].attach(sin1);
					sin1.send('hello');
				});

				it('should throw an error when checking IP for non-existing addressable port', (done) -> {
					final c = getComponent();
					c.process((input, output, _) -> {
						try {
							input.has(['foo', 0]);
						} catch (e:Error) {
							e.should.beType(Error);
							e.message.should.contain('foo');
							done();
							return null;
						}
						fail(new Error('Expected a throw'));
						return null;
					});
					final sin1 = InternalSocket.createSocket();
					c.inPorts["in"].attach(sin1);
					sin1.send('hello');
				});

				it('should throw an error when checking data for non-existing port', (done) -> {
					final c = getComponent();
					c.process((input, output, _) -> {
						try {
							input.hasData('foo');
						} catch (e:Error) {
							e.should.beType(Error);
							e.message.should.contain('foo');
							done();
							return null;
						}
						fail(new Error('Expected a throw'));
						return null;
					});
					final sin1 = InternalSocket.createSocket();
					c.inPorts["in"].attach(sin1);
					sin1.send('hello');
				});

				it('should throw an error when checking stream for non-existing port', (done) -> {
					final c = getComponent();
					c.process((input, output, _) -> {
						try {
							input.hasStream('foo');
						} catch (e:Error) {
							e.should.beType(Error);
							e.message.should.contain('foo');
							done();
							return null;
						}
						fail(new Error('Expected a throw'));
						return null;
					});
					final sin1 = InternalSocket.createSocket();
					c.inPorts["in"].attach(sin1);
					sin1.send('hello');
				});
			});
			describe('starting a component', {
				it('should flag the component as started', (done) -> {
					final c = new zenflo.lib.Component({
						inPorts: new InPorts({
							"in": {
								dataType: 'string',
								required: true,
							},
						}),
					});
					final i = new InternalSocket();
					c.inPorts["in"].attach(i);
					c.start().handle((cb) -> {
						switch cb {
							case Success(data): {}
							case Failure(err): {
									fail(err);
									return;
								}
						}

						c.started.should.be(true);
						c.isStarted().should.be(true);
						done();
					});
				});
			});
			describe('shutting down a component', {
				it('should flag the component as not started', (done) -> {
					final c = new zenflo.lib.Component({
						inPorts: new InPorts({
							"in": {
								dataType: 'string',
								required: true,
							},
						}),
					});
					final i = new InternalSocket();
					c.inPorts["in"].attach(i);
					c.start().handle((cb) -> {
						switch cb {
							case Success(data): {}
							case Failure(err): {
									fail(err);
									return;
								}
						}
						c.isStarted().should.be(true);
						c.shutdown().handle((_cb) -> {
							switch _cb {
								case Success(data): {}
								case Failure(err): {
										fail(err);
										return;
									}
							}

							c.started.should.be(false);
							c.isStarted().should.be(false);
							done();
						});
					});
				});
			});
			describe('with object-based IPs', {
				it('should speak IP objects', (done) -> {
					final c = new zenflo.lib.Component({
						inPorts: new InPorts({
							"in": {
								dataType: 'string',
							},
						}),
						outPorts: new OutPorts({
							out: {
								datatype: 'string',
							},
						}),
						process: (input, output, _) -> {
							output.sendDone(input.get('in'));
							return null;
						},
					});

					final s1 = new InternalSocket();
					final s2 = new InternalSocket();

					s2.on('ip', (ips) -> {
						final ip:IP = ips[0];
						ip.should.not.be(null);
						ip.type.should.be('data');
						Std.isOfType(ip["groups"], Array).should.be(true);
						Equal.equals(ip["groups"], ['foo']).should.be(true);
						Std.isOfType(ip.data, String).should.be(true);
						ip.data.should.be('some-data');
						done();
					});

					c.inPorts["in"].attach(s1);
					c.outPorts["out"].attach(s2);

					s1.post(new IP('data', 'some-data', {groups: ['foo']}));
				});
				it('should support substreams', (done) -> {
					final handle = {
						str: '',
						level: 0
					}
					var c = new zenflo.lib.Component({
						forwardBrackets: {},
						inPorts: new InPorts({
							tags: {
								dataType: 'string',
							},
						}),
						outPorts: new OutPorts({
							html: {
								dataType: 'string',
							},
						}),
						process: (input, output, _) -> {
							final ip:IP = input.get('tags');
							switch (ip.type) {
								case 'openBracket':
									handle.str += '<${ip.data}>';
									handle.level++;
								case 'data':
									handle.str += ip.data;
								case 'closeBracket':
									handle.str += '</${ip.data}>';
									handle.level--;
									if (handle.level == 0) {
										output.send({html: handle.str});
										handle.str = '';
									}
							}
							output.done();
							return null;
						}
					});

					final d = new zenflo.lib.Component({
						inPorts: new InPorts({
							bang: {
								dataType: 'bang',
							},
						}),
						outPorts: new OutPorts({
							tags: {
								dataType: 'string',
							},
						}),
						process: (input, output, _) -> {
							input.getData('bang');
							output.send({tags: new IP('openBracket', 'p')});
							output.send({tags: new IP('openBracket', 'em')});
							output.send({tags: new IP('data', 'Hello')});
							output.send({tags: new IP('closeBracket', 'em')});
							output.send({tags: new IP('data', ', ')});
							output.send({tags: new IP('openBracket', 'strong')});
							output.send({tags: new IP('data', 'World!')});
							output.send({tags: new IP('closeBracket', 'strong')});
							output.send({tags: new IP('closeBracket', 'p')});
							output.done();
							return null;
						}
					});

					final s1 = new InternalSocket();
					final s2 = new InternalSocket();
					final s3 = new InternalSocket();

					s3.on('ip', (ips) -> {
						final ip:IP = ips[0];
						ip.should.not.be(null);
						ip.type.should.be('data');
						ip.data.should.be('<p><em>Hello</em>, <strong>World!</strong></p>');
						done();
					});

					d.inPorts["bang"].attach(s1);
					d.outPorts["tags"].attach(s2);
					c.inPorts["tags"].attach(s2);
					c.outPorts["html"].attach(s3);

					s1.post(new IP('data', 'start'));
				});
			});
			describe('with process function', {
				var c:zenflo.lib.Component = null;
				var sin1:InternalSocket = null;
				var sin2:InternalSocket = null;
				var sin3:InternalSocket = null;
				var sout1:InternalSocket = null;
				var sout2:InternalSocket = null;

				beforeEach((done) -> {
					sin1 = new InternalSocket();
					sin2 = new InternalSocket();
					sin3 = new InternalSocket();
					sout1 = new InternalSocket();
					sout2 = new InternalSocket();
					done();
				});

				it('should trigger on IPs', (done) -> {
					var hadIPs = [];
					c = new zenflo.lib.Component({
						inPorts: new InPorts({
							foo: {dataType: 'string'},
							bar: {dataType: 'string'},
						}),
						outPorts: new OutPorts({
							baz: {dataType: 'boolean'},
						}),
						process: (input, output, _) -> {
							hadIPs = [];
							if (input.has('foo')) {
								hadIPs.push('foo');
							}
							if (input.has('bar')) {
								hadIPs.push('bar');
							}
							output.sendDone({baz: true});

							return null;
						},
					});

					c.inPorts["foo"].attach(sin1);
					c.inPorts["bar"].attach(sin2);
					c.outPorts["baz"].attach(sout1);

					var count = 0;
					sout1.on('ip', (_) -> {
						count++;
						if (count == 1) {
							Equal.equals(hadIPs, ['foo']).should.be(true);
						}
						if (count == 2) {
							Equal.equals(hadIPs, ['foo', 'bar']).should.be(true);
							done();
						}
					});

					sin1.post(new IP('data', 'first'));
					sin2.post(new IP('data', 'second'));
				});

				it('should trigger on IPs to addressable ports', (done) -> {
					final receivedIndexes = [];
					final c = new zenflo.lib.Component({
						inPorts: new InPorts({
							foo: {
								dataType: 'string',
								addressable: true,
							},
						}),
						outPorts: new OutPorts({
							baz: {
								datatype: 'boolean',
							},
						}),
						process: (input, output, _) -> {
							// See what inbound connection indexes have data
							final indexesWithData = input.attached('foo').filter((idx) -> input.hasData(['foo', idx]));
							if (indexesWithData.length == 0) {
								return Promise.NEVER;
							}
							// Read from the first of them
							final indexToUse = indexesWithData[0];
							final packet = input.get(['foo', indexToUse]);
							receivedIndexes.push({
								idx: indexToUse,
								payload: packet.data,
							});
							output.sendDone({baz: true});
							return Promise.NEVER;
						},
					});

					c.inPorts["foo"].attach(sin1, 1);
					c.inPorts["foo"].attach(sin2, 0);
					c.outPorts["baz"].attach(sout1);

					var count = 0;

					sout1.on('ip', (_) -> {
						count++;
						if (count == 1) {
							Equal.equals(receivedIndexes, [
								{
									idx: 1,
									payload: 'first',
								},
							]).should.be(true);
						}
						if (count == 2) {
							Equal.equals(receivedIndexes, [
								{
									idx: 1,
									payload: 'first',
								},
								{
									idx: 0,
									payload: 'second',
								},
							]).should.be(true);
							done();
						}
					});
					sin1.post(new IP('data', 'first'));
					sin2.post(new IP('data', 'second'));
				});
				it('should be able to send IPs to addressable connections', (done) -> {
					final expected = [
						{
							data: 'first',
							index: 1,
						},
						{
							data: 'second',
							index: 0,
						},
					];
					c = new zenflo.lib.Component({
						inPorts: new InPorts({
							foo: {
								dataType: 'string',
							},
						}),
						outPorts: new OutPorts({
							baz: {
								dataType: 'boolean',
								addressable: true,
							},
						}),
						process: (input, output, _) -> {
							if (!input.has('foo')) {
								return null;
							}
							final packet = input.get('foo');
							output.sendDone(new IP('data', packet.data, {index: expected.length - 1}));
							return null;
						},
					});

					c.inPorts["foo"].attach(sin1);
					c.outPorts["baz"].attach(sout1, 1);
					c.outPorts["baz"].attach(sout2, 0);

					sout1.on('ip', (ips) -> {
						final ip:IP = ips[0];
						final exp = expected.shift();
						final received = {
							data: ip.data,
							index: 1,
						};
						Equal.equals(received, exp).should.be(true);
						if (expected.length == 0) {
							done();
						}
					});
					sout2.on('ip', (ips) -> {
						final ip:IP = ips[0];
						final exp = expected.shift();
						final received = {
							data: ip.data,
							index: 0,
						};
						Equal.equals(received, exp).should.be(true);
						if (expected.length == 0) {
							done();
						}
					});
					sin1.post(new IP('data', 'first'));
					sin1.post(new IP('data', 'second'));
				});

				it('trying to send to addressable port without providing index should fail', (done) -> {
					c = new zenflo.lib.Component({
						inPorts: new InPorts({
							foo: {
								dataType: 'string',
							},
						}),
						outPorts: new OutPorts({
							baz: {
								dataType: 'boolean',
								addressable: true,
							},
						}),
						process: (input, output, _) -> {
							if (!input.hasData('foo')) {
								return Promise.NEVER;
							}
							final packet = input.get('foo');
							final noIndex = new IP('data', packet.data);
							try {
								output.sendDone(noIndex);
							} catch (e) {
								done();
							}
							return Promise.NEVER;
						},
					});

					c.inPorts["foo"].attach(sin1);
					c.outPorts["baz"].attach(sout1, 1);
					c.outPorts["baz"].attach(sout2, 0);

					sout1.on('ip', (_) -> {});
					sout2.on('ip', (_) -> {});

					sin1.post(new IP('data', 'first'));
				});
				it('should be able to send falsy IPs', (done) -> {
					final expected = [
						{
							port: 'out1',
							data: 1,
						},
						{
							port: 'out2',
							data: 0,
						},
					];
					c = new zenflo.lib.Component({
						inPorts: new InPorts({
							foo: {
								dataType: 'string',
							},
						}),
						outPorts: new OutPorts({
							out1: {
								dataType: 'int',
							},
							out2: {
								dataType: 'int',
							},
						}),
						process: (input, output, _) -> {
							if (!input.has('foo')) {
								return Promise.NEVER;
							}
							input.get('foo');
							output.sendDone({
								out1: 1,
								out2: 0,
							});

							return Promise.NEVER;
						},
					});

					c.inPorts["foo"].attach(sin1);
					c.outPorts["out1"].attach(sout1, 1);
					c.outPorts["out2"].attach(sout2, 0);

					sout1.on('ip', (ips) -> {
						final ip:IP = ips[0];
						final exp = expected.shift();
						final received = {
							port: 'out1',
							data: ip.data,
						};
						Equal.equals(received, exp).should.be(true);
						if (expected.length == 0) {
							done();
						}
					});
					sout2.on('ip', (ips) -> {
						final ip:IP = ips[0];
						final exp = expected.shift();
						final received = {
							port: 'out2',
							data: ip.data,
						};

						Equal.equals(received, exp).should.be(true);
						if (expected.length == 0) {
							done();
						}
					});
					sin1.post(new IP('data', 'first'));
				});

				it('should not be triggered by non-triggering ports', (done) -> {
					final triggered = [];
					final c = new zenflo.lib.Component({
						inPorts: new InPorts({
							foo: {
								dataType: 'string',
								triggering: false,
							},
							bar: {dataType: 'string'},
						}),
						outPorts: new OutPorts({
							baz: {dataType: 'boolean'},
						}),
						process: (input, output, _) -> {
							triggered.push(input.port.name);
							output.sendDone({baz: true});
							return Promise.NEVER;
						},
					});

					c.inPorts["foo"].attach(sin1);
					c.inPorts["bar"].attach(sin2);
					c.outPorts["baz"].attach(sout1);

					var count = 0;
					sout1.on('ip', (_) -> {
						count++;
						if (count == 1) {
							Equal.equals(triggered, ['bar']).should.be(true);
						}
						if (count == 2) {
							Equal.equals(triggered, ['bar', 'bar']).should.be(true);
							done();
						}
					});

					sin1.post(new IP('data', 'first'));
					sin2.post(new IP('data', 'second'));
					sin1.post(new IP('data', 'first'));
					sin2.post(new IP('data', 'second'));
				});
				it('should fetch undefined for premature data', (done) -> {
					c = new zenflo.lib.Component({
						inPorts: new InPorts({
							foo: {
								dataType: 'string',
							},
							bar: {
								dataType: 'boolean',
								triggering: false,
								control: true,
							},
							baz: {
								dataType: 'string',
								triggering: false,
								control: true,
							},
						}),
						process: (input, _, _) -> {
							if (!input.has('foo')) {
								return Promise.NEVER;
							}
							final d:Array<Any> = input.getData('foo', 'bar', 'baz');
							var foo = d[0], bar = d[1], baz = d[2];
							foo.should.beType(String);
							bar.should.be(null);
							baz.should.be(null);
							done();
							return Promise.NEVER;
						},
					});

					c.inPorts["foo"].attach(sin1);
					c.inPorts["bar"].attach(sin2);
					c.inPorts["baz"].attach(sin3);

					sin1.post(new IP('data', 'AZ'));
					sin2.post(new IP('data', true));
					sin3.post(new IP('data', 'first'));
				});
				it('should receive and send complete IP objects', (done) -> {
					c = new zenflo.lib.Component({
						inPorts: new InPorts({
							foo: {dataType: 'string'},
							bar: {dataType: 'string'},
						}),
						outPorts: new OutPorts({
							baz: {datatype: 'object'},
						}),
						process: (input, output, _) -> {
							if (!input.has('foo', 'bar')) {
								return Promise.NEVER;
							}
							final d:Array<Dynamic> = input.get('foo', 'bar');
							var foo = d[0], bar = d[1];
							final baz = {
								foo: foo.data,
								bar: bar.data,
								groups: foo.groups,
								type: bar.type,
							};
							output.sendDone({
								baz: new IP('data', baz, {groups: ['baz']}),
							});
							return Promise.NEVER;
						},
					});

					c.inPorts["foo"].attach(sin1);
					c.inPorts["bar"].attach(sin2);
					c.outPorts["baz"].attach(sout1);

					sout1.once('ip', (ips) -> {
						final ip:IP = ips[0];
						ip.should.not.be(null);
						ip.type.should.be('data');
						ip.data.foo.should.be('foo');
						ip.data.bar.should.be('bar');
						var data:Dynamic = ip.data;
						var groups:Array<Any> = data.groups;
						Equal.equals(groups, ['foo']).should.be(true);
						ip.data.type.should.be('data');
						Equal.equals(ip["groups"], ['baz']).should.be(true);
						done();
					});

					sin1.post(new IP('data', 'foo', {groups: ['foo']}));
					sin2.post(new IP('data', 'bar', {groups: ['bar']}));
				});
				it('should stamp IP objects with the datatype of the outport when sending', (done) -> {
					c = new zenflo.lib.Component({
						inPorts: new InPorts({
							foo: {dataType: 'all'},
						}),
						outPorts: new OutPorts({
							baz: {dataType: 'string'},
						}),
						process: (input, output, _) -> {
							if (!input.has('foo')) {
								return Promise.NEVER;
							}
							final foo = input.get('foo');
							output.sendDone({baz: foo});

							return Promise.NEVER;
						},
					});

					c.inPorts["foo"].attach(sin1);
					c.outPorts["baz"].attach(sout1);

					sout1.once('ip', (ips) -> {
						final ip:IP = ips[0];
						ip.should.not.be(null);
						ip.type.should.be('data');
						ip.data.should.be('foo');
						ip.dataType.should.be('string');
						done();
					});

					sin1.post(new IP('data', 'foo'));
				});

				it('should stamp IP objects with the schema of the outport when sending', (done) -> {
					c = new zenflo.lib.Component({
						inPorts: new InPorts({
							foo: {
								dataType: 'all',
							},
						}),
						outPorts: new OutPorts({
							baz: {
								dataType: 'string',
								schema: 'text/markdown'
							},
						}),
						process: (input, output, _) -> {
							if (!input.has('foo')) {
								return Promise.NEVER;
							}
							final foo = input.get('foo');
							output.sendDone({baz: foo});

							return Promise.NEVER;
						},
					});

					c.inPorts["foo"].attach(sin1);
					c.outPorts["baz"].attach(sout1);

					sout1.once('ip', (ips) -> {
						final ip:IP = ips[0];
						ip.should.not.be(null);
						ip.type.should.be('data');
						ip.data.should.be('foo');
						ip.dataType.should.be('string');
						ip.schema.should.be('text/markdown');
						done();
					});

					sin1.post(new IP('data', 'foo'));
				});
				it('should stamp IP objects with the schema of the inport when receiving', (done) -> {
					c = new zenflo.lib.Component({
						inPorts: new InPorts({
							foo: {
								dataType: 'all',
								schema: 'text/markdown'
							},
						}),
						outPorts: new OutPorts({
							baz: {
								dataType: 'string'
							},
						}),
						process: (input, output, _) -> {
							if (!input.has('foo')) {
								return Promise.NEVER;
							}
							final foo = input.get('foo');
							output.sendDone({baz: foo});

							return Promise.NEVER;
						},
					});

					c.inPorts["foo"].attach(sin1);
					c.outPorts["baz"].attach(sout1);

					sout1.once('ip', (ips) -> {
						final ip:IP = ips[0];
						ip.should.not.be(null);
						ip.type.should.be('data');
						ip.data.should.be('foo');
						ip.dataType.should.be('string');
						ip.schema.should.be('text/markdown');
						done();
					});

					sin1.post(new IP('data', 'foo'));
				});

				it('should receive and send just IP data if wanted', (done) -> {
					c = new zenflo.lib.Component({
						inPorts: new InPorts({
							foo: {dataType: 'string'},
							bar: {dataType: 'string'},
						}),
						outPorts: new OutPorts({
							baz: {dataType: 'object'},
						}),
						process: (input, output, _) -> {
							if (!input.has('foo', 'bar')) {
								return Promise.NEVER;
							}
							final d = input.getData('foo', 'bar');
							final baz = {
								foo: d[0],
								bar: d[1]
							};
							output.sendDone({baz: baz});

							return Promise.NEVER;
						},
					});

					c.inPorts["foo"].attach(sin1);
					c.inPorts["bar"].attach(sin2);
					c.outPorts["baz"].attach(sout1);

					sout1.once('ip', (ips) -> {
						final ip:IP = ips[0];
						ip.should.not.be(null);
						ip.type.should.be('data');
						ip.data.foo.should.be('foo');
						ip.data.bar.should.be('bar');
						done();
					});

					sin1.post(new IP('data', 'foo', {groups: ['foo']}));
					sin2.post(new IP('data', 'bar', {groups: ['bar']}));
				});

				it('should receive IPs and be able to selectively find them', (done) -> {
					var called = 0;
					c = new zenflo.lib.Component({
						inPorts: new InPorts({
							foo: {dataType: 'string'},
							bar: {dataType: 'string'},
						}),
						outPorts: new OutPorts({
							baz: {dataType: 'object'},
						}),
						process: (input, output, _) -> {
							final validate = function(ip) {
								called++;
								return (ip.type == 'data') && (ip.data == 'hello');
							};
							if (!input.has('foo', 'bar', validate)) {
								return Promise.NEVER;
							}
							var foo = input.get('foo');
							while ((foo != null ? foo.type : null) != 'data') {
								foo = input.get('foo');
							}
							final bar = input.getData('bar');
							output.sendDone({baz: '${foo.data}:${bar}'});

							return Promise.NEVER;
						},
					});

					c.inPorts["foo"].attach(sin1);
					c.inPorts["bar"].attach(sin2);
					c.outPorts["baz"].attach(sout1);

					var shouldHaveSent = false;

					sout1.on('ip', (ips) -> {
						final ip:IP = ips[0];
						shouldHaveSent.should.be(true); // Should not sent before its time
						ip.should.not.be(null);
						ip.type.should.be('data');
						ip.data.should.be('hello:hello');
						called.should.be(10);
						done();
					});

					sin1.post(new IP('openBracket', 'a'));
					sin1.post(new IP('data', 'hello', sin1.post(new IP('closeBracket', 'a'))));
					shouldHaveSent = true;
					sin2.post(new IP('data', 'hello'));
				});

				it('should keep last value for controls', (done) -> {
					c = new zenflo.lib.Component({
						inPorts: new InPorts({
							foo: {dataType: 'string'},
							bar: {
								dataType: 'string',
								control: true,
							},
						}),
						outPorts: new OutPorts({
							baz: {dataType: 'object'},
						}),
						process: (input, output, _) -> {
							if (!input.has('foo', 'bar')) {
								return Promise.NEVER;
							}
							final d = input.getData('foo', 'bar');
							final baz = {
								foo: d[0],
								bar: d[1]
							};
							output.sendDone({baz: baz});

							return Promise.NEVER;
						},
					});

					c.inPorts["foo"].attach(sin1);
					c.inPorts["bar"].attach(sin2);
					c.outPorts["baz"].attach(sout1);

					sout1.once('ip', (ips) -> {
						final ip:IP = ips[0];
						ip.should.not.be(null);
						ip.type.should.be('data');
						ip.data.foo.should.be('foo');
						ip.data.bar.should.be('bar');
						// sout1.removeAllListeners();
                        sout1.once('ip', (_ips) -> {
                            final _ip:IP = _ips[0];
                            _ip.should.not.be(null);
                            _ip.type.should.be('data');
                            _ip.data.foo.should.be('boo');
                            _ip.data.bar.should.be('bar');
                            done();
                        });
					});

					sin1.post(new IP('data', 'foo'));
					sin2.post(new IP('data', 'bar'));
					sin1.post(new IP('data', 'boo'));
				});
			});
		});
	}
}