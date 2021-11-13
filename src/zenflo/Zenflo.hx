package zenflo;




/**
    ### Network options

    It is possible to pass some options to control the behavior of network creation:

    * `baseDir`: (default: cwd) Project base directory used for component loading
    * `componentLoader`: (default: NULL) NoFlo ComponentLoader instance to use for the
    network. New one will be instantiated for the baseDir if this is not given.
    * `delay`: (default: FALSE) Whether the network should be started later. Defaults to
    immediate execution
    * `flowtrace`: (default: NULL) Flowtrace instance to create a retroactive debugging
    trace of the network run.
    * `asyncDelivery`: (default: FALSE) Whether Information Packets should be
    delivered asynchronously.
    * `subscribeGraph`: (default: FALSE) Whether the network should monitor the underlying
    graph for changes

    Options can be passed as a second argument:
    ```
    Zenflo.createNetwork(someGraph, options);
    ```
    The options object can also be used for setting ComponentLoader options in this
    network.
**/
typedef NetworkOptions = {
	> zenflo.lib.BaseNetwork.NetworkOptions,
	?delay:Bool,
	?subscribeGraph:Bool
}

/**
    ## Network instantiation

    This function handles instantiation of NoFlo networks from a Graph object. It creates
    the network, and then starts execution by sending the Initial Information Packets.

    ```
    Zenflo.createNetwork(someGraph, {}).next((_)-> trace('Network is now running!')));
    ```
    It is also possible to instantiate a Network but delay its execution by giving the
    third `delay` option. In this case you will have to handle connecting the graph and
    sending of IIPs manually.

    ```
    Zenflo.createNetwork(someGraph, {delay: true})
        .next((network) -> network.connect())
        .next((network) -> network.start())
        .next((_)-> trace('Network is now running!')));
    ```
**/
typedef Network = zenflo.lib.Network;


typedef Graph = zenflo.graph.Graph;

/**
    ### Component Loader

    The ComponentLoader is responsible for finding and loading
    ZenFlo components. Component Loader uses [fbp-manifest](https://github.com/flowbased/fbp-manifest)
    to find components and graphs by traversing a given root
    directory on the file system.
**/
typedef ComponentLoader = zenflo.lib.ComponentLoader;

/**
    ### Component baseclasses
    These baseclasses can be used for defining ZenFlo components.
**/
typedef Component = zenflo.lib.Component;

/**
    ### ZenFlo ports

    These classes are used for instantiating ports on ZenFlo components.
**/
typedef Inports = zenflo.lib.InPorts;

/**
    ### ZenFlo ports

    These classes are used for instantiating ports on ZenFlo components.
**/
typedef Outports = zenflo.lib.InPorts;

/**
    ### ZenFlo sockets

    The ZenFlo internalSocket is used for connecting ports of
    different components together in a network.
**/
typedef InternalSocket = zenflo.lib.InternalSocket;


/**
	### Information Packets
    ZenFlo Information Packets are defined as "IP" objects.
**/
typedef IP = zenflo.lib.IP;





function createNetwork(graphInstance:Graph, ?options:NetworkOptions):Promise<Network> {
	if (options == null) {
		options = {};
	}

	if (options.subscribeGraph == null) {
		options.subscribeGraph = false;
	}

	final network = new Network(graphInstance, options);

	// Ensure components are loaded before continuing
	return network.loader.listComponents().next((_) -> {
		if (options.delay) {
			// In case of delayed execution we don't wire it up
			return Promise.resolve(network);
		}
		final connected:Promise<Network> = cast network.connect();
		return connected.next((_) -> cast network.start());
	});
}

/**
    ### Starting a network from a file

    It is also possible to start a NoFlo network by giving it a path to a `.json` or `.fbp` network
    definition file.

    ```
    Zenflo.loadFile('somefile.json', {})
        .next((_)->{
            trace('Network is now running!');
        });
    ```
**/
function loadFile(file:String, ?options:NetworkOptions):Promise<Network> {
	return Graph.loadFile(file).next((graphInstance) -> createNetwork(graphInstance, options));
}

/**
    ### Saving a network definition

    ZenFlo graph files can be saved back into the filesystem with this method.
**/
function saveFile(graphInstance:Graph, file:String):Promise<String> {
    return graphInstance.save(file);
}


