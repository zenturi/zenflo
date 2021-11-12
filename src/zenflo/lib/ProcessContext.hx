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

	public var ?scope:String;

	public var ?deactivated:Bool;
	public var ?source:String;

	public var ?closeIp:IP;

	public var ?ports:Array<String>;
}


@:forward
abstract ProcessContext(TProcessContext) from TProcessContext  to Dynamic to TProcessContext {
	public function new(ip:IP, nodeInstance:Component, port:InPort, result:Dynamic) {
		this.ip = ip;
		this.nodeInstance = nodeInstance;
		this.port = port;
		this.result = result;
		this.scope = this.ip.scope;
		this.activated = false;
		this.deactivated = false;
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
