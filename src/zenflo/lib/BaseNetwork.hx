package zenflo.lib;

import zenflo.graph.GraphIIP;
import zenflo.graph.GraphEdge;
import haxe.Constraints.Function;
import haxe.macro.Expr.Case;
import zenflo.graph.GraphNode;
import zenflo.graph.GraphNodeMetadata;
import haxe.DynamicAccess;
import zenflo.lib.ComponentLoader;
import tink.core.Error;
import tink.core.Promise;
import zenflo.lib.Component;
import haxe.Timer;
import zenflo.lib.IP;
import zenflo.graph.Graph;

typedef AddNodeCallback = (err:Error, process:NetworkProcess) -> Void;

typedef NetworkProcess = {
	?id:String,
	?componentName:String,
	?component:Component
}

typedef NetworkIP = {
	?socket:InternalSocket,
	?data:Any,
}

typedef NetworkEvent = {
	?type:String,
	?payload:Dynamic
}

function connectPort(socket:InternalSocket, process:NetworkProcess, port:String, index:Null<Int>, inbound:Bool):Promise<InternalSocket> {
	if (inbound) {
		socket.to = {
			process: process,
			port: port,
			index: index
		};

		if (process.component == null || process.component.inPorts == null || process.component.inPorts.ports.get(port) == null) {
			return Promise.reject(new Error('No inport \'${port}\' defined in process ${process.id} (${socket.getId()})'));
		}
		if (process.component.inPorts.ports[port].isAddressable()) {
			process.component.inPorts.ports[port].attach(socket, index);
			return Promise.resolve(socket);
		}
		process.component.inPorts.ports[port].attach(socket);
		return Promise.resolve(socket);
	}

	socket.from = {
		process: process,
		port: port,
		index: index
	};

	if (process.component == null || process.component.outPorts == null || !process.component.outPorts.ports.exists(port)) {
		return Promise.reject(new Error('No outport \'${port}\' defined in process ${process.id} (${socket.getId()})'));
	}

	if (process.component.outPorts.ports[port].isAddressable()) {
		process.component.outPorts.ports[port].attach(socket, index);
		return Promise.resolve(socket);
	}
	process.component.outPorts.ports[port].attach(socket);
	return Promise.resolve(socket);
}

typedef NetworkOwnOptions = {
	// Project base directory for component loading
	?baseDir:String,
	// Component loader instance to use, if any
	?componentLoader:ComponentLoader,
	// Flowtrace instance to use for tracing this network run
	?flowtrace:Dynamic,
	// Make Information Packet delivery asynchronous
	?asyncDelivery:Bool
}

typedef NetworkOptions = {
	> ComponentLoaderOptions,
	> NetworkOwnOptions,
};

/**
	## The ZenFlo network coordinator

	NoFlo networks consist of processes connected to each other
	via sockets attached from outports to inports.

	The role of the network coordinator is to take a graph and
	instantiate all the necessary processes from the designated
	components, attach sockets between them, and handle the sending
	of Initial Information Packets.
**/
class BaseNetwork extends EventEmitter {
	/**
		All ZenFlo networks are instantiated with a graph. Upon instantiation
		they will load all the needed components, instantiate them, and
		set up the defined connections and IIPs.
	**/
	public function new(graph:Dynamic, ?options:NetworkOptions) {
		super();
		this.options = options;
		// Processes contains all the instantiated components for this network
		/** @type {Object<string, NetworkProcess>} */
		this.processes = new DynamicAccess();
		// Connections contains all the socket connections in the network
		/** @type {Array<internalSocket.InternalSocket>} */
		this.connections = [];
		// Initials contains all Initial Information Packets (IIPs)
		/** @type {Array<NetworkIIP>} */
		this.initials = [];
		/** @type {Array<NetworkIIP>} */
		this.nextInitials = [];
		// Container to hold sockets that will be sending default data.
		/** @type {Array<import("./InternalSocket").InternalSocket>} */
		this.defaults = [];
		// The Graph this network is instantiated with
		this.graph = graph;
		this.started = false;
		this.stopped = true;
		this.debug = true;
		this.asyncDelivery = options.asyncDelivery || false;
		/** @type {Array<NetworkEvent>} */
		this.eventBuffer = [];

		this.baseDir = null;
		#if !js
		this.baseDir = options.baseDir != null ? options.baseDir : graph.properties.baseDir != null ? graph.properties.baseDir : Sys.getCwd();
		#else
		#if nodejs 
			this.baseDir = options.baseDir != null ? options.baseDir : graph.properties.baseDir != null ? graph.properties.baseDir : untyped __js__("process.cwd()");
		#else 
			this.baseDir = options.baseDir != null ? options.baseDir : graph.properties.baseDir != null ? graph.properties.baseDir : '/';
		#end
		#end

		// As most NoFlo networks are long-running processes, the
		// network coordinator marks down the start-up time. This
		// way we can calculate the uptime of the network.
		/** @type {Date | null} */
		this.startupDate = null;

		// Initialize a Component Loader for the network
		if (options.componentLoader != null) {
			/** @type {ComponentLoader} */
			this.loader = options.componentLoader;
		} else {
			/** @type {ComponentLoader} */
			this.loader = new ComponentLoader(this.baseDir, this.options);
		}

		// Enable Flowtrace for this network, when available
		this.flowtraceName = null;
		if (options.flowtrace != null) {
			this.setFlowtrace(options.flowtrace, null);
		} else {
			this.setFlowtrace(null, null);
		}
	}

	public var options:Null<NetworkOptions>;

	public var processes:DynamicAccess<NetworkProcess>;

	public var connections:Array<InternalSocket>;

	public var initials:Array<NetworkIP>;

	public var nextInitials:Array<NetworkIP>;

	public var defaults:Array<InternalSocket>;

	public var graph:Graph;

	public var started:Bool;

	public var stopped:Bool;

	public var debug:Bool;

	public var asyncDelivery:Bool;

	public var eventBuffer:Array<NetworkEvent>;

	public var baseDir:String;

	public var startupDate:Date;

	public var loader:Null<ComponentLoader>;

	public var flowtraceName:String;
	public var flowtrace:Dynamic;

	/**
		The uptime of the network is the current time minus the start-up
		time, in seconds.
	**/
	public function upTime():Float {
		if (this.startupDate == null) {
			return 0;
		}
		return (Date.now().getTime() - this.startupDate.getTime()) / 1000;
	}

	public function getActiveProcesses():Array<String> {
		final active = [];
		if (!this.started) {
			return active;
		}
		for (name in this.processes.keys()) {
			final process = this.processes[name];
			if (process == null || process.component == null) {
				return [];
			}
			if (process.component.load > 0) {
				// Modern component with load
				active.push(name);
			}
			if (process.component.__openConnections > 0) {
				// Legacy component
				active.push(name);
			}
		}

		return active;
	}

	public function traceEvent(event:String, payload:Dynamic) {
		if (this.flowtrace == null) {
			return;
		}
		if (this.flowtraceName != null && this.flowtraceName != this.flowtrace.mainGraph) {
			// Let main graph log all events from subgraphs
			return;
		}

		switch event {
			case 'ip':
				{
					var type = "data";
					if (payload.type == OpenBracket) {
						type = 'begingroup';
					} else if (payload.type == CloseBracket) {
						type = 'endgroup';
					}
					final src = payload.socket.from != null ? {
						node: payload.socket.from.process.id,
						port: payload.socket.from.port
					} : null;
					final tgt = payload.socket.to != null ? {
						node: payload.socket.to.process.id,
						port: payload.socket.to.port
					} : null;
					this.flowtrace.addNetworkPacket('network:${type}', src, tgt, this.flowtraceName, {
						subgraph: payload.subgraph,
						group: payload.group,
						datatype: payload.datatype,
						schema: payload.schema,
						data: payload.data,
					});
				}
			case 'start':
				{
					this.flowtrace.addNetworkStarted(this.flowtraceName);
				}
			case 'end':
				{
					this.flowtrace.addNetworkStopped(this.flowtraceName);
				}
			case 'error':
				{
					this.flowtrace.addNetworkError(this.flowtraceName, payload);
				}
			default:
				{
					// No default handler
				}
		}
	}

	public function bufferedEmit(event:String, payload:Dynamic) {
		// Add the event to Flowtrace immediately
		this.traceEvent(event, payload);
		// Errors get emitted immediately, like does network end
		if (['icon', 'error', 'process-error', 'end'].contains(event)) {
			this.emit(event, payload);
			return;
		}
		if (!this.isStarted() && (event != 'end')) {
			this.eventBuffer.push({
				type: event,
				payload: payload,
			});
			return;
		}

		this.emit(event, payload);

		if (event == 'start') {
			// Once network has started we can send the IP-related events
			for (index => ev in this.eventBuffer) {
				this.emit(ev.type, ev.payload);
			}
			this.eventBuffer = [];
		}

		if (event == 'ip') {
			// Emit also the legacy events from IP
			switch (payload.type) {
				case OpenBracket:
					this.bufferedEmit('begingroup', payload);
					return;
				case CloseBracket:
					this.bufferedEmit('endgroup', payload);
					return;
				case DATA:
					this.bufferedEmit('data', payload);
				default:
			}
		}
	}

	/**
		## Loading components

		Components can be passed to the ZenFlo network in two ways:

		* As direct, instantiated objects
		* As filenames
	**/
	public function load(?component:String, ?metadata:GraphNodeMetadata):Promise<Any> {
		return this.loader.load(component, metadata);
	}

	/**
		## Add a process to the network

		Processes can be added to a network at either start-up time
		or later. The processes are added with a node definition object
		that includes the following properties:

		* `id`: Identifier of the process in the network. Typically a string
		* `component`: Filename or path of a NoFlo component, or a component instance object
	**/
	public function addNode(node:GraphNode, options:Dynamic):Promise<NetworkProcess> {
		var promise:Promise<NetworkProcess> = new Promise(null);

		if (this.processes[node.id] != null) {
			promise = Promise.resolve(this.processes[node.id]);
		} else {
			/** @type {NetworkProcess} */
			final process:NetworkProcess = {id: node.id, component: null, componentName: ""};

			// No component defined, just register the process but don't start.
			if (node.component == null) {
				this.processes[process.id] = process;
				promise = Promise.resolve(process);
			} else {
				// Load the component for the process.
				promise = this.load(node.component, node.metadata).next((instance) -> {
					cast(instance, Component).nodeId = node.id;
					process.component = cast instance;
					process.componentName = node.component;

					// Inform the ports of the node name
					final inPorts:DynamicAccess<InPort> = cast process.component.inPorts.ports;
					final outPorts:DynamicAccess<OutPort> =cast  process.component.outPorts.ports;

					for (index => name in inPorts.keys()) {
						final port = inPorts[name];
						port.node = node.id;
						port.nodeInstance = instance;
						port.name = name;
					}

					for (index => name in outPorts.keys()) {
						final port = outPorts[name];
						port.node = node.id;
						port.nodeInstance = instance;
						port.name = name;
					}

					if (cast(instance, Component).isSubgraph()) {
						this.subscribeSubgraph(process);
					}
					this.subscribeNode(process);

					// Store and return the process instance
					this.processes[process.id] = process;
					return process;
				});
			}
		}
		return promise;
	}

	public function removeNode(node:GraphNode):Promise<Any> {
		var promise:Promise<Any> = new Promise(null);

		final process:NetworkProcess = this.getNode(node.id);
		if (process == null) {
			promise = Promise.reject(new Error('Node ${node.id} not found'));
		} else {
			if (process.component == null) {
				this.processes.remove(node.id);
				return Promise.resolve(null);
			}
			promise = process.component.shutdown().next((_) -> {
				this.processes.remove(node.id);
				return Promise.resolve(null);
			});
		}
		return promise;
	}

	public function renameNode(oldId:String, newId:String):Promise<Any> {
		final process:NetworkProcess = this.getNode(oldId);
		var promise = new Promise<Any>(null);
		if (process == null) {
			promise = Promise.reject(new Error('Process ${oldId} not found'));
		} else {
			// Inform the process of its ID
			process.id = newId;
			if (process.component != null) {
				// Inform the ports of the node name
				final inPorts = process.component.inPorts.ports;
				final outPorts = process.component.outPorts.ports;

				for (index => name in inPorts.keys()) {
					final port = inPorts[name];
					if (port == null) {
						return promise;
					}
					port.node = newId;
				}

				for (index => name in outPorts.keys()) {
					final port = outPorts[name];
					if (port == null) {
						return promise;
					}
					port.node = newId;
				}
			}
			this.processes[newId] = process;

			this.processes.remove(oldId);
			promise = Promise.resolve(null);
		}

		return promise;
	}

	/**
		Get process by its ID.
	**/
	public function getNode(id:String):NetworkProcess {
		return this.processes[id];
	}

	public function connect():Promise<BaseNetwork> {
		var promise = new Promise<BaseNetwork>(null);
		final handleAll = (key:Array<Any>, method:Function) -> {
			return Lambda.fold(key, (entity:Any, next:Promise<Any>) -> {
				next.next((_) -> method(entity, {initial: true}));
			}, Promise.resolve(null));
		}

		promise = Promise.resolve(null)
			.next((_) -> handleAll(this.graph.nodes.toArray(), this.addNode.bind()))
			.next((_) -> handleAll(this.graph.edges.toArray(), this.addEdge.bind()))
			.next((_) -> handleAll(this.graph.initializers, this.addInitial.bind()))
			.next((_) -> handleAll(this.graph.nodes.toArray(), this.addDefaults.bind()))
			.next((_) -> this);
		return promise;
	}

	public function addEdge(edge:GraphEdge, options:Dynamic):Promise<InternalSocket> {
		return this.ensureNode(edge.from.node, 'outbound').next((from) -> {
			final socket = InternalSocket.createSocket(edge.metadata, {
				debug: this.debug,
				async: this.asyncDelivery,
			});
			return this.ensureNode(edge.to.node, 'inbound')
				.next((to) -> {
					// Subscribe to events from the socket
					this.subscribeSocket(socket, from);

					return connectPort(socket, to, edge.to.port, edge.to.index, true);
				})
				.next((_) -> connectPort(socket, from, edge.from.port, edge.from.index, false))
				.next((_) -> {
					this.connections.push(socket);
					return socket;
				});
		});
	}

	public function removeEdge(edge:GraphEdge):Promise<Any> {
		for (index => connection in this.connections) {
			if (connection == null) {
				return Promise.resolve(null);
			}
			if ((edge.to.node != connection.to.process.id) || (edge.to.port != connection.to.port)) {
				return Promise.resolve(null);
			}
			connection.to.process.component.inPorts.ports[connection.to.port].detach(connection);
			if (edge.from.node != null) {
				if (connection.from != null
					&& (edge.from.node == connection.from.process.id)
					&& (edge.from.port == connection.from.port)) {
					connection.from.process.component.outPorts.ports[connection.from.port].detach(connection);
				}
			}
			this.connections.splice(this.connections.indexOf(connection), 1);
		}

		return Promise.resolve(null);
	}

	public function addInitial(initializer:GraphIIP, options:Dynamic):Promise<InternalSocket> {
		return this.ensureNode(initializer.to.node, 'inbound').next((to) -> {
			final socket = InternalSocket.createSocket(initializer.metadata, {
				debug: this.debug,
				async: this.asyncDelivery,
			});

			// Subscribe to events from the socket
			this.subscribeSocket(socket);

			return connectPort(socket, to, initializer.to.port, initializer.to.index, true);
		}).next((socket) -> {
			this.connections.push(socket);
			final init = {
				socket: socket,
				data: initializer.from.data,
			};
			this.initials.push(init);
			this.nextInitials.push(init);
			if (this.isRunning()) {
				// Network is running now, send initials immediately
				(this.sendInitials)();
			} else if (!this.isStopped()) {
				// Network has finished but hasn't been stopped, set
				// started and set
				this.setStarted(true);
				(this.sendInitials)();
			}
			return socket;
		});
	}

	public function removeInitial(initializer:GraphIIP):Promise<Any> {
		for (index => connection in this.connections) {
			if (connection == null) {
				return Promise.resolve(null);
			}
			if ((initializer.to.node != connection.to.process.id) || (initializer.to.port != connection.to.port)) {
				return Promise.resolve(null);
			}
			connection.to.process.component.inPorts.ports[connection.to.port].detach(connection);
			this.connections.splice(this.connections.indexOf(connection), 1);

			for (i in 0...this.initials.length) {
				final init = this.initials[i];
				if (init == null) {
					return Promise.resolve(null);
				}
				if (init.socket != connection) {
					return Promise.resolve(null);
				}
				this.initials.splice(this.initials.indexOf(init), 1);
			}
			for (i in 0...this.nextInitials.length) {
				final init = this.nextInitials[i];
				if (init == null) {
					return Promise.resolve(null);
				}
				if (init.socket != connection) {
					return Promise.resolve(null);
				}
				this.nextInitials.splice(this.nextInitials.indexOf(init), 1);
			}
		}

		return Promise.resolve(null);
	}

	public function addDefaults(node:GraphNode, options:Dynamic):Promise<Any> {
		return this.ensureNode(node.id, 'inbound').next((process) -> Promise.inParallel(process.component.inPorts.ports.keys().map((key) -> {
			// Attach a socket to any defaulted inPorts as long as they aren't already attached.
			final port:InPort = cast process.component.inPorts.ports[key];
			if (!port.hasDefault() || port.isAttached()) {
				return Promise.resolve(0);
			}
			final socket = InternalSocket.createSocket({}, {
				debug: this.debug,
				async: this.asyncDelivery,
			});

			// Subscribe to events from the socket
			this.subscribeSocket(socket);

			return connectPort(socket, process, key, null, true).next((_) -> {
				this.connections.push(socket);
				this.defaults.push(socket);
			});
		}))).next((_) -> null);
	}

	public function ensureNode(node:String, direction:String):Promise<NetworkProcess> {
		final instance = this.getNode(node);
		if (instance == null) {
			return Promise.reject(new Error('No process defined for ${direction} node ${node}'));
		}
		if (instance.component == null) {
			return Promise.reject(new Error('No component defined for ${direction} node ${node}'));
		}
		final comp = /** @type {import("./Component").Component} */ (instance.component);
		if (!comp.isReady()) {
			return new Promise((resolve, reject) -> {
				comp.once('ready', (_) -> {
					resolve(instance);
				});
				return null;
			});
		}
		return Promise.resolve(instance);
	}

	public function setFlowtrace(flowtrace:Dynamic, ?name:String, main = true) {
		if (flowtrace == null) {
			this.flowtraceName = null;
			this.flowtrace = null;
			return;
		}
		if (this.flowtrace != null) {
			// We already have a tracer
			return;
		}

		this.flowtrace = flowtrace;
		this.flowtraceName = name != null ? name : this.graph.name;
		this.flowtrace.addGraph(this.flowtraceName, this.graph, main);
		for (nodeId in this.processes.keys()) {
			// Register existing subgraphs
			final node = this.processes[nodeId];
			final inst = /** @type {import("../components/Graph").Graph} */ (node.component);
			if (!inst.isSubgraph() || inst.network == null) {
				return;
			}
			inst.network.setFlowtrace(this.flowtrace, node.componentName, false);
		}
	}

	public function subscribeSubgraph(node:NetworkProcess) {
		if (node.component == null) {
			return;
		}
		if (!node.component.isReady()) {
			node.component.once('ready', (_) -> {
				this.subscribeSubgraph(node);
			});
			return;
		}

		final instance = /** @type {import("../components/Graph").Graph} */ (node.component);
		if (instance.network == null) {
			return;
		}

		instance.network.setDebug(this.debug);
		instance.network.setAsyncDelivery(this.asyncDelivery);
		if (this.flowtrace) {
			instance.network.setFlowtrace(this.flowtrace, node.componentName, false);
		}

		final emitSub = (type:String, data:Dynamic) -> {
			if ((type == 'process-error') /*&& (this.listeners('process-error').length == 0)*/) {
				if (data.id && data.metadata && data.error) {
					throw data.error;
				}
				throw data;
			}
			if (data == null) {
				data = {};
			}
			if (data.subgraph) {
				if (data.subgraph.unshift == null) {
					data.subgraph = [data.subgraph];
				}
				data.subgraph.unshift(node.id);
			} else {
				data.subgraph = [node.id];
			}
			this.bufferedEmit(type, data);
		};

		/**
		 * @type {IP} data
		 */
		instance.network.on('ip', (data) -> {
			emitSub('ip', data[0]);
		});

		/**
		 * @type {Error} data
		 */
		instance.network.on('process-error', (data) -> {
			emitSub('process-error', data[0]);
		});
	}

	function subscribeNode(node:NetworkProcess) {
		if (node.component == null) {
			return;
		}
		final instance = /** @type {import("./Component").Component} */ (node.component);
		instance.on('activate', (_) -> {
			if (this.debouncedEnd == null) {
				this.abortDebounce = true;
			}
		});
		instance.on('deactivate', (value) -> {
			final load:Int = value[0];
			if (load > 0) {
				return;
			}
			this.checkIfFinished();
		});
		if (instance.getIcon == null) {
			return;
		}
		instance.on('icon', (_) -> {
			this.bufferedEmit('icon', {
				id: node.id,
				icon: instance.getIcon(),
			});
		});
	}

	/**
		Subscribe to events from all connected sockets and re-emit them
	**/
	public function subscribeSocket(socket:InternalSocket, ?source:NetworkProcess) {
		socket.on('ip', (ips) -> {
			final ip:Dynamic = ips[0];
			this.bufferedEmit('ip', {
				id: socket.getId(),
				type: ip.type,
				socket: socket,
				data: ip.data,
				metadata: socket.metadata,
			});
		});
		socket.on('error', (events) -> {
			final event:Dynamic = events[0];
			// if (this.listeners('process-error').length == 0) {
			// 	if (event.id && event.metadata && event.error) {
			// 		throw event.error;
			// 	}
			// 	throw event;
			// }
			this.bufferedEmit('process-error', event);
		});
		if (source == null || source.component == null) {
			return;
		}
		final comp = /** @type {import("./Component").Component} */ (source.component);
		// Handle activation for legacy components via connects/disconnects
		socket.on('connect', (_) -> {
			if (comp.__openConnections == null) {
				comp.__openConnections = 0;
			}
			comp.__openConnections += 1;
		});
		socket.on('disconnect', (_) -> {
			comp.__openConnections -= 1;
			if (comp.__openConnections < 0) {
				comp.__openConnections = 0;
			}
			if (comp.__openConnections == 0) {
				this.checkIfFinished();
			}
		});
	}

	public function isRunning():Bool {
		return this.getActiveProcesses().length > 0;
	}

	public function sendInitials() {
		return new Promise((resolve:Dynamic, _) -> {
			Timer.delay(resolve, 0);
			return null;
		}).next((_) -> Lambda.fold(this.initials, (initial, chain:Promise<Any>) -> {
			return chain.next((_) -> {
				initial.socket.post(new IP(DATA, initial.data, {
					initial: true,
				}));
				return Promise.resolve(null);
			});
		}, Promise.resolve(null))).next((_) -> {
			// Clear the list of initials to still be sent
			this.initials = [];
			return Promise.resolve(null);
		});
	}

	public function isStarted() {
		return this.started;
	}

	public function setStarted(started:Bool) {
		if (this.started == started) {
			return;
		}
		if (!started) {
			// Ending the execution
			this.started = false;
			this.bufferedEmit('end', {
				start: this.startupDate,
				end: Date.now(),
				uptime: this.uptime(),
			});
			return;
		}

		// Starting the execution
		if (this.startupDate == null) {
			this.startupDate = Date.now();
		}
		this.started = true;
		this.stopped = false;
		this.bufferedEmit('start', {start: this.startupDate});
	}

	public function isStopped():Bool {
		return this.stopped;
	}

	public function setDebug(active:Bool) {
		if (active == this.debug) {
			return;
		}
		this.debug = active;
		for (index => socket in this.connections) {
			socket.setDebug(active);
		}

		for (index => processId in this.processes.keys()) {
			final process = this.processes[processId];
			if (process.component == null) {
				return;
			}

			final instance = process.component;
			if (instance.isSubgraph()) {
				final inst = /** @type {import("../components/Graph").Graph} */ (instance);
				inst.network.setDebug(active);
			}
		}
	}

	public function getDebug() {
		return this.debug;
	}

	public function setAsyncDelivery(active:Bool) {
		if (active == this.asyncDelivery) {
			return;
		}
		this.asyncDelivery = active;
		for (index => socket in this.connections) {
			socket.async = this.asyncDelivery;
		}
		for (key => processId in this.processes.keys()) {
			final process = this.processes[processId];
			if (process.component == null) {
				return;
			}

			final instance = process.component;
			if (instance.isSubgraph()) {
				final inst = /** @type {import("../components/Graph").Graph} */ (instance);
				inst.network.setAsyncDelivery(active);
			}
		}
	}

	var debouncedEnd:() -> Void;

	public function checkIfFinished() {
		if (this.isRunning()) {
			return;
		}

		// this.abortDebounce;
		if (this.debouncedEnd == null) {
			this.debouncedEnd = Utils.debounce(() -> {
				if (this.abortDebounce) {
					return;
				}
				if (this.isRunning()) {
					return;
				}
				this.setStarted(false);
			}, 50);
		}
		(this.debouncedEnd)();
	}

	var abortDebounce:Bool;

	function uptime():Int {
		throw new haxe.exceptions.NotImplementedException();
	}

	public function startComponents():Promise<Any> {
		if (this.processes == null || this.processes.keys().length == 0) {
			return Promise.resolve(null);
		}
		// Perform any startup routines necessary for every component.
		return Promise.inParallel(this.processes.keys().map((id) -> {
			final process = this.processes[id];
			if (process.component == null) {
				return Promise.resolve(null);
			}
			return process.component.start();
		})).next((_) -> {
			return null;
		});
	}

	public function sendDefaults():Promise<Any> {
		return Promise.inParallel(this.defaults.map((socket) -> {
			// Don't send defaults if more than one socket is present on the port.
			// This case should only happen when a subgraph is created as a component
			// as its network is instantiated and its inputs are serialized before
			// a socket is attached from the "parent" graph.
			if (socket.to.process.component.inPorts.ports[socket.to.port].sockets.length != 1) {
				return Promise.resolve(null);
			}
			socket.connect();
			socket.send();
			socket.disconnect();
			return Promise.resolve(null);
		})).next((_) -> null);
	}

	public function start():Promise<BaseNetwork> {
		if (this.debouncedEnd == null) {
			this.abortDebounce = true;
		}

		var promise = null;
		if (this.started) {
			promise = this.stop().next((_) -> this.start());
		} else {
			this.initials = this.nextInitials.slice(0);
			this.eventBuffer = [];
			promise = this.startComponents()
				.next((_) -> this.sendInitials())
				.next((_) -> this.sendDefaults())
				.next((_) -> {
					this.setStarted(true);
					return Promise.resolve(this);
				});
		}

		return promise;
	}

	public function stop():Promise<BaseNetwork> {
		if (this.debouncedEnd == null) {
			this.abortDebounce = true;
		}

		var promise:Promise<BaseNetwork> = null;
		if (!this.started) {
			this.stopped = true;
			promise = Promise.resolve(this);
		} else {
			// Disconnect all connections
			for (index => connection in this.connections) {
				if (!connection.isConnected()) {
					return promise;
				}
				connection.disconnect();
			}

			if (this.processes == null || this.processes.keys().length == 0) {
				// No processes to stop
				this.setStarted(false);
				this.stopped = true;
				promise = Promise.resolve(this);
			} else {
				// Emit stop event when all processes are stopped
				promise = Promise.inParallel(this.processes.keys().map((id) -> {
					if (this.processes[id].component != null) {
						return Promise.resolve(null);
					}
					// eslint-disable-next-line max-len
					final comp = /** @type {import("./Component").Component} */ (this.processes[id].component);
					return comp.shutdown();
				})).next((_) -> {
					this.setStarted(false);
					this.stopped = true;
					return Promise.resolve(this);
				});
			}
		}
		return promise;
	}
}
