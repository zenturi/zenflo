package zenflo.spec.lib;

using buddy.Should;

@colorize
class IP extends buddy.BuddySuite {
	public function new() {
		describe('IP object', {
			it('should create IPs of different types', {
				final open = new zenflo.lib.IP('openBracket');
				final data = new zenflo.lib.IP(DATA, 'Payload');
				final close = new zenflo.lib.IP('closeBracket');
				open.type.should.be('openBracket');
				close.type.should.be('closeBracket');
				data.type.should.be('data');
			});
			it('should be moved to an owner', {
				final p = new zenflo.lib.IP(DATA, 'Token');
				final someProc = new zenflo.lib.Component();
				p.move(someProc);
				p.owner.should.be(someProc);
			});
			it('should be able to clone itself', {
				var d1 = new zenflo.lib.IP(DATA, 'Trooper', {
					"groups": ['foo', 'bar'],
					owner: new zenflo.lib.Component(),
					scope: 'request-12345',
					clonable: true,
					datatype: 'string',
					schema: 'text/plain',
				});
                final d2 = d1.clone();
                d2.should.not.be(d1);
                d2.type.should.be(d1.type);
                d2.schema.should.be(d1.schema);
                d2.data.should.be(d1.data);
                d2["groups"].should.be(d1["groups"]);
                d2.owner.should.be(d1.owner);
                d2.scope.should.be(d1.scope);
			});
            it('should dispose its contents when dropped',  {
                final p = new zenflo.lib.IP(DATA, 'Garbage');
                p["groups"] = ['foo', 'bar'];
                p.drop();
                Reflect.fields(p).length.should.be(0);
              });
		});
	}
}
