package zenflo.graph;

typedef GraphJsonEdge = {
	?src:{
		process:GraphNodeID,
		port:String,
		?index:Int,
	},
	?data:Any,
	tgt:{
		process:GraphNodeID, port:String, ?index:Int,
	},
	?metadata:GraphEdgeMetadata,
}
