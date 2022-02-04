package zenflo.spec.lib;

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
						inPorts: i,
						outPorts: o
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
						inPorts: i,
						outPorts: o,
						process: (input:ProcessInput, output:ProcessOutput, _:ProcessContext) -> {
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
		});
	}
}
