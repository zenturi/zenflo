package zenflo.lib;

import zenflo.graph.GraphIIP;
import zenflo.graph.GraphEdge;
import zenflo.graph.GraphNode;
import zenflo.lib.BaseNetwork.NetworkProcess;
import tink.core.Promise;




/**
	## The ZenFlo network coordinator

	ZenFlo networks consist of processes connected to each other
	via sockets attached from outports to inports.

	The role of the network coordinator is to take a graph and
	instantiate all the necessary processes from the designated
	components, attach sockets between them, and handle the sending
	of Initial Information Packets.
**/
class Network extends BaseNetwork {
	/**
		Add a process to the network. The node will also be registered
		with the current graph.
	**/
	override public function addNode(node:GraphNode, options:Dynamic):Promise<NetworkProcess> {
		options = options == null ? {} : options;
		final promise = super.addNode(node, options).next((process) -> {
			if (!options.initial) {
				this.graph.addNode(node.id, node.component, node.metadata);
			}
			return process;
		});
		return promise;
	}

	/**
		Remove a process from the network. The node will also be removed
		from the current graph.
	**/
	override public function removeNode(node:GraphNode):Promise<Void> {
		return super.removeNode(node).next((_) -> {
			this.graph.removeNode(node.id);
			return null;
		});
	}

	override public function renameNode(oldId:String, newId:String):Promise<Void> {
		return super.renameNode(oldId, newId).next((_) -> {
			this.graph.renameNode(oldId, newId);
			return null;
		});
	}

	override public function removeEdge(edge:GraphEdge):Promise<Void> {
		return super.removeEdge(edge).next((_) -> {
			this.graph.removeEdge(edge.from.node, edge.from.port, edge.to.node, edge.to.port);
			return null;
		});
	}

    public override function addInitial(iip:GraphIIP, options:Dynamic):Promise<InternalSocket> {
        return super.addInitial(iip, options).next((socket) -> {
            if (options.initial == null) {
              this.graph.addInitialIndex(
                iip.from.data,
                iip.to.node,
                iip.to.port,
                iip.to.index,
                iip.metadata
              );
            }
            return socket;
          });
    }

    public override function removeInitial(iip:GraphIIP):Promise<Any> {
        return super.removeInitial(iip).next((_)->{
            this.graph.removeInitial(iip.to.node, iip.to.port);
        });
    }
    
}
