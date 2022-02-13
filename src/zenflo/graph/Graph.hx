package zenflo.graph;

import haxe.Timer;
import ds.ArrayList;
import haxe.io.Path;
#if sys
import sys.io.File;
#end
import tink.core.Promise;
import haxe.Json;
import cloner.Cloner;
import haxe.DynamicAccess;
import zenflo.graph.GraphNodeMetadata;
import zenflo.lib.EventEmitter;
import tink.core.Error;

using equals.Equal;

function createGraph(name:String, options:GraphOptions):Graph {
	return new Graph(name, options);
}

/**
	remove everything in the graph
**/
function resetGraph(graph:Graph) {
	// Edges and similar first, to have control over the order
	// If we'd do nodes first, it will implicitly delete edges
	// Important to make journal transactions invertible
	graph.groups.reverse();
	(() -> {
		for (group in graph.groups) {
			if (group != null) {
				graph.removeGroup(group.name);
			}
		}
	})();

	(() -> {
		for (port in graph.outports.keys()) {
			graph.removeOutport(port);
		}
	})();

	(() -> {
		for (port in graph.inports.keys()) {
			graph.removeInport(port);
		}
	})();

	graph.setProperties({});
	graph.initializers.reverse();

	(() -> {
		for (iip in graph.initializers) {
			graph.removeInitial(iip.to.node, iip.to.port);
		}
	})();

	graph.edges.reverse();
	(() -> {
		for (edge in graph.edges) {
			graph.removeEdge(edge.from.node, edge.from.port, edge.to.node, edge.to.port);
		}
	})();

	graph.nodes.reverse();
	(() -> {
		for (node in graph.nodes) {
			graph.removeNode(node.id);
		}
	})();
}

/**
	Note: Caller should create transaction
	First removes everything in @base, before building it up to mirror @to
**/
function mergeResolveTheirs(base:Graph, to:Graph) {
	resetGraph(base);

	(() -> {
		for (node in to.nodes) {
			base.addNode(node.id, node.component, node.metadata);
		}
	})();

	(() -> {
		for (edge in to.edges) {
			base.addEdge(edge.from.node, edge.from.port, edge.to.node, edge.to.port, edge.metadata);
		}
	})();

	(() -> {
		for (iip in to.initializers) {
			if (iip.to.index != null) {
				base.addInitialIndex(iip.from.data, iip.to.node, iip.to.port, iip.to.index, iip.metadata != null ? iip.metadata : {});
				return;
			}
			base.addInitial(iip.from.data, iip.to.node, iip.to.port, iip.metadata != null ? iip.metadata : {});
		}
	})();
	base.setProperties(to.properties);
	(() -> {
		for (pub in to.inports.keys()) {
			final priv = to.inports[pub];
			base.addInport(pub, priv.process, priv.port, priv.metadata != null ? priv.metadata : {});
		}
	})();
	(() -> {
		for (pub in to.outports.keys()) {
			final priv = to.outports[pub];
			base.addOutport(pub, priv.process, priv.port, priv.metadata != null ? priv.metadata : {});
		}
	})();

	(() -> {
		for (group in to.groups) {
			base.addGroup(group.name, group.nodes, group.metadata != null ? group.metadata : {});
		}
	})();
}

function equivalent(a:Graph, b:Graph):Bool {
	// TODO: add option to only compare known fields
	// TODO: add option to ignore metadata
	return a.toJSON().equals(b.toJSON());
}

/**
	This class represents an abstract FBP graph containing nodes
	connected to each other with edges.

	These graphs can be used for visualization and sketching, but
	also are the way to start a ZenFlo or other FBP network.
**/
class Graph extends EventEmitter {
	public var name:String;

	public var nodes:ZArray<GraphNode>;

	public var edges:ZArray<GraphEdge>;

	public var initializers:Array<GraphIIP>;

	public var groups:ZArray<GraphGroup>;

	public var inports:DynamicAccess<GraphExportedPort>;
	public var outports:DynamicAccess<GraphExportedPort>;
	public var properties:PropertyMap;

	public var transaction:{?id:Null<String>, depth:Int};

	public var caseSensitive:Bool;

	public function new(name:String = "", ?options:GraphOptions) {
		super();
		// this.setMaxListeners(0);
		this.name = name;
		this.properties = {};
		this.nodes = new ZArray();
		this.edges = new ZArray();
		this.initializers = new Array();
		this.inports = {};
		this.outports = {};
		this.groups = new ZArray();
		this.transaction = {
			id: null,
			depth: 0,
		};

		this.caseSensitive = false;
		if (options != null && options.caseSensitive != null) {
			this.caseSensitive = options.caseSensitive;
		}
	}

	public function getPortName(port:String = ''):String {
		if (this.caseSensitive) {
			return port;
		}
		return port.toLowerCase();
	}

	public function startTransaction(id:String, ?metadata:JournalMetadata) {
		if (this.transaction.id != null) {
			throw new Error('Nested transactions not supported');
		}

		this.transaction.id = id;
		this.transaction.depth = 1;
		this.emit('startTransaction', id, metadata);
		return this;
	}

	public function endTransaction(id:String, ?metadata:JournalMetadata) {
		if (this.transaction.id == null) {
			throw new Error('Attempted to end non-existing transaction');
		}

		this.transaction.id = null;
		this.transaction.depth = 0;
		this.emit('endTransaction', id, metadata);
		return this;
	}

	public function checkTransactionStart():Graph {
		if (this.transaction.id == null) {
			this.startTransaction('implicit');
		} else if (this.transaction.id == 'implicit') {
			this.transaction.depth += 1;
		}
		return this;
	}

	public function checkTransactionEnd():Graph {
		if (this.transaction.id == 'implicit') {
			this.transaction.depth -= 1;
		}
		if (this.transaction.depth == 0) {
			this.endTransaction('implicit');
		}
		return this;
	}

	/**
		## Modifying Graph properties

		This method allows changing properties of the graph.
	**/
	public function setProperties(properties:PropertyMap) {
		this.checkTransactionStart();
		final before = this.properties.copy();
		for (item in properties.keys()) {
			final val = properties[item];
			this.properties[item] = val;
		}

		this.emit('changeProperties', this.properties, before);
		this.checkTransactionEnd();
		return this;
	}

	public function addInport(publicPort:String, nodeKey:GraphNodeID, portKey:String, ?metadata:GraphNodeMetadata) {
		// Check that node exists
		if (this.getNode(nodeKey) == null) {
			return this;
		}

		final portName = this.getPortName(publicPort);
		this.checkTransactionStart();
		this.inports[portName] = {
			process: nodeKey,
			port: this.getPortName(portKey),
			metadata: metadata,
		};
		this.emit('addInport', portName, this.inports[portName]);
		this.checkTransactionEnd();
		return this;
	}

	public function removeInport(publicPort:String):Graph {
		final portName = this.getPortName(publicPort);
		if (!this.inports.exists(portName)) {
			return this;
		}

		this.checkTransactionStart();
		final port = this.inports[portName];
		this.setInportMetadata(portName, new GraphNodeMetadata());
		this.inports.remove(portName);
		this.emit('removeInport', portName, port);
		this.checkTransactionEnd();
		return this;
	}

	public function renameInport(oldPort:String, newPort:String):Graph {
		final oldPortName = this.getPortName(oldPort);
		final newPortName = this.getPortName(newPort);
		if (!this.inports.exists(oldPortName)) {
			return this;
		}
		if (newPortName == oldPortName) {
			return this;
		}

		this.checkTransactionStart();
		this.inports[newPortName] = this.inports[oldPortName];
		this.inports.remove(oldPortName);
		this.emit('renameInport', oldPortName, newPortName);
		this.checkTransactionEnd();
		return this;
	}

	public function addOutport(publicPort:String, nodeKey:GraphNodeID, portKey:String, ?metadata:GraphNodeMetadata):Graph {
		if (metadata == null) {
			metadata = {};
		}
		// Check that node exists
		if (this.getNode(nodeKey) == null) {
			return this;
		}

		final portName = this.getPortName(publicPort);
		this.checkTransactionStart();
		this.outports[portName] = {
			process: nodeKey,
			port: this.getPortName(portKey),
			metadata: metadata,
		};
		this.emit('addOutport', portName, this.outports[portName]);

		this.checkTransactionEnd();
		return this;
	}

	public function removeOutport(publicPort:String):Graph {
		final portName = this.getPortName(publicPort);
		if (!this.outports.exists(portName)) {
			return this;
		}

		this.checkTransactionStart();

		final port = this.outports[portName];
		this.setOutportMetadata(portName, new GraphNodeMetadata());
		this.outports.remove(portName);
		this.emit('removeOutport', portName, port);

		this.checkTransactionEnd();
		return this;
	}

	public function renameOutport(oldPort:String, newPort:String):Graph {
		final oldPortName = this.getPortName(oldPort);
		final newPortName = this.getPortName(newPort);
		if (!this.outports.exists(oldPortName)) {
			return this;
		}

		this.checkTransactionStart();
		this.outports[newPortName] = this.outports[oldPortName];
		this.outports.remove(oldPortName);
		this.emit('renameOutport', oldPortName, newPortName);
		this.checkTransactionEnd();
		return this;
	}

	public function setOutportMetadata(publicPort:String, ?metadata:GraphNodeMetadata):Graph {
		final portName = this.getPortName(publicPort);
		if (!this.outports.exists(portName)) {
			return this;
		}

		this.checkTransactionStart();
		final before = this.outports[portName].metadata.copy();
		if (this.outports[portName].metadata == null) {
			this.outports[portName].metadata = new GraphNodeMetadata();
		}

		(() -> {
			for (item in metadata.keys()) {
				final val = metadata[item];
				final existingMeta = this.outports[portName].metadata;
				if (existingMeta == null) {
					continue;
				}
				if (val != null) {
					existingMeta[item] = val;
				} else {
					existingMeta.remove(item);
				}
			}
		})();
		this.emit('changeOutport', portName, this.outports[portName], before, metadata);
		this.checkTransactionEnd();
		return this;
	}

	/**
		## Grouping nodes in a graph
	**/
	public function addGroup(group:String, nodes:Array<GraphNodeID>, metadata:GraphGroupMetadata) {
		this.checkTransactionStart();

		final g = {
			name: group,
			nodes: nodes,
			metadata: metadata,
		};

		this.groups.push(g);
		this.emit('addGroup', g);

		this.checkTransactionEnd();

		return this;
	}

	public function renameGroup(oldName:String, newName:String):Graph {
		this.checkTransactionStart();
		this.groups.iter((group) -> {
			if (group == null) {
				return;
			}
			if (group.name != oldName) {
				return;
			}
			group.name = newName;
			this.emit('renameGroup', oldName, newName);
		});
		this.checkTransactionEnd();
		return this;
	}

	public function removeGroup(groupName:String):Graph {
		this.checkTransactionStart();
		for(group in this.groups){
			if (group == null) {
				this.groups.remove(group);
				continue;
			}
			if (group.name != groupName) {
				break;
			}
			this.setGroupMetadata(group.name, {});
			this.emit('removeGroup', group);
			this.groups.remove(group);
		}
		this.checkTransactionEnd();
		return this;
	}

	public function setGroupMetadata(groupName:String, metadata:GraphGroupMetadata):Graph {
		this.checkTransactionStart();
		for (group in this.groups) {
			if (group == null) {
				continue;
			}
			if (group.name != groupName) {
				continue;
			}
			final before = group.metadata.copy();
			for (item in metadata.keys()) {
				final val = metadata[item];
				if (group.metadata == null) {
					continue;
				}

				if (val != null) {
					group.metadata[item] = val;
				} else {
					group.metadata.remove(item);
				}
			}
			this.emit('changeGroup', group, before, metadata);
		}

		this.checkTransactionEnd();
		return this;
	}

	/**
		## Adding a node to the graph

		Nodes are identified by an ID unique to the graph. Additionally,
		a node may contain information on what FBP component it is and
		possible display coordinates.

		```
		myGraph.addNode('Read, 'ReadFile', {x:91, y:154});
		```
	**/
	public function addNode(id:GraphNodeID, component:String, ?metadata:GraphNodeMetadata) {
		this.checkTransactionStart();
		final node = {
			id: id,
			component: component,
			metadata: metadata,
		};
		this.nodes.push(node);
		this.emit('addNode', node);

		this.checkTransactionEnd();
		return this;
	}

	/**
		## Removing a node from the graph

		Existing nodes can be removed from a graph by their ID. This
		will remove the node and also remove all edges connected to it.

		```
		myGraph.removeNode('Read');
		```

		Once the node has been removed, the `removeNode` event will be
		emitted.
	**/
	public function removeNode(id:GraphNodeID):Graph {
		final node = this.getNode(id);
		if (node == null) {
			return this;
		}

		this.checkTransactionStart();

		this.edges.iter((edge) -> {
			if (edge != null) {
				if ((edge.from.node == node.id) || (edge.to.node == node.id)) {
					this.removeEdge(edge.from.node, edge.from.port, edge.to.node, edge.to.port);
				}
			}
		});

		for (iip in this.initializers) {
			if (iip != null && iip.to != null && iip.to.node == node.id) {
				this.removeInitial(iip.to.node, iip.to.port);
			}
		}

		Lambda.iter(this.inports.keys(), (pub) -> {
			final priv = this.inports[pub];
			if (priv.process == id) {
				this.removeInport(pub);
			}
		});
		Lambda.iter(this.outports.keys(), (pub) -> {
			final priv = this.outports[pub];
			if (priv.process == id) {
				this.removeOutport(pub);
			}
		});
		this.groups.iter((group) -> {
			if (group == null) {
				return;
			}
			final index = group.nodes.indexOf(id);
			if (index == -1) {
				return;
			}
			group.nodes.splice(index, 1);
			if (group.nodes.length == 0) {
				// Don't leave empty groups behind
				this.removeGroup(group.name);
			}
		});

		this.setNodeMetadata(id, new GraphNodeMetadata());

		this.nodes = Lambda.filter(this.nodes, (n) -> {
			if (n != node)
				return true;
			return false;
		});

		this.emit('removeNode', node);

		this.checkTransactionEnd();

		return this;
	}

	/**
		## Renaming a node

		Nodes IDs can be changed by calling this method.
	**/
	public function renameNode(oldId:GraphNodeID, newId:GraphNodeID) {
		this.checkTransactionStart();

		final node = this.getNode(oldId);
		if (node == null) {
			return this;
		}
		node.id = newId;

		Lambda.foreach(this.edges, (e) -> {
			final edge = e;
			if (edge == null) {
				return true;
			}
			if (edge.from.node == oldId) {
				edge.from.node = newId;
			}
			if (edge.to.node == oldId) {
				edge.to.node = newId;
			}

			return true;
		});

		Lambda.foreach(this.initializers, (iip) -> {
			if (iip == null) {
				return true;
			}
			if (iip.to.node == oldId) {
				iip.to.node = newId;
			}

			return true;
		});

		Lambda.foreach(this.inports.keys(), (pub) -> {
			final priv = this.inports[pub];
			if (priv.process == oldId) {
				priv.process = newId;
			}
			return true;
		});

		Lambda.foreach(this.outports.keys(), (pub) -> {
			final priv = this.outports[pub];
			if (priv.process == oldId) {
				priv.process = newId;
			}
			return true;
		});

		Lambda.foreach(this.groups, (group) -> {
			if (group == null) {
				return true;
			}
			final index = group.nodes.indexOf(oldId);
			if (index == -1) {
				return true;
			}
			final g = group;
			g.nodes[index] = newId;
			return true;
		});

		this.emit('renameNode', oldId, newId);
		this.checkTransactionEnd();
		return this;
	}

	/**
		## Connecting nodes

		Nodes can be connected by adding edges between a node's outport
		and another node's inport:

		```
		myGraph.addEdge('Read', 'out', 'Display', 'in');
		myGraph.addEdgeIndex('Read', 'out', null, 'Display', 'in', 2);
		```
		Adding an edge will emit the `addEdge` event.
	**/
	public function addEdge(outNode:GraphNodeID, outPort:String, inNode:GraphNodeID, inPort:String, ?metadata:GraphEdgeMetadata):Graph {
		if (metadata == null)
			metadata = new GraphEdgeMetadata();

		final outPortName = this.getPortName(outPort);
		final inPortName = this.getPortName(inPort);

		final some = (edges:ZArray<GraphEdge>) -> {
			for (edge in edges) {
				if ((edge.from.node == outNode) && (edge.from.port == outPortName) && (edge.to.node == inNode) && (edge.to.port == inPortName)) {
					return true;
				}
			}
			return false;
		};
		if (some(this.edges)) {
			return this;
		}
		if (this.getNode(outNode) == null) {
			return this;
		}
		if (this.getNode(inNode) == null) {
			return this;
		}

		this.checkTransactionStart();

		final edge:GraphEdge = {
			from: {
				node: outNode,
				port: outPortName,
			},
			to: {
				node: inNode,
				port: inPortName,
			},
			metadata: metadata,
		};
		this.edges.push(edge);
		this.emit('addEdge', edge);

		this.checkTransactionEnd();
		return this;
	}

	/**
		Adding an edge will emit the `addEdge` event.
	**/
	public function addEdgeIndex(outNode:GraphNodeID, outPort:String, outIndex:Null<Int>, inNode:GraphNodeID, inPort:String, ?inIndex:Null<Int>,
			?metadata:GraphEdgeMetadata) {
		if (metadata == null)
			metadata = new GraphEdgeMetadata();
		final outPortName = this.getPortName(outPort);
		final inPortName = this.getPortName(inPort);
		final inIndexVal = (inIndex == null) ? null : inIndex;
		final outIndexVal = (outIndex == null) ? null : outIndex;

		final some = (edges:ZArray<GraphEdge>) -> {
			for (edge in edges) {
				if ((edge.from.node == outNode) && (edge.from.port == outPortName) && (edge.from.index == outIndexVal) && (edge.to.node == inNode)
					&& (edge.to.port == inPortName) && (edge.to.index == inIndexVal)) {
					return true;
				}
			}
			return false;
		};
		if (some(this.edges)) {
			return this;
		}
		if (this.getNode(outNode) == null) {
			return this;
		}
		if (this.getNode(inNode) == null) {
			return this;
		}

		this.checkTransactionStart();

		final edge:GraphEdge = {
			from: {
				node: outNode,
				port: outPortName,
				index: outIndexVal,
			},
			to: {
				node: inNode,
				port: inPortName,
				index: inIndexVal,
			},
			metadata: metadata,
		};
		this.edges.push(edge);
		this.emit('addEdge', edge);

		this.checkTransactionEnd();
		return this;
	}

	/**
		## Disconnected nodes

		Connections between nodes can be removed by providing the
		nodes and ports to disconnect.

		```
		myGraph.removeEdge('Display', 'out', 'Foo', 'in');
		```

		Removing a connection will emit the `removeEdge` event.
	**/
	public function removeEdge(node:GraphNodeID, port:String, node2:GraphNodeID, port2:String) {
		if (this.getEdge(node, port, node2, port2) == null) {
			return this;
		}
		this.checkTransactionStart();
		final outPort = this.getPortName(port);
		final inPort = this.getPortName(port2);

		for (i in 0...this.edges.size) {
			if (!this.edges.inRange(i))
				continue;
			final edge = this.edges[i];
			if (node2 != null && inPort != null) {
				if ((edge.from.node == node) && (edge.from.port == outPort) && (edge.to.node == node2) && (edge.to.port == inPort)) {
					this.setEdgeMetadata(edge.from.node, edge.from.port, edge.to.node, edge.to.port, {});
					this.emit('removeEdge', this.edges.removeAt(i));
				}
			} else if (((edge.from.node == node) && (edge.from.port == outPort))
				|| ((edge.to.node == node) && (edge.to.port == outPort))) {
				this.setEdgeMetadata(edge.from.node, edge.from.port, edge.to.node, edge.to.port, {});
				this.emit('removeEdge', this.edges.removeAt(i));
			}
		}

		this.checkTransactionEnd();
		return this;
	}

	/**
		## Getting an edge

		Edge objects can be retrieved from the graph by the node and port IDs:
		```
		myEdge = myGraph.getEdge('Read', 'out', 'Write', 'in');
		```
	**/
	public function getEdge(node:GraphNodeID, port:String, node2:GraphNodeID, port2:String):Null<GraphEdge> {
		final outPort = this.getPortName(port);
		final inPort = this.getPortName(port2);

		final edges:ZArray<zenflo.graph.GraphEdge> = Lambda.filter(this.edges, (edge) -> {
			if (edge == null) {
				return false;
			}
			if (edge.from.node == node && edge.from.port == outPort && edge.to.node == node2 && edge.to.port == inPort) {
				return true;
			}
			return false;
		});

		final edge = edges[0];

		if (edge == null) {
			return null;
		}
		return edge;
	}

	/**
		## Changing an edge's metadata

		Edge metadata can be set or changed by calling this method.
	**/
	public function setEdgeMetadata(node:GraphNodeID, port:String, node2:GraphNodeID, port2:String, metadata:GraphEdgeMetadata):Graph {
		final edge = this.getEdge(node, port, node2, port2);
		if (edge == null) {
			return this;
		}

		this.checkTransactionStart();
		if (edge.metadata == null) {
			edge.metadata = {};
		}
		final before = edge.metadata.copy();

		for (item in metadata.keys()) {
			final val = metadata[item];
			if (edge.metadata == null) {
				edge.metadata = {};
			}
			if (val != null) {
				edge.metadata[item] = val;
			} else {
				edge.metadata.remove(item);
			}
		}

		this.emit('changeEdge', edge, before, metadata);
		this.checkTransactionEnd();
		return this;
	}

	/**
		## Adding Initial Information Packets

		Initial Information Packets (IIPs) can be used for sending data
		to specified node inports without a sending node instance.

		IIPs are especially useful for sending configuration information
		to components at FBP network start-up time. This could include
		filenames to read, or network ports to listen to.

		```
		myGraph.addInitial('somefile.txt', 'Read', 'source');
		myGraph.addInitialIndex('somefile.txt', 'Read', 'source', 2);
		```

		If inports are defined on the graph, IIPs can be applied calling
		the `addGraphInitial` or `addGraphInitialIndex` methods.
		```
		myGraph.addGraphInitial('somefile.txt', 'file');
		myGraph.addGraphInitialIndex('somefile.txt', 'file', 2);
		```
	**/
	public function addInitial(data:Any, node:GraphNodeID, port:String, ?metadata:GraphIIPMetadata):Graph {
		if (metadata == null)
			metadata = {};
		if (this.getNode(node) == null) {
			return this;
		}
		final portName = this.getPortName(port);

		this.checkTransactionStart();
		final initializer = {
			from: {
				data: data,
			},
			to: {
				node: node,
				port: portName,
			},
			metadata: metadata,
		};
		this.initializers.push(initializer);
		this.emit('addInitial', initializer);

		this.checkTransactionEnd();
		return this;
	}

	public function addInitialIndex(data:Any, node:GraphNodeID, port:String, ?index:Int, ?metadata:GraphIIPMetadata) {
		if (metadata == null)
			metadata = {};

		if (this.getNode(node) == null) {
			return this;
		}

		final indexVal = (index == null) ? null : index;
		final portName = this.getPortName(port);

		this.checkTransactionStart();
		final initializer = {
			from: {
				data: data,
			},
			to: {
				node: node,
				port: portName,
				index: indexVal,
			},
			metadata: metadata,
		};
		this.initializers.push(initializer);
		this.emit('addInitial', initializer);

		this.checkTransactionEnd();
		return this;
	}

	public function addGraphInitial(data:Any, node:String, ?metadata:GraphIIPMetadata):Graph {
		if (metadata == null)
			metadata = {};

		final inport = this.inports[node];
		if (inport == null) {
			return this;
		}
		return this.addInitial(data, inport.process, inport.port, metadata);
	}

	public function addGraphInitialIndex(data:Any, node:String, index:Int, ?metadata:GraphIIPMetadata):Graph {
		if (metadata == null)
			metadata = {};

		final inport = this.inports[node];
		if (inport == null) {
			return this;
		}
		return this.addInitialIndex(data, inport.process, inport.port, index, metadata);
	}

	/**
		## Removing Initial Information Packets

		IIPs can be removed by calling the `removeInitial` method.
		```
		myGraph.removeInitial('Read', 'source');
		```

		If the IIP was applied via the `addGraphInitial` or
		`addGraphInitialIndex` functions, it can be removed using
		the `removeGraphInitial` method.

		```
		myGraph.removeGraphInitial('file');
		```
		Remove an IIP will emit a `removeInitial` event.
	**/
	public function removeInitial(node:GraphNodeID, port:String) {
		final portName = this.getPortName(port);
		this.checkTransactionStart();

		this.initializers = this.initializers.filter((iip) -> {
			if (iip != null && iip.to != null && iip.to.node == node && iip.to.port == portName) {
				this.emit('removeInitial', iip);
				return false;
			}
			return true;
		});

		this.checkTransactionEnd();
		return this;
	}

	public function removeGraphInitial(node:String):Graph {
		final inport = this.inports[node];
		if (inport == null) {
			return this;
		}
		this.removeInitial(inport.process, inport.port);
		return this;
	}

	/**
		## Changing a node's metadata

		Node metadata can be set or changed by calling this method.
	**/
	public function setNodeMetadata(id:GraphNodeID, metadata:GraphNodeMetadata) {
		final node = this.getNode(id);
		if (node == null) {
			return this;
		}

		this.checkTransactionStart();

		if (node.metadata == null) {
			node.metadata = {};
		}
		final before = node.metadata.copy();
		Lambda.foreach(metadata.keys(), (item) -> {
			final val = metadata[item];
			if (val != null) {
				node.metadata[item] = val;
			} else {
				node.metadata.remove(item);
			}
			return true;
		});

		this.emit('changeNode', node, before, metadata);
		this.checkTransactionEnd();
		return this;
	}

	/**
		## Getting a node

		Nodes objects can be retrieved from the graph by their ID:
		```
		myNode = myGraph.getNode('Read');
		```
	**/
	public function getNode(id:GraphNodeID):Null<GraphNode> {
		final nodes = [for (node in this.nodes) if (node != null && node.id == id) node; else continue];
		if (nodes.length == 0) {
			return null;
		}
		return nodes[0];
	}

	public function setInportMetadata(publicPort:String, metadata:GraphNodeMetadata) {
		final portName = this.getPortName(publicPort);
		if (!this.inports.exists(portName)) {
			return this;
		}

		this.checkTransactionStart();
		if (this.inports[portName].metadata == null) {
			this.inports[portName].metadata = new GraphNodeMetadata();
		}
		final before = this.inports[portName].metadata.copy();
		Lambda.foreach(metadata.keys(), (item) -> {
			final val = metadata[item];
			final existingMeta = this.inports[portName].metadata;
			if (existingMeta == null) {
				return true;
			}
			if (val != null) {
				existingMeta[item] = val;
			} else {
				existingMeta.remove(item);
			}

			return true;
		});

		this.emit('changeInport', portName, this.inports[portName], before, metadata);
		this.checkTransactionEnd();
		return this;
	}

	public function toDOT():String {
		final cleanId = (id:String) -> {
			var re = ~/"/g;
			re.replace(id, '\\"');
		};
		final cleanPort = (port:String) -> {
			var re = ~/\./g;
			re.replace(port, '');
		}

		final wrapQuotes = (id:String) -> '"${cleanId(id)}"';

		var dot = 'digraph {\n';

		(() -> {
			for (node in this.nodes) {
				dot += '    ${wrapQuotes(node.id)} [label=${wrapQuotes(node.id)} shape=box]\n';
			}
		})();
		(() -> {
			for (id in 0...this.initializers.length) {
				final initializer = this.initializers[id];
				var data = null;
				if (Reflect.isFunction(initializer.from.data)) {
					data = 'Function';
				} else {
					data = Json.stringify(initializer.from.data);
				}
				dot += '    data${id} [label=${wrapQuotes(data)} shape=plaintext]\n';
				dot += '    data${id} -> ${wrapQuotes(initializer.to.node)}[headlabel=${cleanPort(initializer.to.port)} labelfontcolor=blue labelfontsize=8.0]\n';

				// return initializer;
			}
		})();
		// this.initializers.forEach((initializer, id) -> {
		// 	var data = null;
		// 	if (Reflect.isFunction(initializer.from.data)) {
		// 		data = 'Function';
		// 	} else {
		// 		data = Json.stringify(initializer.from.data);
		// 	}
		// 	dot += '    data${id} [label=${wrapQuotes(data)} shape=plaintext]\n';
		// 	dot += '    data${id} -> ${wrapQuotes(initializer.to.node)}[headlabel=${cleanPort(initializer.to.port)} labelfontcolor=blue labelfontsize=8.0]\n';

		// 	return initializer;
		// });

		(() -> {
			for (edge in this.edges) {
				dot += '    ${wrapQuotes(edge.from.node)} -> ${wrapQuotes(edge.to.node)}[taillabel=${cleanPort(edge.from.port)} headlabel=${cleanPort(edge.to.port)} labelfontcolor=blue labelfontsize=8.0]\n';
			}
		})();

		dot += '}';

		return dot;
	}

	public function toYUML():String {
		final yuml:Array<String> = [];

		(() -> {
			for (initializer in this.initializers) {
				yuml.push('(start)[${initializer.to.port}]->(${initializer.to.node})');
			}
		})();

		(() -> {
			for (edge in this.edges) {
				yuml.push('(${edge.from.node})[${edge.from.port}]->(${edge.to.node})');
			}
		})();

		return yuml.join(',');
	}

	public function toJSON():GraphJson {
		final json:GraphJson = {
			caseSensitive: this.caseSensitive,
			properties: {},
			inports: this.inports.copy(),
			outports: this.outports.copy(),
			groups: [],
			processes: {},
			connections: [],
		};
		json.properties = this.properties.copy();
		json.properties["name"] = this.name;

		json.properties.remove("baseDir");
		json.properties.remove("componentLoader");

		this.groups.iter((group) -> {
			final groupData:GraphGroup = {
				name: group.name,
				nodes: group.nodes,
			};
			if (group.metadata != null && group.metadata.keys().length != 0) {
				groupData.metadata = group.metadata.copy();
			}
			json.groups.push(groupData);
		});

		Lambda.foreach(this.nodes, (node) -> {
			if (json.processes == null) {
				json.processes = {};
			}
			json.processes.set(node.id, {
				component: node.component,
				metadata: {}
			});
			// json.processes[node.id] = {
			// 	component: node.component
			// };
			if (node.metadata != null) {
				json.processes[node.id].metadata = node.metadata.copy();
			}

			return true;
		});

		Lambda.foreach(this.edges, (edge) -> {
			final connection:GraphJsonEdge = {
				src: {
					process: edge.from.node,
					port: edge.from.port,
				},
				tgt: {
					process: edge.to.node,
					port: edge.to.port,
				}
			};

			if (edge.from != null && edge.from.index != null) {
				connection.src.index = edge.from.index;
			}
			if (edge.to != null && edge.to.index != null) {
				connection.tgt.index = edge.to.index;
			}

			if (edge.metadata != null && edge.metadata.keys().length != 0) {
				connection.metadata = edge.metadata.copy();
			}

			if (json.connections == null) {
				json.connections = [];
			}
			json.connections.push(connection);

			return true;
		});

		Lambda.foreach(this.initializers, (initializer) -> {
			final iip:GraphJsonEdge = {
				data: initializer.from.data,
				tgt: {
					process: initializer.to.node,
					port: initializer.to.port
				},
			};
			if (initializer.to != null && initializer.to.index != null) {
				iip.tgt.index = initializer.to.index;
			}
			if (initializer.metadata != null && initializer.metadata.keys().length != 0) {
				iip.metadata = initializer.metadata.copy();
			}
			if (json.connections == null) {
				json.connections = [];
			}
			json.connections.push(iip);

			return true;
		});

		return json;
	}

	public function save(file:String):Promise<String> {
		return new Promise<String>((resolve, reject) -> {
			final json = Json.stringify(this.toJSON(), null, '\t');
			final path = Path.withoutExtension(file);
			try {
				#if (sys || hxnodejs)
				#if sys
				File.saveContent('${path}.json', json);
				#else
				js.node.Fs.writeFileSync('${path}.json', json);
				#end
				resolve('${file}.json');
				#else
				reject(new Error("File saving not yet supported on this platform"));
				#end
			} catch (e) {
				trace(e);
				reject(new Error(e.toString()));
			}
			return null;
		});
	}

	public static function loadJSON(json:Dynamic, ?metadata:JournalMetadata):Promise<Graph> {
		if (metadata == null)
			metadata = {};

		return new Promise<Graph>((resolve, reject) -> {
			var definition:GraphJson = {};
			if (Std.isOfType(json, String)) {
				definition = Json.parse(json);
			} else {
				definition = json;
			}

			if (definition.properties == null) {
				definition.properties = {};
			}
			if (definition.processes == null) {
				definition.processes = {};
			}
			if (definition.connections == null) {
				definition.connections = [];
			}

			final graph = new Graph(definition.properties["name"], {
				caseSensitive: definition.caseSensitive == null ? false : definition.caseSensitive,
			});

			graph.startTransaction('loadJSON', metadata);
			final properties:PropertyMap = {};
				(() -> {
					for (property in definition.properties.keys()) {
						if (property == 'name') {
							continue;
						}
						if (definition.properties == null) {
							continue;
						}
						final value:Any = definition.properties[property];
						properties[property] = value;
					}
				})();

			graph.setProperties(properties);

			(() -> {
				if (definition.processes == null) {
					return;
				}
				for (id in definition.processes.keys()) {
					final def = definition.processes[id];
					if (def.metadata == null) {
						def.metadata = {};
					}
					graph.addNode(id, def.component, def.metadata);
				}
			})();

			(() -> {
				for (i in 0...definition.connections.length) {
					final conn = definition.connections[i];
					final meta = conn.metadata != null ? conn.metadata : {};
					if (conn.data != null) {
						if (conn.tgt.index != null) {
							graph.addInitialIndex(conn.data, conn.tgt.process, graph.getPortName(conn.tgt.port), conn.tgt.index, meta);
						} else {
							graph.addInitial(conn.data, conn.tgt.process, graph.getPortName(conn.tgt.port), meta);
						}
						continue;
					}
					if (conn.src == null) {
						continue;
					}

					if (conn.src.index != null || conn.tgt.index != null) {
						graph.addEdgeIndex(conn.src.process, graph.getPortName(conn.src.port), conn.src.index, conn.tgt.process,
							graph.getPortName(conn.tgt.port), conn.tgt.index, meta);
						continue;
					}
					graph.addEdge(conn.src.process, graph.getPortName(conn.src.port), conn.tgt.process, graph.getPortName(conn.tgt.port), meta);
				}
			})();

			if (definition.inports != null) {
				(() -> {
					if (definition.inports == null) {
						return;
					}
					for (pub in definition.inports.keys()) {
						final priv = definition.inports[pub];
						graph.addInport(pub, priv.process, graph.getPortName(priv.port), priv.metadata != null ? priv.metadata : {});
					}
				})();
			}

			if (definition.outports != null) {
				(() -> {
					for (pub in definition.outports.keys()) {
						if (definition.outports == null || !definition.outports.exists(pub)) {
							continue;
						}
						final priv = definition.outports[pub];
						graph.addOutport(pub, priv.process, graph.getPortName(priv.port), priv.metadata != null ? priv.metadata : {});
					}
				})();
			}

			if (definition.groups != null) {
				(() -> {
					for (group in definition.groups) {
						graph.addGroup(group.name, group.nodes, group.metadata != null ? group.metadata : {});
					}
				})();
			}

			graph.endTransaction('loadJSON');

			resolve(graph);
			return null;
		});
	}

	public static function loadFile(graphFilePath:String):Promise<Graph> {
		#if (sys || hxnodejs)
		#if sys
		var input = File.read(graphFilePath, false);
		var buf = input.readAll();
		#else
		var buf = js.node.Fs.readFileSync(graphFilePath);
		#end
		var ext = Path.extension(graphFilePath);
		if (ext == "json") {
			return loadJSON(buf.toString());
		} else if (ext == ".fbp") {
			throw "Not yet implemented for .fbp";
		}
		throw "Unsupported file";
		#else
		return Promise.resolve(null);
		#end
	}
}
