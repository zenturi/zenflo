package zenflo.graph;

import zenflo.lib.EventEmitter;

/**
 * General interface for journal storage
 */
abstract class JournalStore extends EventEmitter {
	public var graph:Graph;
	public var lastRevision:Int;

	public function new(graph:Graph) {
		super();
		this.graph = graph;
		this.lastRevision = 0;
	}

	public function countTransactions():Int {
		return 0;
	}

	public function putTransaction(revId:Int, entries:Array<TransactionEntry>) {
		if (revId > this.lastRevision) {
			this.lastRevision = revId;
		}
		this.emit('transaction', revId, entries);
	}

	public function fetchTransaction(revId:Int):Array<TransactionEntry> {
		return [];
	}
}
