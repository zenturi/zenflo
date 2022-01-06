package zenflo.graph;

class JournalAction {
    public var name:String;

	public function new(name:String, cmd:()->Void, undo:()->Void) {
		this.name = name;
        this.execute = cmd;
        this.undo = undo;
	}

    public dynamic function execute(){};
    public dynamic function undo(){};
}