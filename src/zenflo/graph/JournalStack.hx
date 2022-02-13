package zenflo.graph;

// import polygonal.ds.ArrayList;
class JournalStack<T> {
	var dataCollection:Array<T>;

	public function new() {
		this.dataCollection = new Array<T>();
	}

	public function find(i:Int):Null<T> {
		return dataCollection[i];
	}

	public function push(item:T) {
		dataCollection.unshift(item);
	}

	public function pop():Null<T> {
		if (dataCollection.length > 0) {
			final e = dataCollection[dataCollection.length - 1];
			dataCollection.remove(e);
			return e;
		} else {
			return null;
		}
	}

	public function clear() {
		dataCollection = [];
	}
}
