package zenflo.spec.lib;

import equals.Equal;

using buddy.Should;

@colorize
class Ports extends buddy.BuddySuite {
	public function new() {
		describe('Ports collection', {
			describe('InPorts', {
				final p = new InPorts();
				it('should initially contain no ports', () -> {
					Equal.equals(p.ports, {}).should.be(true);
				});
				it('should allow adding a port', {
					p.add('foo', {dataType: 'string'});
					Reflect.isObject(p.ports['foo']).should.be(true);
					p.ports['foo'].getDataType().should.be('string');
				});
				it('should allow overriding a port', {
					p.add('foo', {dataType: 'boolean'});
					Reflect.isObject(p.ports['foo']).should.be(true);
					p.ports['foo'].getDataType().should.be('boolean');
				});
				it('should throw if trying to add an \'add\' port', {
					try {
						(() -> p.add('add'))();
					} catch (e) {
						e.should.not.be(null);
					}
				});
				it('should throw if trying to add an \'remove\' port', {
					try {
						(() -> p.add('remove'))();
					} catch (e) {
						e.should.not.be(null);
					}
				});
				it('should throw if trying to add a port with invalid characters', () -> {
					try {
						(() -> p.add('hello world!'))();
					} catch (e) {
						e.should.not.be(null);
					}
				});
				it('should throw if trying to remove a port that doesn\'t exist', () -> {
					try {
						(() -> p.remove('bar'))();
					} catch (e) {
						e.should.not.be(null);
					}
				});
				it('should throw if trying to subscribe to a port that doesn\'t exist', {
					try {
						(() -> p.once('bar', 'ip', (_) -> {}))();
					} catch (e) {
						e.should.not.be(null);
					}
					try {
						(() -> p.on('bar', 'ip', (_) -> {}))();
					} catch (e) {
						e.should.not.be(null);
					}
				});
				it('should allow subscribing to an existing port', (done) -> {
					var received = 0;
					p.ports['foo'].once('ip', (_) -> {
						received++;
						if (received == 2) {
							done();
						}
					});
					p.ports['foo'].on('ip', (_) -> {
						received++;
						if (received == 2) {
							done();
						}
					});
					final foo:InPort = cast p['foo'];
					foo.handleIP(new IP('data', null));
				});
				it('should be able to remove a port', {
					p.remove('foo');
					Equal.equals(p.ports, {}).should.be(true);
				});
			});

			describe('OutPorts', {
				final p = new OutPorts();
				it('should initially contain no ports', {
					Equal.equals(p.ports, {}).should.be(true);
				});
				it('should allow adding a port', {
					p.add('foo', {dataType: 'string'});
					Reflect.isObject(p.ports['foo']).should.be(true);
					p.ports['foo'].getDataType().should.be('string');
				});
                it('should throw if trying to add an \'add\' port',  {
                    try {
                        (() -> p.add('add'))();
                    } catch(e){
                        e.should.not.be(null);
                    }
                });
                it('should throw if trying to add an \'remove\' port',  {
                    try {
                        (() -> p.add('remove'))();
                    } catch(e){
                        e.should.not.be(null);
                    }
                });
                it('should throw when calling connect with port that doesn\'t exist', {
                    try {
                        (() -> p.connect('bar'))();
                    } catch(e){
                        e.should.not.be(null);
                    }
                });
                it('should throw when calling beginGroup with port that doesn\'t exist',  {
                    try {
                        (() -> p.beginGroup('bar'))();
                    } catch (e){
                        e.should.not.be(null);
                    }
                });
                it('should throw when calling send with port that doesn\'t exist',  {
                    try {
                        (() -> p.send('bar'))();
                    } catch (e){
                        e.should.not.be(null);
                    }
                });
                it('should throw when calling endGroup with port that doesn\'t exist',  {
                    try {
                        (() -> p.endGroup('bar'))();
                    } catch (e){
                        e.should.not.be(null);
                    }
                });
                it('should throw when calling disconnect with port that doesn\'t exist',  {
                    try {
                        (() -> p.disconnect('bar'))();
                    } catch (e){
                        e.should.not.be(null);
                    }
                });
			});
		});
	}
}
