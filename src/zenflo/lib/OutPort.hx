package zenflo.lib;

import haxe.Json;
import zenflo.lib.IP.IPType;
import zenflo.lib.IP.IPDynamic;
import tink.core.Error;
import haxe.DynamicAccess;
import zenflo.lib.BasePort.BaseOptions;
import haxe.ds.Either;



class OutPort extends BasePort {
	public final cache:DynamicAccess<IP>;

	public function new(?options:OutPortOptions) {
		final opts:OutPortOptions = options != null ? options : {};
		if (opts.scoped == null) {
			opts.scoped = true;
		}
		if (opts.caching == null) {
			opts.caching = false;
		}
		super(opts);

		final baseOptions = this.options;
		this.options = /** @type {PortOptions} */ (baseOptions);

		/** @type {Object<string, IP>} */
		this.cache = new DynamicAccess<IP>();
	}

	override public function attach(socket:InternalSocket, ?index:Int) {
		super.attach(socket, index);
		if (this.isCaching() && (this.cache['${index}'] != null)) {
			this.send(this.cache['${index}'], index);
		}
	}

	public function connect(?index:Int) {
		final sockets = this.getSockets(index);
		this.checkRequired(sockets);
		for (socket in sockets) {
			if (socket == null) {
				return;
			}
			socket.connect();
		}
	}

	function getSockets(index:Null<Int>):Array<InternalSocket> {
		// Addressable sockets affect only one connection at time
		if (this.isAddressable()) {
			if (index == null) {
				throw new Error('${this.getId()} Socket ID required;');
			}
			final idx = /** @type {number} */ (index);
			if (this.sockets[idx] == null) {
				return [];
			}
			return [this.sockets[idx]];
		}
		// Regular sockets affect all outbound connections
		return this.sockets;
	}

	function checkRequired(sockets:Array<InternalSocket>) {
		if ((sockets.length == 0) && this.isRequired()) {
			throw new Error('${this.getId()}: No connections available');
		}
	}

	public function isCaching() {
		final op:Dynamic = this.options;
		if (op != null && op.caching) {
			return true;
		}
		return false;
	}

	public function send(data:Any, ?index:Int) {
		final sockets = this.getSockets(index);
		this.checkRequired(sockets);
		
		if (this.isCaching() && (data != this.cache['${index}'])) {
			this.cache['${index}'] = data;
		}

		for (socket in sockets) {
			if (socket == null) {
				return;
			}
			socket.send(data);
		}
	}

	public function beginGroup(group:String, ?index:Int) {
		final sockets = this.getSockets(index);
		trace(sockets);
		this.checkRequired(sockets);
		for (socket in sockets) {
			if (socket == null) {
				return;
			}
			socket.beginGroup(group);
		}
	}

	public function endGroup(?index:Int) {
		final sockets = this.getSockets(index);
		this.checkRequired(sockets);
		for (socket in sockets) {
			if (socket == null) {
				return;
			}
			socket.endGroup();
		}
	}

	public function disconnect(?index:Int) {
		final sockets = this.getSockets(index);
		this.checkRequired(sockets);
		for (socket in sockets) {
			if (socket == null) {
				return;
			}
			socket.disconnect();
		}
	}

	public function openBracket(?data:String, ?options:IPDynamic, ?index:Int) {
		return this.sendIP(Either.Right(OpenBracket), data, options, index);
	}

	public function data(?data:Dynamic, ?options:IPDynamic, ?index:Int) {
		return this.sendIP(Either.Right(DATA), data, options, index);
	}

	public function sendIP(type:Either<IP, IPType>, ?data:Null<Any>, ?options:Null<IPDynamic>, ?index:Null<Int>, autoConnect = true) {
		/** @type {IP} */
		var ip:IP = null;

		var idx = index;
		switch type {
			case Left(v):
				{
					ip = v;
					idx = ip.index;
					
				}
			case Right(v):
				{
					ip = new IP(v, data, options);
				}
		}

		final sockets = this.getSockets(idx);
		
		this.checkRequired(sockets);

		if (ip.dataType == 'all') {
			// Stamp non-specific IP objects with port datatype
			ip.dataType = this.getDataType();
		}
		if (this.getSchema() != null && ip.schema == null) {
			// Stamp non-specific IP objects with port schema
			ip.schema = this.getSchema();
		}

		final cachedData = this.cache['${idx}'] != null ? this.cache['${idx}'].data : null;
		if (this.isCaching() && data != cachedData) {
			this.cache['${idx}'] = ip;
		}
		var pristine = true;
		Lambda.iter(sockets, (socket)->{
			if (socket == null) {
				return;
			}
			if (pristine) {
				socket.post(ip, autoConnect);
				pristine = false;
			} else {
				if (ip.clonable) {
					ip = ip.clone();
				}
				socket.post(ip, autoConnect);
			}
		});
		return this;
	}

	// var autoConnect(default, null):Bool = false;

	public function closeBracket(?data:Any, ?options:Any, index = null) {
		return this.sendIP(Either.Right(CloseBracket), data, options, index);
	}
}


