package zenflo.graph;

import polygonal.ds.ArrayList;

class JournalStack<T> {
    final dataCollection:ArrayList<T>;

	public function new() {
		this.dataCollection = new ArrayList<T>();
	}

    public function find(i:Int):Null<T>{
        return dataCollection.get(i);
    }

    public function push(item:T) {
        dataCollection.pushFront(item);
    }

    public function pop():Null<T> {
        if(dataCollection.size > 0){
            return dataCollection.removeAt(dataCollection.size - 1);
        } else {
            return null;
        }
    }

    public function clear() {
        dataCollection.clear();
    }
}