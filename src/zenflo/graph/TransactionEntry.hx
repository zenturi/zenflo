package zenflo.graph;

import haxe.DynamicAccess;

typedef TransactionEntry = {
	?cmd:String,
	?args:Dynamic,
	?rev:Null<Int>,
	?old:Null<JournalMetadata>,
	?_new:Null<JournalMetadata>,
}

