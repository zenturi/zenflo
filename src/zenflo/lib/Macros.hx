/*
 * MIT License
 *
 * Copyright (c) 2022 Damilare Akinlaja, Zenturi Systems Co.
 * Copyright (c) 2017-2018 Flowhub UG
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of
 * this software and associated documentation files (the "Software"), to deal in
 * the Software without restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the
 * Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
 * FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
 * COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
 * AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH
 * THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

package zenflo.lib;

import zenflo.lib.BaseNetwork.NetworkOwnOptions;
import haxe.DynamicAccess;
import tink.core.Error;
import zenflo.graph.Graph;
import haxe.ds.Either;
import tink.core.Promise;
import zenflo.graph.GraphNodeID;
import haxe.Constraints.Function;
import zenflo.lib.Component.ComponentOptions;

/**
	## asComponent generator API

	asComponent is a macro for turning Haxe functions into
	ZenFlo components.

	All input arguments become input ports, and the function's
	result will be sent to either `out` or `error` port.

	```
		using zenflo.lib.Macros.*;
		using zenflo.lib.Utils;

		final random = asComponent(Math.random.deflate(), {
			description: 'Generate a random number'
		});
	```
**/
function asComponent(paramsAndRet:Array<Dynamic>, ?options:ComponentOptions) {
	final func = paramsAndRet[0];
	final pNames:Array<Dynamic> = paramsAndRet[1];
	final isPromise = paramsAndRet[2];

	var c = new zenflo.lib.Component(options);

	for (p in pNames) {
		c.inPorts.add(p.name, p.options);
		c.forwardBrackets[p.name] = ['out', 'error'];
	}
	if (pNames.length == 0) {
		c.inPorts.add('in', {dataType: 'bang'});
	}
	c.outPorts.add('out');
	c.outPorts.add('error');

	c.process((input:zenflo.lib.ProcessInput, output:zenflo.lib.ProcessOutput, _) -> {
		var values:Array<String> = [];

		if (pNames.length != 0) {
			var _args = [for (p in pNames) p.name];

			if (!input.hasData(..._args)) {
				return null;
			}
			var data:Dynamic = input.getData(..._args);

			if (!Std.isOfType(data, Array)) {
				values.push(data);
			} else {
				values = values.concat(data);
			}
		} else {
			if (!input.hasData('in')) {
				return null;
			}
			var data = input.getData('in');
			values.push(data);
		}

		var res:Dynamic = Reflect.callMethod({}, func, values);
		if (res != null) {
			if (isPromise) {
				res.handle(_c -> {
					switch _c {
						case tink.core.Outcome.Success(v): {
								output.sendDone(v);
							}
						case tink.core.Outcome.Failure(err): {
								output.done(err);
							}
					}
				});
				return null;
			}
		}
		output.sendDone(res);

		return null;
	});
	return c;
}

typedef AsCallbackComponent = Either<Graph, String>;

typedef AsCallbackOptions = {
	// Name for the wrapped network
	?name:String,
	// Component loader instance to use, if any
	?loader:ComponentLoader,
	// Project base directory for component loading
	?baseDir:String,
	// Flowtrace instance to use for tracing this network run
	?flowtrace:Dynamic,
	// Access to Network instance
	?networkCallback:NetworkCallback,
	// Whether the callback should operate on raw IP objects
	?raw:Bool,
	// Make Information Packet delivery asynchronous
	?asyncDelivery:Bool
};

typedef OutputMap = Array<Any>;
typedef InputMap = Either<DynamicAccess<Array<IP>>, Array<DynamicAccess<IP>>>;
typedef ResultCallback = (err:Null<Error>, output:Dynamic) -> Void;
typedef NetworkAsCallback = (inputs:Dynamic, callback:ResultCallback) -> Void;
typedef NetworkAsPromise = (inputs:Dynamic) -> tink.core.Promise<Any>;
typedef NetworkCallback = (network:Network) -> Void;

/**
 * ### Option normalization
 * 
 * Here we handle the input valus given to the `asCallback`
 * function. This allows passing things like a pre-initialized
 * ZenFlo ComponentLoader, or giving the component loading
 * baseDir context.
 * 
 * @param options 
 * @param component 
 * @return AsCallbackOptions
 */
function normalizeOptions(options:AsCallbackOptions, component:AsCallbackComponent):AsCallbackOptions {
	if (options == null) {
		options = {};
	}
	if (options.name != null) {
		switch (component) {
			case Right(v):
				{
					options.name = v;
				}
			case _:
		}
	}

	if (options.loader != null) {
		options.baseDir = options.loader.baseDir;
	}
	#if (sys || hxnodejs)
	if (options.baseDir == null) {
		options.baseDir = Sys.getCwd();
	}
	#end

	if (options.baseDir != null && options.loader == null) {
		options.loader = new ComponentLoader(options.baseDir);
	}

	if (options.raw == null) {
		options.raw = false;
	}

	if (options.asyncDelivery == null) {
		options.asyncDelivery = false;
	}

	return options;
}

/**
 * ### Network preparation
 * 
 * Each invocation of the asCallback-wrapped ZenFlo graph
 * creates a new network. This way we can isolate multiple
 * executions of the function in their own contexts.
 * @param component 
 * @param options 
 * @return Promise<Network>
 */
function prepareNetwork(component:Dynamic, options:AsCallbackOptions):Promise<Network> {
	// If we were given a graph instance, then just create a network
	if (Std.isOfType(component, Graph)) {
		// This is a graph object
		final opts:NetworkOptions = cast Reflect.copy(options);
		opts.componentLoader = options.loader;
		final network = new Network(component, opts);
		// Wire the network up
		return cast network.connect();
	}
	if (Std.isOfType(component, String)) {
		{
			if (options.loader == null) {
				return Promise.reject(new Error('No component loader provided'));
			}

			// Start by loading the component
			return new Promise<Network>((resolve, reject) -> {
				options.loader.load(component).handle((cb) -> {
					switch cb {
						case Success(instance): {
								// Prepare a graph wrapping the component
								final graph:Graph = new Graph(options.name);
								final nodeName:GraphNodeID = options.name != null ? options.name : 'AsCallback';
								graph.addNode(nodeName, cast component);

								// Expose ports
								final inPorts:DynamicAccess<InPort> = cast instance.inPorts.ports;
								final outPorts:DynamicAccess<OutPort> = cast instance.outPorts.ports;

								Lambda.iter(inPorts.keys(), (port) -> {
									graph.addInport(port, nodeName, port);
								});

								Lambda.iter(outPorts.keys(), (port) -> {
									graph.addOutport(port, nodeName, port);
								});

								final opts:NetworkOptions = cast Reflect.copy(options);
								opts.componentLoader = options.loader;

								final network = new Network(graph, opts);

								// Wire the network up and start execution
								network.connect().handle((cb) -> {
									switch cb {
										case Success(network): {
												resolve(cast network);
											}
										case Failure(err): {
												reject(err);
											}
									}
								});
							}
						case Failure(err): {
								reject(err);
							}
					}
				});

				return null;
			});
		}
	}

	return Promise.reject(new Error('Could not prepare network'));
}

/**
 * ### Network execution
 * 
 * Once network is ready, we connect to all of its exported
 * in and outports and start the network.
 * 
 * Input data is sent to the inports, and we collect IP
 * packets received on the outports.
 * 
 * Once the network finishes, we send the resulting IP
 * objects to the callback.
 * 
 * @param network 
 * @param inputs 
 * @return Promise<OutputMap>
 */
function runNetwork(network:Network, inputs:Dynamic):Promise<OutputMap> {
	return new Promise<OutputMap>((resolve, reject) -> {
		// Prepare inports
		var inSockets:DynamicAccess<InternalSocket> = {};
		// Subscribe outports
		final received:Array<DynamicAccess<IP>> = [];
		final outPorts = Reflect.fields(network.graph.outports);
		var outSockets:DynamicAccess<InternalSocket> = {};

		Lambda.iter(outPorts, outport -> {
			final portDef = network.graph.outports[outport];
			final process = network.getNode(portDef.process);
			if (process == null || process.component == null) {
				return;
			}
			outSockets[outport] = InternalSocket.createSocket({}, {
				debug: false,
			});

			network.subscribeSocket(outSockets[outport]);
			process.component.outPorts.ports[portDef.port].attach(outSockets[outport]);
			outSockets[outport].from = {
				process: process,
				port: portDef.port,
			};

			outSockets[outport].on('ip', (ips) -> {
				final ip:IP = ips[0];
				final res:DynamicAccess<IP> = {};
				res[outport] = ip;
				received.push(res);
			});
		});

		var onEnd:(a:Array<Any>) -> Void = null;

		// Subscribe to process errors
		final onError = (vals:Array<Any>) -> {
			final err:Error = vals[0];
			reject(err);
			network.removeListener('end', onEnd);
		};

		network.once('process-error', onError);

		// Subscribe network finish
		onEnd = (_) -> {
			Lambda.iter(outSockets.keys(), (port) -> {
				final socket = outSockets[port];
				socket.from.process.component.outPorts[socket.from.port].detach(socket);
			});
			outSockets = {};
			inSockets = {};
			resolve(received);
			// Clear listeners
			network.removeListener('process-error', onError);
		};

		network.once('end', onEnd);

		// Start network
		network.start().handle((cb) -> {
			switch (cb) {
				case Success(_): {
						switch (inputs) {
							case Right(inputs): {
									// Send inputs
									for (i in 0...inputs.length) {
										final inputMap:DynamicAccess<Array<IP>> = inputs[i];
										final keys = inputMap.keys();
										
										for (port in keys) {
											final value:Any = inputMap[port];

											if (!inSockets.exists(port)) {
												final portDef = network.graph.inports[port];

												if (portDef == null) {
													reject(new Error('Port ${port} not available in the graph'));
													return;
												}
												final process = network.getNode(portDef.process);

												if (process == null || process.component == null) {
													reject(new Error('Process ${portDef.process} for port ${port} not available in the graph'));
													return;
												}

												inSockets[port] = InternalSocket.createSocket({}, {
													debug: false,
												});

												network.subscribeSocket(inSockets[port]);

												inSockets[port].to = {
													process: process,
													port: port,
												};

												process.component.inPorts.ports[portDef.port].attach(inSockets[port]);
											}

											try {
												if (IP.isIP(value)) {
													inSockets[port].post(value);
												} else {
													inSockets[port].post(new IP('data', value));
												}
											} catch (e:Error) {
												reject(e);
												network.removeListener('process-error', onError);
												network.removeListener('end', onEnd);
												return;
											}
										}
									}
								}
							case _:
						}
					}
				case Failure(err): {
						reject(err);
					}
			}
		});

		return null;
	});
}

/**s
 * @param inputs 
 * @param network 
 * @return String
 */
function getType(inputs:Any, network:Network):String {
	// Scalar values are always simple inputs
	if (inputs == null || !Reflect.isObject(inputs)) {
		return 'simple';
	}

	if (Std.isOfType(inputs, Array)) {
		final _inputs:Array<Any> = inputs;
		final maps:Array<Any> = _inputs.filter((entry) -> getType(entry, network) == 'map');
		// If each member of the array is an input map, this is a sequence
		if (maps.length == _inputs.length) {
			return 'sequence';
		}
		// Otherwise arrays must be simple inputs
		return 'simple';
	}

	// Empty objects can't be maps
	final keys = Reflect.fields(inputs);
	if (keys.length == 0) {
		return 'simple';
	}
	for (i in 0...keys.length) {
		final key = keys[i];
		if (network.graph.inports[key] == null) {
			return 'simple';
		}
	}

	return 'map';
}

/**
 * @param inputs 
 * @param inputType 
 * @param network 
 */
function prepareInputMap(inputs:Dynamic, inputType:String, network:Network):InputMap {
	// Sequence we can use as-is
	if (inputType == 'sequence') {
		return InputMap.Right(inputs);
	}
	// We can turn a map to a sequence by wrapping it in an array
	if (inputType == 'map') {
		return InputMap.Right([inputs]);
	}

	// Simple inputs need to be converted to a sequence
	var inPort = network.graph.inports.keys()[0];
	if (inPort == null) {
		return InputMap.Left({});
	}

	// If we have a port named "IN", send to that
	if (network.graph.inports.exists("in")) {
		inPort = 'in';
	}

	final map:DynamicAccess<IP> = {};
	map[inPort] = inputs;
	return InputMap.Right([map]);
}

/**
 * @param values 
 * @param options 
 * @return Array<Any>
 */
function normalizeOutput(values:Array<Any>, options:AsCallbackOptions):Any {
	if (options.raw) {
		return values;
	}

	final result:Array<Any> = [];
	var previous:Null<Array<Any>> = null;
	var current = result;

	Lambda.iter(values, (packet) -> {
		final packet:IP = packet;
		switch packet.type {
			case OpenBracket: {
					previous = current;
					current = [];
					previous.push(current);
				}
			case DATA: {
					current.push(packet.data);
				}
			case CloseBracket: {
					current = previous;
				}
		}
	});

	if (result.length == 1) {
		return result[0];
	}
	return result;
}

/**
 * @param outputs 
 * @param resultType 
 * @param options 
 */
function sendOutputMap(outputs:OutputMap, resultType:String, options:AsCallbackOptions):Promise<Any> {
	// First check if the output sequence contains errors
	final errors = outputs.filter((map) -> {
		final map:DynamicAccess<Any> = map;
		return map["error"] != null;
	}).map((map) -> {
		final map:DynamicAccess<Any> = map;
		return map["error"];
	});

	if (errors.length != 0) {
		final m = normalizeOutput(errors, options);
		return Promise.reject(new Error(Std.string(m)));
	}

	if (resultType == 'sequence') {
		return Promise.resolve(outputs.map((map) -> {
			final map:DynamicAccess<Any> = map;

			/** @type {Object<string, any|IP>} */
			final res:DynamicAccess<Any> = {};

			Lambda.iter(map.keys(), (key) -> {
				final val = map[key];
				if (options.raw) {
					res[key] = val;
					return;
				}
				res[key] = normalizeOutput([val], options);
			});
			return res;
		}));
	}

	// Flatten the sequence
	final mappedOutputs:DynamicAccess<Array<Any>> = {};
	Lambda.iter(outputs, (map) -> {
		final map:DynamicAccess<Any> = map;
		Lambda.iter(map.keys(), (key) -> {
			final val = map[key];
			if (!mappedOutputs.exists(key)) {
				mappedOutputs[key] = [];
			}
			mappedOutputs[key].push(val);
		});
	});

	final outputKeys = mappedOutputs.keys();
	final withValue = outputKeys.filter((outport) -> mappedOutputs[outport].length > 0);
	if (withValue.length == 0) {
		// No output
		return Promise.resolve(null);
	}

	if ((withValue.length == 1) && (resultType == 'simple')) {
		// Single outport
		return Promise.resolve(normalizeOutput(mappedOutputs[withValue[0]], options));
	}

	final result:DynamicAccess<Any> = {};
	for (port in mappedOutputs.keys()) {
		final packets = mappedOutputs[port];
		result[port] = normalizeOutput(packets, options);
	}

	
	return Promise.resolve(result);
}

/**
 * ### AsPromise
 * Convert graph component to a Promise callback
 * @param component  Any - Graph or Component name
 * @param options 
 * @return NetworkAsPromise
 */
function asPromise(component:Dynamic, options:AsCallbackOptions):NetworkAsPromise {
	if (component == null) {
		throw new Error('No component or graph provided');
	}

	if (Std.isOfType(component, String)) {
		options = normalizeOptions(options, AsCallbackComponent.Right(component));
	}

	if (Std.isOfType(component, Graph)) {
		options = normalizeOptions(options, AsCallbackComponent.Left(component));
	}

	return (inputs) -> new Promise<Any>((resolve, reject) -> {
		prepareNetwork(component, options).handle((cb) -> {
			switch cb {
				case Success(network): {
						if (options.networkCallback != null) {
							options.networkCallback(network);
						}

						final resultType = getType(inputs, network);
						final inputMap = prepareInputMap(inputs, resultType, network);

						runNetwork(network, inputMap).handle((cb) -> {
							switch (cb) {
								case Success(outputMap): {
										sendOutputMap(outputMap, resultType, options).handle((cb) -> {
											switch (cb) {
												case Success(outputMap): {
														resolve(outputMap);
													}
												case Failure(err): {
														reject(err);
													}
											}
										});
									}
								case Failure(err): {
										reject(err);
									}
							}
						});
					}
				case Failure(err): {
						reject(err);
					}
			}
		});
	});
}

/**
 * ## asCallback embedding API
 * asCallback is a helper for embedding ZenFlo components or
 * graphs in other Haxe (or target) programs.
 * 
 * By using the `asCallback` function, you can turn any
 * ZenFlo component or ZenFlo Graph instance into a regular,
 * Haxe function.
 * 
 * Each call to that function starts a new ZenFlo network where
 * the given input arguments are sent as IP objects to matching
 * inports. Once the network finishes, the IP objects received
 * from the network will be sent to the callback function.
 * 
 * If there was anything sent to an `error` outport, this will
 * be provided as the error argument to the callback.
 * 
 * 
 * @param component Any - Graph or Component name
 * @param options AsCallbackOptions
 * @return NetworkAsCallback
 */
function asCallback(component:Dynamic, options:AsCallbackOptions):NetworkAsCallback {
	var promised:NetworkAsPromise = asPromise(component, options);
	return (inputs, callback) -> {
		promised(inputs).handle((cb) -> {
			switch (cb) {
				case Success(output): {
						callback(null, output);
					}
				case Failure(err): {
						callback(err, null);
					}
			}
		});
	};
}
