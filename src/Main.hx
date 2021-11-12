package ;

import zenflo.lib.EventEmitter;

/**
	@author Damilare Akinlaja
**/
class Main {
	public static function main() {
		new Main();
	}

	public function new() {
		final eventEmitter = new EventEmitter();
		eventEmitter.on('start', (values) -> {
			final start = values[0];
			final end = values[1];
			trace('started from $start to $end');
		});
		eventEmitter.emit('start', 1, 100);
		eventEmitter.emit('start', 2, 100);
	}
}