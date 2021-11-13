package zenflo.graph;



typedef GraphEdge = {
	from:{
		node:GraphNodeID, port:String, ?index:Int
	},
	to:{
		node:GraphNodeID, port:String, ?index:Int
	},
	?metadata:Null<GraphEdgeMetadata>,
}
