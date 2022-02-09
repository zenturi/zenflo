package zenflo.spec.lib;

import tink.core.Error;
import zenflo.lib.InPort.InPortOptions;
using buddy.Should;

import equals.Equal;

@colorize
class Inport extends buddy.BuddySuite {
	public function new() {
		describe('Inport Port', {
			describe('with default options', {
				final p = new zenflo.lib.InPort();
				it('should be of datatype "all"', {
					p.getDataType().should.be('all');
				});
				it('should not be required', {
					p.isRequired().should.be(false);
				});
				it('should not be addressable', {
					p.isAddressable().should.be(false);
				});
				it('should not be buffered', () -> p.isBuffered().should.be(false));
			});
		});
		describe('with custom type', () -> {
			final p = new zenflo.lib.InPort({
				dataType: 'string',
				schema: 'text/url',
			});
			it('should retain the type', () -> {
				p.getDataType().should.be('string');
				p.getSchema().should.be('text/url');
			});
		});
		describe('without attached sockets', () -> {
			final p = new zenflo.lib.InPort();
			it('should not be attached', () -> {
				p.isAttached().should.be(false);
				Equal.equals(p.listAttached(), []).should.be(true);
			});
			it('should allow attaching', () -> {
				p.canAttach().should.be(true);
			});
			it('should not be connected initially', () -> {
				p.isConnected().should.be(false);
			});
			it('should not contain a socket initially', () -> {
				p.sockets.length.should.be(0);
			});
		});
		describe('with processing function called with port as context', {
			it('should set context to port itself', (done) -> {
				final s = new zenflo.lib.InternalSocket();
				final p = new zenflo.lib.InPort();
				p.on('data', (packets) -> {
					final packet = packets[0];
					packet.should.be('some-data');
					done();
				});
				p.attach(s);
				s.send('some-data');
			});
		});
		describe('with default value', {
			var p:InPort = null;
			var s:InternalSocket = null;

			beforeEach(() -> {
				p = new InPort({Default: 'default-value'});
				s = new InternalSocket();
				p.attach(s);
			});

			it('should send the default value as a packet, though on next tick after initialization', (done) -> {
				p.on('data', (datas) -> {
					final data = datas[0];
					data.should.be('default-value');
					done();
				});
				s.send();
			});
			it('should send the default value before IIP', (done) -> {
				final received = ['default-value', 'some-iip'];
				p.on('data', (datas) -> {
					final data = datas[0];
					data.should.be(received.shift());
					if (received.length == 0) {
						done();
					}
				});
         
                #if !cpp haxe.Timer.delay(()->{ #end
                    #if cpp Sys.sleep(0.10);  #end
                    s.send();
					s.send('some-iip');
                #if !cpp }, 0); #end
			});
		});
        describe('with options stored in port', () -> {
            it('should store all provided options in port, whether we expect it or not', () -> {
              final options = {
                dataType: 'string',
                type: 'http://schema.org/Person',
                description: 'Person',
                required: true,
                weNeverExpectThis: 'butWeStoreItAnyway',
              };

             final p = new zenflo.lib.InPort(options);
              for (name in Reflect.fields(options)) {
                if (Reflect.hasField(options, name)) {
                  final option = Reflect.field(options, name);
                  Equal.equals(Reflect.field(p.options, name), option).should.be(true);
                }
              }
            });
        });
        describe('with data type information',  {
            final right = 'all string number int object array'.split(' ');
            final wrong = 'not valie data types'.split(' ');
            final f = (datatype) -> new InPort({ dataType:datatype });

            Lambda.foreach(right, (r)->{
                it('should accept a \'${r}\' data type', () -> {
                    try{
                        f(r).should.not.be(null);
                    }catch(e:Error){
                        fail(e);
                    }
                });
                return true;
            });

            Lambda.foreach(wrong, (w)->{
                it('should NOT accept a \'${w}\' data type', () -> {
                    try{
                        f(w);
                    }catch(e:Error){
                        e.should.not.be(null);
                        e.should.beType(Error);
                    }
                });
                return true;
            });
        });
        describe('with TYPE (i.e. ontology) information', {
            final f = (type) -> new InPort({ type:type });
            it('should be a URL or MIME', () -> {
                try{
                    f('http://schema.org/Person').should.not.be(null);
                    f('text/javascript').should.not.be(null);
                }catch(e:Error){
                    fail(e);
                }
                try {
                    f('neither-a-url-nor-mime');
                } catch(e:Error){
                    e.should.not.be(null);
                    e.should.beType(Error);
                }
            });
        });

        describe('with accepted enumerated values', {
            it('should accept certain values', (done) ->{
                final p = new InPort({ values: 'noflo is awesome'.split(' ') });
                final s = new InternalSocket();
                p.attach(s);
                p.on('data', (datas) -> {
                    final data = datas[0];
                    data.should.be('awesome');
                    done();
                });
                s.send('awesome');
            });
            it('should throw an error if value is not accepted',  (done)->{
                final p = new InPort({ values: 'noflo is awesome'.split(' ') });
                final s = new InternalSocket();
                p.attach(s);
                p.on('data', (_) -> {
                  // Fail the test, we shouldn't have received anything
                  true.should.be(false);
                });
                
                try {
                    s.send('terrific');
                }catch(e:Error){
                    e.should.not.be(null);
                    e.should.beType(Error);
                    done();
                }
              });
        });

        describe('with processing shorthand',  {
            it('should also accept metadata (i.e. options) when provided', (done) -> {
                final s = new InternalSocket();
                final ps = {
                    outPorts: new OutPorts({ "out": new OutPort() }),
                    inPorts: new InPorts()
                };

                ps.inPorts.add("in", {
                    dataType: 'string',
                    required: true,
                });

                final _in:InPort = cast ps.inPorts.ports["in"];
                if(_in != null){
                    _in.on("ip", (ips)->{
                        final ip:zenflo.lib.IP = ips[0];
                        if (ip.type != DATA) { return; }
                        ip.data.should.be('some-data');
                        done();
                    });
                }
                _in.attach(s);
                Equal.equals(_in.listAttached(), [0]).should.be(true);
                s.send('some-data');
                s.disconnect();
            });
            it('should translate IP objects to legacy events', (done) -> {
                final s = new InternalSocket();
                final expectedEvents = [
                    'connect',
                    'data',
                    'disconnect',
                ];

                final receivedEvents = [];

                final ps = {
                    outPorts: new OutPorts({ out: new OutPort() }),
                    inPorts: new InPorts()
                };

                ps.inPorts.add('in', {
                    datatype: 'string',
                    required: true
                });

                final _in:InPort = cast ps.inPorts.ports["in"];
                _in.on('connect', (_) -> {
                    receivedEvents.push('connect');
                  });
                _in.on('data', (_) -> {
                    receivedEvents.push('data');
                });

                _in.on('disconnect', (_) -> {
                    receivedEvents.push('disconnect');
                    Equal.equals(receivedEvents, expectedEvents).should.be(true);
                    done();
                });

                _in.attach(s);
                Equal.equals(_in.listAttached(), [0]).should.be(true);
                s.post(new IP('data', 'some-data'));
            });
            it('should stamp an IP object with the port\'s datatype', (done) -> {
                final p = new InPort({ dataType: 'string' });
                p.on('ip', (datas) -> {
                    final data:IP = datas[0];
                    Reflect.isObject(data).should.be(true);
                    data.type.should.be('data');
                    data.data.should.be("Hello");
                    data.dataType.should.be('string');
                    done();
                });
                p.handleIP(new IP('data', 'Hello'));
            });
            it('should keep an IP object\'s datatype as-is if already set', (done) -> {
                final p = new InPort({ dataType: 'string' });
                p.on('ip', (datas) -> {
                    final data:IP = datas[0];
                    Reflect.isObject(data).should.be(true);
                    data.type.should.be('data');
                    data.data.should.be(123);
                    data.dataType.should.be('integer');
                    done();
                  });
                  p.handleIP(new IP('data', 123,
                    { dataType: 'integer' }));
            });
            it('should stamp an IP object with the port\'s schema', (done) -> {
                final p = new InPort({
                  dataType: 'string',
                  schema: 'text/markdown',
                });
                p.on('ip', (datas) -> {
                    final data:IP = datas[0];
                    Reflect.isObject(data).should.be(true);
                    data.type.should.be('data');
                    data.data.should.be("Hello");
                    data.dataType.should.be('string');
                    data.schema.should.be('text/markdown');
                  
                    done();
                });
                p.handleIP(new IP('data', 'Hello'));
            });
            it('should keep an IP object\'s schema as-is if already set', (done) -> {
                final p = new InPort({
                  dataType: 'string',
                  schema: 'text/markdown',
                });
                p.on('ip', (datas) -> {
                    final data:IP = datas[0];
                    Reflect.isObject(data).should.be(true);
                    data.type.should.be('data');
                    data.data.should.be("Hello");
                    data.dataType.should.be('string');
                    data.schema.should.be('text/plain');
                  done();
                });
                p.handleIP(new IP('data', 'Hello', {
                  dataType: 'string',
                  schema: 'text/plain',
                }));
            });
        });
	}
}
