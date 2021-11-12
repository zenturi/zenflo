package zenflo;

typedef NetworkOptions = {
    > zenflo.lib.BaseNetwork.NetworkOptions,
    ?delay:Bool,
    ?subscribeGraph:Bool
}

function createNetwork(graphInstance:Graph, options:NetworkOptions):Promise<Any> {
    return null;
}


function loadFile(file:String, ?options:NetworkOptions):Promise<Network> {
    return null;
}