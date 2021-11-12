package zenflo.graph;

import haxe.DynamicAccess;

typedef GraphJson = {
    ?caseSensitive: Bool,
    ?properties: PropertyMap,
    ?processes: DynamicAccess<GraphJsonNode>,
    ?connections: Array<GraphJsonEdge>,
    ?inports:  DynamicAccess<GraphExportedPort>,
    ?outports: DynamicAccess<GraphExportedPort>,
    ?groups: Array<GraphGroup>,
  }