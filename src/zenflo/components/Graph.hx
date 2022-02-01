package zenflo.components;

import zenflo.lib.OutPort;
import zenflo.lib.InPort;
import zenflo.lib.ProcessContext;
import zenflo.lib.BaseNetwork;
import tink.core.Error;
import zenflo.lib.IP;
import zenflo.graph.GraphNodeMetadata;
import tink.core.Promise;
import zenflo.lib.Component;
import zenflo.lib.ComponentLoader;


function getComponent(metadata:GraphNodeMetadata) {
    return new Graph(metadata);
}

@:forward
abstract SubgraphContext(ProcessContext) from ProcessContext to ProcessContext from Dynamic {}

class Graph extends Component {
	public var loader:ComponentLoader;

	public function new(metadata:GraphNodeMetadata) {
		super();

		this.metadata = metadata;
		/** @type {import("../lib/Network").Network|null} */
		this.network = null;
		this.ready = true;
		this.started = false;
		this.starting = false;
		/** @type {string|null} */
		this.baseDir = null;
		/** @type {noflo.ComponentLoader|null} */
		this.loader = null;
		this.load = 0;

		this.inPorts = new zenflo.lib.InPorts({
			graph: {
				dataType: 'all',
				description: 'NoFlo graph definition to be used with the subgraph component',
				required: true,
			},
		});
		this.outPorts = new zenflo.lib.OutPorts();

		this.inPorts.ports["graph"].on('ip', (vals) -> {
			final packet:IP = vals[0];
			if (packet.type != DATA) {
				return;
			}
			// TODO: Port this part to Process API and use output.error method instead
			try {
				this.setGraph(packet.data);
			} catch (e:Error) {
				this.error(e);
			}
		});
	}

	public function setGraph(graph:Dynamic):Promise<Network> {
		this.ready = false;
		if (Std.isOfType(graph, String) || Std.isOfType(graph, zenflo.graph.Graph)) {
			if (Std.isOfType(graph, zenflo.graph.Graph)) {
				return this.createNetwork(graph);
			}

			// JSON definition of a graph
			return zenflo.graph.Graph.loadJSON(graph).next((instance) -> this.createNetwork(instance));
		}

		var graphName:String = graph;
		if ((graphName.substr(0, 1) != '/') && (graphName.substr(1, 1) != ':')) {
			#if sys
			var cwd = Sys.getCwd();
			graphName = '${cwd}/${graphName}';
			#else
			graphName = '${graphName}';
			#end
		}
		return zenflo.graph.Graph.loadFile(graphName).next((instance) -> this.createNetwork(instance));
	}

	var metadata:GraphNodeMetadata;

	var ready:Bool;

	var starting:Bool;

	public function createNetwork(graph:zenflo.graph.Graph):Promise<Network> {
		this.description = graph.properties["description"] != null ? graph.properties["description"] : '';
		this.icon = graph.properties["icon"] != null ? graph.properties["icon"] : this.icon;
		final graphObj = graph;
		if (graphObj.name == null && this.nodeId != null) {
			graphObj.name = this.nodeId;
		}

		return Zenflo.createNetwork(graph, {
			delay: true,
			subscribeGraph: false,
			componentLoader: this.loader,
			baseDir: this.baseDir
		}).next((network) -> {
			this.network = /** @type {import("../lib/Network").Network} */ (network);
			this.emit('network', network);
			// Subscribe to network lifecycle
			this.subscribeNetwork(this.network);
			// Wire the network up
			return cast(network, BaseNetwork).connect();
		}).next((network) -> {
			for (name in network.processes.keys()) {
				// Map exported ports to local component
				final node = network.processes[name];
				this.findEdgePorts(name, node);
			}

			// Finally set ourselves as "ready"
			this.setToReady();

			return cast(network, Network);
		});
	}

	public function subscribeNetwork(network:Network) {
		final contexts:Array<SubgraphContext> = [];
		network.on('start', (_) -> {
			final ctx:SubgraphContext = {
				activated: false,
				deactivated: false,
				result: {}
			};
			contexts.push(ctx);
			this.activate(ctx);
		});
		network.on('end', (_) -> {
			final ctx = contexts.pop();
			if (ctx == null) {
				return;
			}
			this.deactivate(ctx);
		});
	}

	public function isExportedInport(port:InPort, nodeName:String, portName:String):Any {
		if (this.network == null) {
			return false;
		}
		// First we check disambiguated exported ports
		final keys = this.network.graph.inports.keys();
		for (i in 0...keys.length) {
			final pub = keys[i];
			final priv = this.network.graph.inports[pub];
			if (priv.process == nodeName && priv.port == portName) {
				return pub;
			}
		}

		// Component has exported ports and this isn't one of them
		return false;
	}

	public function isExportedOutport(port:OutPort, nodeName:String, portName:String):Any {
		if (this.network == null) {
			return false;
		}
		// First we check disambiguated exported ports
		final keys = this.network.graph.outports.keys();
		for (i in 0...keys.length) {
			final pub = keys[i];
			final priv = this.network.graph.inports[pub];
			if (priv.process == nodeName && priv.port == portName) {
				return pub;
			}
		}

		// Component has exported ports and this isn't one of them
		return false;
	}

	public function setToReady() {
		haxe.Timer.delay(() -> {
			this.ready = true;
			return this.emit('ready');
		}, 0);
	}

	public function findEdgePorts(name:String, ?process:Null<NetworkProcess>):Bool {
		if (process.component == null) {
			return false;
		}
		final inPorts = process.component.inPorts.ports;
		final outPorts = process.component.outPorts.ports;
		(() -> {
			for (portName => port in inPorts) {
				final targetPortName = this.isExportedInport(cast port, name, portName);
				if (Std.isOfType(targetPortName, String)) {
					return;
				}
				this.inPorts.add(targetPortName, port);
				this.inPorts.ports[targetPortName].on('connect', (_) -> {
					// Start the network implicitly if we're starting to get data
					if (this.starting || this.network == null) {
						return;
					}
					if (cast(this.network, BaseNetwork).isStarted()) {
						return;
					}
					if (this.network.startupDate != null) {
						// Network was started, but did finish. Re-start simply
						this.network.setStarted(true);
						return;
					}
					// Network was never started, start properly
					this.setUp();
				});
			}
		})();

		(() -> {
			for (portName => port in outPorts) {
				final targetPortName = this.isExportedOutport(cast port, name, portName);
				if (Std.isOfType(targetPortName, String)) {
					return;
				}
				this.outPorts.add(targetPortName, port);
			}
		})();

		return true;
	}

	override public function isReady() {
		return this.ready;
	}

	override public function isSubgraph() {
		return true;
	}

	override public function setUp():Promise<Any> {
		this.starting = true;
		if (!this.isReady()) {
			return new Promise((resolve, reject) -> {
				this.once('ready', (_) -> {
					this.setUp().handle((c) -> {
						switch c {
							case Success(data): {
									resolve(data);
								}
							case Failure(failure): reject(failure);
						}
					});
				});

                return null;
			});
		}
		if (this.network == null) {
			return Promise.resolve(null);
		}
		return this.network.start().next((_) -> {
			this.starting = false;
		});
	}

	public override function tearDown():Promise<Dynamic> {
		this.starting = false;
		if (this.network == null) {
			return Promise.resolve({});
		}
		return this.network.stop().next((_) -> {});
	}
}
