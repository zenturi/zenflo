package zenflo.lib;

import zenflo.lib.Component.BracketContext;
import haxe.DynamicAccess;


typedef ProcessResult = {
	? __resolved:Bool,

	?__bracketClosingBefore:Array<ProcessContext>,

	?__bracketContext:BracketContext,

	?__bracketClosingAfter:Array<BracketContext>,
}

typedef TProcessContext = {
	public var ?ip:IP;

	public var ?nodeInstance:Component;

	public var ?port:InPort;

	public var ?result:ProcessResult;

	public var ?activated:Bool;

	public var ?scope:Dynamic;

	public var ?deactivated:Bool;
	public var ?source:String;

	public var ?closeIp:IP;

	public var ?ports:Array<String>;
}


@:forward
abstract ProcessContext(TProcessContext) from TProcessContext  to Dynamic to TProcessContext {
	public function new(v:TProcessContext) {
		this = Reflect.copy(v);
		this.activated = false;
		this.deactivated = false;
		this.scope = this.ip.scope;
	}


	public function activate() {
		// Push a new result value if previous has been sent already
		/* eslint-disable no-underscore-dangle */
		if (this.result.__resolved || (this.nodeInstance.outputQ.indexOf(this.result) == -1)) {
			this.result = {};
		}
		this.nodeInstance.activate(this);
	}

	public function deactivate() {
		if (!this.result.__resolved) {
			this.result.__resolved = true;
		}
		this.nodeInstance.deactivate(this);
	}
}
