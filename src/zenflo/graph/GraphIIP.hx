package zenflo.graph;

typedef GraphIIP = {
	?to:{
		node:GraphNodeID,
		port:String,
		?index:Int,
	},
	?from:{
		data:Any
	},
	?metadata:GraphIIPMetadata,
}
