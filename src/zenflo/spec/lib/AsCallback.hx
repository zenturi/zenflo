package zenflo.spec.lib;

using buddy.Should;

class AsCallback extends buddy.BuddySuite {
	public function new() {
		describe('asCallback interface', {
			final processAsync = function() {
				final c = new zenflo.lib.Component();
				c.inPorts.add('in', {dataType: 'string'});
				c.outPorts.add('out', {dataType: 'string'});

				return c.process((input, output, _) -> {
					final data = input.getData('in');
					haxe.Timer.delay(() -> output.sendDone(data), 1);
				});
			};
		});
	}
}
