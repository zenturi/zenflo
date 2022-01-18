package;

import zenflo.lib.EventEmitter;
import buddy.Buddy;

using buddy.Should;
/**
	@author Damilare Akinlaja
**/
class Main implements Buddy<[TestEvent]> {}

class TestEvent extends buddy.BuddySuite {
	public function new() {
		describe("Event emitter test", {
			final eventEmitter = new EventEmitter();
			it("should emit only once", (done) -> {
				eventEmitter.once('start', (values) -> {
					final start = values[0];
					final end = values[1];
					start.should.be(1);
					end.should.be(100);
					done();
				});
				eventEmitter.emit('start', 1, 100);
				eventEmitter.emit('start', 2, 100);
			});
		});
	}
}
