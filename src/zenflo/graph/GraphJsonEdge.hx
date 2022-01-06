package zenflo.graph;

typedef GraphJsonEdge = {
	?src:GraphJsonEdgePack,
	?data:Null<Dynamic>,
	tgt:GraphJsonEdgePack,
	?metadata:GraphEdgeMetadata
}

typedef GraphJsonEdgePack = {
    process:GraphNodeID,
    port:String,
    ?index:Null<Int>
}
