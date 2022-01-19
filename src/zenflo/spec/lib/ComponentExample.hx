package zenflo.spec.lib;

import haxe.Json;
import haxe.Timer;
import zenflo.lib.InternalSocket;
import zenflo.spec.lib.MergeObjects.getComponent;
import tink.core.Error;

using buddy.Should;

@colorize
class ComponentExample extends buddy.BuddySuite {
	public function new() {
		describe("MergeObjects component", {
			var c:Null<Component> = null;
			var sin1:Null<InternalSocket> = null;
			var sin2:Null<InternalSocket> = null;
			var sin3:Null<InternalSocket> = null;
			var sout1:Null<InternalSocket> = null;
			var sout2:Null<InternalSocket> = null;

			final obj1 = {
				name: 'Patrick',
				age: 21,
			};
			final obj2 = {
				title: 'Attorney',
				age: 33,
			};

			beforeAll((done) -> {
				c = getComponent();
				sin1 = new InternalSocket();
				sin2 = new InternalSocket();
				sin3 = new InternalSocket();
				sout1 = new InternalSocket();
				sout2 = new InternalSocket();

				final _obj1:InPort = c.inPorts.ports["obj1"];
				_obj1.attach(sin1);
				final _obj2:InPort = c.inPorts.ports["obj2"];
				_obj2.attach(sin2);
				final _overwrite:InPort = c.inPorts.ports["overwrite"];
				_overwrite.attach(sin3);

				final _result:OutPort = c.outPorts.ports["result"];
				_result.attach(sout1);
				final _error:OutPort = c.outPorts.ports["error"];
				_error.attach(sout2);

				done();
			});

			beforeEach((done) -> {
				sout1.removeAllListeners();
				sout2.removeAllListeners();
				done();
			});

			it('should not trigger if input is not complete', (done) -> {
				sout1.once('ip', (_) -> {
					fail(new Error('Premature result'));
				});
				sout2.once('ip', (_) -> {
					fail(new Error('Premature error'));
				});

				sin1.post(new IP(DATA, obj1));
				sin2.post(new IP(DATA, obj2));

				Timer.delay(done, 10);
			});

			it('should merge objects when input is complete', (done) -> {
				sout1.once('ip', (ips) -> {
					final ip:IP = ips[0];
					Reflect.isObject(ip).should.be(true);
					ip.type.should.be('data');
					Reflect.isObject(ip.data).should.be(true);
					if (ip.data != null) {
						ip.data.name.should.be(obj1.name);
						ip.data.title.should.be(obj2.title);
						ip.data.age.should.be(obj1.age);
					}

					done();
				});
				sout2.once('ip', (ips) -> {
					final ip:IP = ips[0];
					done();
				});

				sin3.post(new IP(DATA, false));
			});

			it('should obey the overwrite control', (done) -> {
				sout1.once('ip', (ips) -> {
					final ip:IP = ips[0];
					Reflect.isObject(ip).should.be(true);
					ip.type.should.be('data');
					Reflect.isObject(ip.data).should.be(true);
					if (ip.data != null) {
						ip.data.name.should.be(obj1.name);
						ip.data.title.should.be(obj2.title);
						ip.data.age.should.be(obj2.age);
					}

					done();
				});
				sout2.once('ip', (ips) -> {
					final ip:IP = ips[0];

					done();
				});

				sin3.post(new IP(DATA, true));
				sin1.post(new IP(DATA, obj1));
				sin2.post(new IP(DATA, obj2));
			});
		});
	}
}
