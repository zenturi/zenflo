package zenflo.lib;

import zenflo.lib.BasePort.BaseOptions;

/**
	Outport Port (outport) implementation for ZenFlo components.
	These ports are the way a component sends Information Packets.
**/
typedef OutPortOptions = {
	> BaseOptions,
	@:optional var caching:Null<Bool>;
}
