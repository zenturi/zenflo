package zenflo.graph;

import zenflo.graph.GraphNodeID;
import zenflo.lib.Component;

typedef GraphNode = {
    id:GraphNodeID,
    component:String,
    ?metadata:Null<GraphNodeMetadata>
}