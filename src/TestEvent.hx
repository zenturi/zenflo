package;

import zenflo.lib.EventEmitter;
import buddy.Buddy;

using buddy.Should;
/**
	@author Damilare Akinlaja
**/
class TestEvent implements Buddy<[TestCase]> {}

class TestCase extends buddy.BuddySuite {
	public function new() {
		describe("Event emitter test", {
			final eventEmitter = new EventEmitter();
			it("should emit only twice", (done) -> {
				var count = 0;
				eventEmitter.on('start', (values) -> {
					final start = values[0];
					final end = values[1];
					if(count == 0){
						start.should.be(1);
					}
					if(count == 1){
						start.should.be(2);
					}
					end.should.be(100);
					count++;
					if(count != 2){
						return;
					}
					count.should.be(2);
					done();
				});
				eventEmitter.emit('start', 1, 100);
				eventEmitter.emit('start', 2, 100);
			});
		});
	}
}
