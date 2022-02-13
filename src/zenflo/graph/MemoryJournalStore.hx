package zenflo.graph;

/**
 * In-memory journal storage
 *
 */
class MemoryJournalStore extends JournalStore {
	public var transactions:Array<Array<TransactionEntry>>;

	public function new(graph:Graph) {
		super(graph);
		this.transactions = [];
	}

	override public function countTransactions():Int {
		return this.transactions.length;
	}

	public override function putTransaction(revId:Int, entries:Array<TransactionEntry>) {
		super.putTransaction(revId, entries);
		this.transactions.insert(revId,entries);
	}

	override public function fetchTransaction(revId:Int):Array<TransactionEntry> {
		// trace(this.transactions);
		return this.transactions[revId];
	}
}
