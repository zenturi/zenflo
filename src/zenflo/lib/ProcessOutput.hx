package zenflo.lib;


import haxe.DynamicAccess;
import haxe.ds.Either;
import zenflo.lib.ProcessContext.ProcessResult;
import tink.core.Error;

function isError(err:Dynamic):Bool {
	return Std.isOfType(err, Error) || (Std.isOfType(err, Array) && (err.length > 0) && Std.isOfType(err[0], Error));
}

class ProcessOutput #if !cpp extends sneaker.tag.Tagged #end {
	public function new(ports:OutPorts, context:ProcessContext) {
		#if !cpp  super(); #end
		this.ports = ports;
		this.context = context;
		this.nodeInstance = this.context.nodeInstance;
		this.ip = this.context.ip;
		this.result = this.context.result;
		this.scope = this.context.scope;
		#if !cpp  this.newTag("zenflo:component"); #end
	}

	var ports:OutPorts;

	var context:ProcessContext;

	var nodeInstance:Component;

	var ip:IP;

	var result:ProcessResult;

	var scope:String;

    #if cpp
	function debug(msg:String){
		Sys.println('[zenflo:component] => $msg');
	}
	#end

	/**
		Sends an error object
	**/
	public function error(err:Dynamic) {
		final errs = Std.isOfType(err, Array) ? err : [err];
		if (this.ports.ports["error"] != null && (this.ports.ports["error"].isAttached() || !this.ports.ports["error"].isRequired())) {
			if (errs.length > 1) {
				this.sendIP('error', new IP('openBracket'));
			}
			for (index => e in errs) {
				this.sendIP('error', e);
			}

			if (errs.length > 1) {
				this.sendIP('error', new IP('closeBracket'));
			}
		} else {
			for (index => e in errs) {
				throw e;
			}
		}
	}

	/**
		Sends a single IP object to a port
	**/
	public function sendIP(port:String, packet:Dynamic) {
		final ip = IP.isIP(packet) ? packet : new IP(DATA, packet);
		if ((this.scope != null) && (ip.scope == null)) {
			ip.scope = this.scope;
		}

		if (this.nodeInstance.outPorts.ports.exists(port)) {
			throw new Error('Node ${this.nodeInstance.nodeId} does not have outport ${port}');
		}

		// eslint-disable-next-line max-len
		final portImpl = /** @type {import("./OutPort").default} */ (this.nodeInstance.outPorts.ports[port]);

		if (portImpl.isAddressable() && (ip.index == null)) {
			throw new Error('Sending packets to addressable port ${this.nodeInstance.nodeId} ${port} requires specifying index');
		}

		if (this.nodeInstance.isOrdered()) {
			this.nodeInstance.addToResult(this.result, port, ip);
			return;
		}
		if (!portImpl.options.scoped) {
			ip.scope = null;
		}
		portImpl.sendIP(Either.Left(ip));
	}

	public function send(output:Dynamic) {
		if (isError(output)) {
			final errors = /** @type {Error|Array<Error>} */ (output);
			this.error(errors);
			return;
		}

		/** @type {Array<string>} */
		final componentPorts:Array<String> = [];

		var mapIsInPorts = false;

		for (port in this.ports.ports.keys()) {
			if ((port != 'error') && (port != 'ports') && (port != '_callbacks')) {
				componentPorts.push(port);
			}
			if (!mapIsInPorts && (output != null) && (Reflect.isObject(output)) && (output.keys().indexOf(port) != -1)) {
				mapIsInPorts = true;
			}
		}

		if ((componentPorts.length == 1) && !mapIsInPorts) {
			this.sendIP(componentPorts[0], output);
			return;
		}

		if ((componentPorts.length > 1) && !mapIsInPorts) {
			throw new Error('Port must be specified for sending output');
		}

		final keys:Array<String> = output.keys();
		for (port in keys) {
			final out:DynamicAccess<Dynamic> = output;
			final packet = out[port];
			this.sendIP(port, packet);
		}
	}

	/**
		Sends the argument via `send()` and marks activation as `done()`
	**/
	public function sendDone(output:Dynamic) {
		this.send(output);
		this.done();
	}

	public function pass(data:Dynamic, options:DynamicAccess<Dynamic>) {
		if (!this.ports.ports.exists("out")) {
			throw new Error('output.pass() requires port "out" to be present');
		}
		final that = this;

		for (key in options.keys()) {
			final val = options[key];
			that.ip[key] = val;
		}
		this.ip.data = data;
		this.sendIP('out', this.ip);
		this.done();
	}

	/**
		Finishes process activation gracefully
	**/
	public function done(?error:Dynamic) {
		this.result.__resolved = true;
		this.nodeInstance.activate(this.context);
		if (error != null) {
			this.error(error);
		}

		final isLast = () -> {
			// We only care about real output sets with processing data
			final resultsOnly = this.nodeInstance.outputQ.filter((q) -> {
				if (!q.__resolved) {
					return true;
				}
				if ((Reflect.fields(q).length == 2) && q.__bracketClosingAfter != null) {
					return false;
				}
				return true;
			});
			final pos = resultsOnly.indexOf(this.result);
			final len = resultsOnly.length;
			final v = this.nodeInstance;
			final load = v.load;
			if (pos == (len - 1)) {
				return true;
			}
			if ((pos == -1) && (load == (len + 1))) {
				return true;
			}
			if ((len <= 1) && (load == 1)) {
				return true;
			}
			return false;
		};

		if (this.nodeInstance.isOrdered() && isLast()) {
			// We're doing bracket forwarding. See if there are
			// dangling closeBrackets in buffer since we're the
			// last running process function.

            final context = this.nodeInstance.bracketContext;
            final contextIn:DynamicAccess<Dynamic> = Reflect.field(context,"in");
            for (port in contextIn.keys()) {
                final contexts:DynamicAccess<Array<ProcessContext>> = contextIn[port];
                if (contexts[this.scope] != null) { return; }
                final nodeContext:Array<ProcessContext> = contexts[this.scope];
                if (nodeContext.length == 0) { return; }
                final _context:ProcessContext = nodeContext[nodeContext.length - 1];
                // eslint-disable-next-line max-len
                final inPorts = /** @type {import("./InPort").default} */ (this.nodeInstance.inPorts.ports[_context.source]);
                final buf = inPorts.getBuffer(_context.ip.scope, _context.ip.index);
                while (buf.length > 0 && buf[0].type == CloseBracket) {
                  final ip = inPorts.get(_context.ip.scope, _context.ip.index);
                  final ctx = nodeContext.pop();
                  ctx.closeIp = ip;
                  if (this.result.__bracketClosingAfter.length == 0) { this.result.__bracketClosingAfter = []; }
                  this.result.__bracketClosingAfter.push(ctx);
                }
            }
		}
        this.debug('${this.nodeInstance.nodeId} finished processing ${this.nodeInstance.load}');

        this.nodeInstance.deactivate(this.context);
	}
}
