package zenflo.graph;

/**
 * In-memory journal storage
 *
 */
class MemoryJournalStore extends JournalStore {
	public var transactions:ZArray<ZArray<TransactionEntry>>;

	public function new(graph:Graph) {
		super(graph);
		this.transactions = [];
	}

	override public function countTransactions():Int {
		return this.transactions.size;
	}

	public override function putTransaction(revId:Int, entries:ZArray<TransactionEntry>) {
		super.putTransaction(revId, entries);
		this.transactions.insert(revId,entries);
	}

	override public function fetchTransaction(revId:Int):ZArray<TransactionEntry> {
		return this.transactions[revId];
	}
}
