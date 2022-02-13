package zenflo.spec.graph;

// import polygonal.ds.ArrayList;
import haxe.Timer;
import equals.Equal;
import buddy.BuddySuite;
import haxe.DynamicAccess;
import zenflo.graph.GraphJson;

using buddy.Should;

@colorize
class Graph extends buddy.BuddySuite {
	public function new() {
		BuddySuite.useDefaultTrace = true;
		describe("FBP Graph", () -> {
			describe('with case sensitivity', {
				describe('Unnamed graph instance', {
					it('should have an empty name', {
						final g = new zenflo.graph.Graph();
						g.name.should.be('');
					});
				});

				describe('with new instance', {
					final g = new zenflo.graph.Graph('Foo bar', {caseSensitive: true});
					it('should get a name from constructor', {
						g.name.should.be('Foo bar');
					});

					it('should have no nodes initially', {
						g.nodes.size.should.be(0);
					});

					it('should have no edges initially', {
						g.edges.size.should.be(0);
					});
					it('should have no initializers initially', {
						g.initializers.length.should.be(0);
					});

					it('should have no inports initially', {
						g.inports.keys().length.should.be(0);
					});

					it('should have no outports initially', {
						g.outports.keys().length.should.be(0);
					});

					beforeEach(() -> {
						g.removeAllListeners();
					});

					describe('New node', {
						var n = null;

						beforeEach((done) -> {
							#if !cpp
							haxe.Timer.delay(() -> {
								done();
							}, 0);
							#else
							Sys.sleep(0.01);
							done();
							#end
						});
						it('should emit an event', (done) -> {
							g.once('addNode', (vals) -> {
								final node:zenflo.graph.GraphNode = vals[0];
								node.id.should.be('Foo');
								node.component.should.be('Bar');
								n = node;
								done();
							});
							g.addNode('Foo', 'Bar');
						});
						it('should be in graph\'s list of nodes', {
							g.nodes.size.should.be(1);
							g.nodes.indexOf(n).should.be(0);
						});

						it('should be accessible via the getter', {
							final node = g.getNode('Foo');
							node.id.should.be('Foo');
							node.should.be(n);
						});
						it('should have empty metadata', {
							final node = g.getNode('Foo');

							node.metadata.should.be(null);
							var _node:Dynamic = node;
							_node.display.should.be(null);
						});
						it('should be available in the JSON export', {
							final json = g.toJSON();
							Reflect.isObject(json.processes["Foo"]).should.be(true);
							json.processes["Foo"].component.should.be('Bar');
							var foo:Dynamic = json.processes["Foo"];
							foo.display.should.be(null);
						});
						it('removing should emit an event', (done) -> {
							g.once('removeNode', (vals) -> {
								final node:zenflo.graph.GraphNode = vals[0];
								node.id.should.be('Foo');
								node.should.be(n);
								done();
							});
							g.removeNode('Foo');
						});
						it('should not be available after removal', {
							final node = g.getNode('Foo');
							node.should.be(null);
							g.nodes.size.should.be(0);
							g.nodes.indexOf(n).should.be(-1);
						});
					});
					describe('New edge', {
						beforeEach((done) -> {
							#if !cpp
							haxe.Timer.delay(() -> {
								done();
							}, 0);
							#else
							Sys.sleep(0.01);
							done();
							#end
						});
						it('should emit an event', (done) -> {
							g.addNode('Foo', 'foo');
							g.addNode('Bar', 'bar');
							g.once('addEdge', (edges) -> {
								final edge:zenflo.graph.GraphEdge = edges[0];
								edge.from.node.should.be('Foo');
								edge.to.port.should.be('In');
								done();
							});
							#if cpp
							Sys.sleep(0.001);
							#end
							g.addEdge('Foo', 'Out', 'Bar', 'In');
						});
						it('should add an edge', {
							g.addEdge('Foo', 'out', 'Bar', 'in2');
							g.edges.size.should.be(2);
						});
						it('should refuse to add a duplicate edge', {
							final edge = g.edges[0];
							g.addEdge(edge.from.node, edge.from.port, edge.to.node, edge.to.port);
							g.edges.size.should.be(2);
						});
					});
					describe('New edge with index', {
						beforeEach((done) -> {
							#if !cpp
							haxe.Timer.delay(() -> {
								done();
							}, 0);
							#else
							Sys.sleep(0.01);
							done();
							#end
						});
						it('should emit an event', (done) -> {
							g.once('addEdge', (edges) -> {
								final edge:zenflo.graph.GraphEdge = edges[0];
								edge.from.node.should.be('Foo');
								edge.to.port.should.be('in');
								edge.to.index.should.be(1);
								edge.from.index.should.be(null);
								g.edges.size.should.be(3);
								done();
							});
							g.addEdgeIndex('Foo', 'out', null, 'Bar', 'in', 1);
						});
						it('should add an edge', {
							g.addEdgeIndex('Foo', 'out', 2, 'Bar', 'in2');
							g.edges.size.should.be(4);
						});
					});
				});

				describe('loaded from JSON (with case sensitive port names)', {
					final jsonString = '
                    {
                        "caseSensitive": true,
                        "properties": {
                          "name": "Example",
                          "foo": "Baz",
                          "bar": "Foo"
                        },
                        "inports": {
                          "inPut": {
                            "process": "Foo",
                            "port": "inPut",
                            "metadata": {
                              "x": 5,
                              "y": 100
                            }
                          }
                        },
                        "outports": {
                          "outPut": {
                            "process": "Bar",
                            "port": "outPut",
                            "metadata": {
                              "x": 500,
                              "y": 505
                            }
                          }
                        },
                        "groups": [
                          {
                            "name": "first",
                            "nodes": [
                              "Foo"
                            ],
                            "metadata": {
                              "label": "Main"
                            }
                          },
                          {
                            "name": "second",
                            "nodes": [
                              "Foo2",
                              "Bar2"
                            ]
                          }
                        ],
                        "processes": {
                          "Foo": {
                            "component": "Bar",
                            "metadata": {
                              "display": {
                                "x": 100,
                                "y": 200
                              },
                              "routes": [
                                "one",
                                "two"
                              ],
                              "hello": "World"
                            }
                          },
                          "Bar": {
                            "component": "Baz",
                            "metadata": {}
                          },
                          "Foo2": {
                            "component": "foo",
                            "metadata": {}
                          },
                          "Bar2": {
                            "component": "bar",
                            "metadata": {}
                          }
                        },
                        "connections": [
                          {
                            "src": {
                              "process": "Foo",
                              "port": "outPut"
                            },
                            "tgt": {
                              "process": "Bar",
                              "port": "inPut"
                            },
                            "metadata": {
                              "route": "foo",
                              "hello": "World"
                            }
                          },
                          {
                            "src": {
                              "process": "Foo",
                              "port": "out2"
                            },
                            "tgt": {
                              "process": "Bar",
                              "port": "in2",
                              "index": 2
                            },
                            "metadata": {
                              "route": "foo",
                              "hello": "World"
                            }
                          },
                          {
                            "data": "Hello, world!",
                            "tgt": {
                              "process": "Foo",
                              "port": "inPut"
                            }
                          },
                          {
                            "data": "Hello, world, 2!",
                            "tgt": {
                              "process": "Foo",
                              "port": "in2"
                            }
                          },
                          {
                            "data": "Cheers, world!",
                            "tgt": {
                              "process": "Foo",
                              "port": "arr",
                              "index": 0
                            }
                          },
                          {
                            "data": "Cheers, world, 2!",
                            "tgt": {
                              "process": "Foo",
                              "port": "arr",
                              "index": 1
                            }
                          }
                        ]
                      }
                    ';

					final json:GraphJson = haxe.Json.parse(jsonString);
					var g:zenflo.graph.Graph = null;

					beforeEach((done) -> {
						#if !cpp
						haxe.Timer.delay(() -> {
							done();
						}, 0);
						#else
						Sys.sleep(0.01);
						done();
						#end
					});

					it('should produce a Graph when input is string', {
						zenflo.graph.Graph.loadJSON(jsonString).handle((c) -> {
							switch c {
								case Success(instance): {
										g = instance;
										g.should.not.be(null);
									}
								case Failure(err): {
										fail(err);
									}
							}
						});
					});

					it('should produce a Graph when input is JSON', {
						zenflo.graph.Graph.loadJSON(json).handle((c) -> {
							switch c {
								case Success(instance): {
										g = instance;
										g.should.not.be(null);
									}
								case Failure(err): {
										fail(err);
									}
							}
						});
					});

					it('should not mutate the inputted json object', (done) -> {
						if (json != null) {
							if (json.processes != null) {
								json.processes.keys().length.should.be(4);
							} else {
								json.processes.should.not.be(null);
							}
						} else {
							json.should.not.be(null);
						}

						zenflo.graph.Graph.loadJSON(json).handle((c) -> {
							var instance:zenflo.graph.Graph = null;
							switch c {
								case Failure(err): {
										fail(err);
										return;
									}
								case Success(_instance): {
										instance = _instance;
									}
							}

							if (instance == null) {
								fail(new tink.core.Error('No graph loaded'));
								return;
							} else {
								instance.addNode('Split1', 'Split');
								instance.addNode('Split1', 'Split');
								instance.addNode('Split1', 'Split');
								instance.addNode('Split1', 'Split');
								instance.addNode('Split1', 'Split');
								instance.addNode('Split1', 'Split');
								instance.addNode('Split1', 'Split');
								instance.addNode('Split1', 'Split');
								instance.addNode('Split1', 'Split');
								instance.addNode('Split1', 'Split');
								instance.addNode('Split1', 'Split');
							}

							json.processes.keys().length.should.be(4);
							done();
						});
					});

					it('should have a name', {g.name.should.be('Example');});
					it('should have graph metadata intact', {
						var props:Dynamic = g.properties;
						props.foo.should.be("Baz");
						props.bar.should.be("Foo");
					});
					it('should produce same JSON when serialized', {
						equals.Equal.equals(g.toJSON(), json).should.be(true);
					});

					it('should allow modifying graph metadata', (done) -> {
						g.once('changeProperties', (vals) -> {
							final properties:zenflo.graph.PropertyMap = vals[0];
							properties.should.be(g.properties);
							var want:DynamicAccess<String> = {
								foo: 'Baz',
								bar: 'Bar',
								hello: 'World',
							};
							for (key in g.properties.keys()) {
								g.properties[key].should.be(want[key]);
							}

							done();
						});
						g.setProperties({
							hello: 'World',
							bar: 'Bar',
						});
					});
					it('should contain four nodes', {
						g.nodes.size.should.be(4);
					});
					it('the first Node should have its metadata intact', {
						final node = g.getNode('Foo');
						node.metadata.should.not.be(null);
						Reflect.isObject(node.metadata).should.be(true);
						var metadata:Dynamic = node.metadata;
						metadata.display.should.not.be(null);
						Reflect.isObject(metadata.display).should.be(true);
						metadata.display.x.should.be(100);
						metadata.display.y.should.be(200);
						metadata.routes.should.beType(Array);
						var routes:Array<String> = metadata.routes;
						routes.should.contain('one');
						routes.should.contain('two');
					});

					beforeEach((done) -> {
						#if !cpp
						haxe.Timer.delay(() -> {
							done();
						}, 0);
						#else
						Sys.sleep(0.01);
						done();
						#end
					});

					// beforeEach((done) -> {
					// 	Sys.sleep(0.01);
					// 	g.removeAllListeners();
					// 	done();
					// });

					it('should allow modifying node metadata', (done) -> {
						g.removeAllListeners();
						g.once('changeNode', (vals) -> {
							final node:zenflo.graph.GraphNode = vals[0];
							node.id.should.be('Foo');
							var metadata:Dynamic = node.metadata;
							metadata.routes.should.beType(Array);
							final routes:Array<String> = metadata.routes;
							routes.should.contain('one');
							routes.should.contain('two');
							metadata.hello.should.be('World');
							done();
						});

						g.setNodeMetadata('Foo', {hello: 'World'});
					});
					it('should contain two connections', {
						g.edges.size.should.be(2);
					});
					it('the first Edge should have its metadata intact', {
						final edge = g.edges[0];
						Reflect.isObject(edge.metadata).should.be(true);
						var metadata:Dynamic = edge.metadata;
						metadata.route.should.be('foo');
					});
					it('should allow modifying edge metadata', (done) -> {
						final e = g.edges[0];
						g.once('changeEdge', (edges) -> {
							final edge:zenflo.graph.GraphEdge = edges[0];
							edge.should.be(e);
							var metadata:Dynamic = edge.metadata;
							metadata.route.should.be('foo');
							metadata.hello.should.be('World');
							done();
						});
						g.setEdgeMetadata(e.from.node, e.from.port, e.to.node, e.to.port, {hello: 'World'});
					});
					it('should contain four IIPs', {
						g.initializers.length.should.be(4);
					});
					it('should contain one published inport', {
						g.inports.keys().length.should.be(1);
					});
					it('should contain one published outport', {
						g.inports.keys().length.should.be(1);
					});
					it('should keep the output export metadata intact', {
						final exp = g.outports["outPut"];
						var metadata:Dynamic = exp.metadata;
						metadata.x.should.be(500);
						metadata.y.should.be(505);
					});
					it('should contain two groups', {
						g.groups.size.should.be(2);
					});
					it('should allow modifying group metadata', (done) -> {
						final group = g.groups[0];
						g.once('changeGroup', (grps) -> {
							final grp:zenflo.graph.GraphGroup = grps[0];
							grp.should.be(group);
							var metadata:Dynamic = grp.metadata;
							metadata.label.should.be('Main');
							metadata.foo.should.be('Bar');
							equals.Equal.equals(g.groups[1].metadata, {}).should.be(true);
							// haxe.Json.stringify(g.groups[1].metadata).should.be("{}");

							done();
						});
						g.setGroupMetadata('first', {foo: 'Bar'});
					});

					it('should allow renaming groups', (done) -> {
						final group = g.groups[0];
						g.once('renameGroup', (vals) -> {
							var oldName = vals[0];
							var newName = vals[1];
							oldName.should.be("first");
							newName.should.be("renamed");
							group.name.should.be(newName);
							done();
						});
						g.renameGroup('first', 'renamed');
					});
					describe('renaming a node', {
						beforeEach((done) -> {
							g.removeAllListeners();
							#if !cpp
							haxe.Timer.delay(() -> {
								done();
							}, 0);
							#else
							// Sys.sleep(0.01);
							done();
							#end
						});

						it('should emit an event', (done) -> {
							g.once('renameNode', (vals) -> {
								var oldId = vals[0];
								var newId = vals[1];
								oldId.should.be('Foo');
								newId.should.be('Baz');
								done();
							});
							g.renameNode('Foo', 'Baz');
						});
						it('should be available with the new name', {
							Reflect.isObject(g.getNode('Baz')).should.be(true);
						});
						it('shouldn\'t be available with the old name', {
							g.getNode('Foo').should.be(null);
						});
						it('should have the edge still going from it', {
							var connection = null;
							for (edge in g.edges) {
								if (edge.from.node == 'Baz') {
									connection = edge;
								}
							}
							Reflect.isObject(connection).should.be(true);
						});
						it('should still be exported', {
							g.inports["inPut"].process.should.be("Baz");
						});
						it('should still be grouped', {
							var groups = 0;
							for (group in g.groups) {
								if (group.nodes.indexOf('Baz') != -1) {
									groups += 1;
								}
							}

							groups.should.be(1);
						});
						it('shouldn\'t be have edges with the old name', {
							var connection = null;
							for (edge in g.edges) {
								if (edge.from.node == 'Foo') {
									connection = edge;
								}
								if (edge.to.node == 'Foo') {
									connection = edge;
								}
							}

							connection.should.be(null);
						});
						it('should have the IIP still going to it', {
							var iip = null;
							for (initializer in g.initializers) {
								if (initializer.to.node == 'Baz') {
									iip = initializer;
								}
							}

							Reflect.isObject(iip).should.be(true);
						});
						it('shouldn\'t have IIPs going to the old name', {
							var iip = null;
							for (initializer in g.initializers) {
								if (initializer.to.node == 'Foo') {
									iip = initializer;
								}
							}

							iip.should.be(null);
						});
						it('shouldn\'t be grouped with the old name', {
							var groups = 0;
							for (group in g.groups) {
								if (group.nodes.indexOf('Foo') != -1) {
									groups += 1;
								}
							}
							groups.should.be(0);
						});
					});
					describe('renaming an inport', {
						it('should emit an event', (done) -> {
							g.once('renameInport', (vals) -> {
								var oldName = vals[0];
								var newName = vals[1];
								oldName.should.be('inPut');
								newName.should.be('opt');
								g.inports['inPut'].should.be(null);
								Reflect.isObject(g.inports['opt']).should.be(true);
								var opt:Dynamic = g.inports['opt'];
								opt.process.should.be('Baz');
								opt.port.should.be('inPut');
								done();
							});
							g.renameInport('inPut', 'opt');
						});
					});
					describe('renaming an outport', {
						it('should emit an event', (done) -> {
							g.once('renameOutport', (vals) -> {
								var oldName = vals[0];
								var newName = vals[1];
								oldName.should.be('outPut');
								newName.should.be('foo');
								var outports:Dynamic = g.outports;
								outports.outPut.should.be(null);
								Reflect.isObject(outports.foo).should.be(true);
								outports.foo.process.should.be('Bar');
								outports.foo.port.should.be('outPut');
								done();
							});
							g.renameOutport('outPut', 'foo');
						});
					});
					describe('removing a node', {
						// beforeEach((done) -> {
						// 	g.removeAllListeners();
						// 	#if !cpp
						// 	haxe.Timer.delay(() -> {
						// 		done();
						// 	}, 0);
						// 	#else
						// 	// Sys.sleep(0.01);
						// 	done();
						// 	#end
						// });
						it('should emit an event', (done) -> {
							g.once('removeNode', (nodes) -> {
								final node:Dynamic = nodes[0];
								node.id.should.be('Baz');
								done();
							});
							g.removeNode('Baz');
						});

						beforeEach((done) -> {
							#if !cpp
							haxe.Timer.delay(() -> {
								done();
							}, 0);
							#else
							// Sys.sleep(0.01);
							done();
							#end
						});
						it('shouldn\'t have edges left behind', (done) -> {
							var connections = 0;
							for (i in 0...g.edges.size) {
								final edge = g.edges[i];
								if (edge.from.node == 'Baz') {
									connections += 1;
								}
								if (edge.to.node == 'Baz') {
									connections += 1;
								}
							}
							haxe.Timer.delay(()->{
								connections.should.be(0);
								done();
							}, 10);
						});
						it('shouldn\'t have IIPs left behind', (done) -> {
							final connections = Lambda.filter(g.initializers, (iip) -> {
								return iip.to.node == "Baz";
							});
							connections.length.should.be(0);
							done();
						});
						it('shouldn\'t be grouped', {
							var groups = 0;
							for (group in g.groups) {
								if (group.nodes.indexOf('Baz') != -1) {
									groups += 1;
								}
							}
							groups.should.be(0);
						});
						it('shouldn\'t affect other groups', {
							final otherGroup = g.groups[0];
							otherGroup.nodes.length.should.be(2);
						});
					});
				});

				describe('with multiple connected ArrayPorts', {
					final g = new zenflo.graph.Graph();
					g.addNode('Split1', 'Split');
					g.addNode('Split2', 'Split');
					g.addNode('Merge1', 'Merge');
					g.addNode('Merge2', 'Merge');
					g.addEdge('Split1', 'out', 'Merge1', 'in');
					g.addEdge('Split1', 'out', 'Merge2', 'in');
					g.addEdge('Split2', 'out', 'Merge1', 'in');
					g.addEdge('Split2', 'out', 'Merge2', 'in');

					it('should contain four nodes', {
						g.nodes.size.should.be(4);
					});
					it('should contain four edges', {
						g.edges.size.should.be(4);
					});
					it('should allow a specific edge to be removed', {
						g.removeEdge('Split1', 'out', 'Merge2', 'in');
						g.edges.size.should.be(3);
					});

					beforeEach((done) -> {
						// g.removeAllListeners();
						#if !cpp
						haxe.Timer.delay(() -> {
							done();
						}, 0);
						#else
						// Sys.sleep(0.01);
						done();
						#end
					});

					it('shouldn\'t contain the removed connection from Split1', {
						var connection = null;
						for (edge in g.edges) {
							if ((edge.from.node == 'Split1') && (edge.to.node == 'Merge2')) {
								connection = edge;
							}
						}
						connection.should.be(null);
					});
					it('should still contain the other connection from Split1', {
						var connection = null;
						for (edge in g.edges) {
							if ((edge.from.node == 'Split1') && (edge.to.node == 'Merge1')) {
								connection = edge;
							}
						}
						Reflect.isObject(connection).should.be(true);
					});
				});
				describe('with an Initial Information Packet', {
					final g = new zenflo.graph.Graph();
					g.addNode('Split', 'Split');
					g.addInitial('Foo', 'Split', 'in');

					it('should contain one node', {
						g.nodes.size.should.be(1);
					});
					it('should contain no edges', {
						g.edges.size.should.be(0);
					});
					it('should contain one IIP', {
						g.initializers.length.should.be(1);
					});

					beforeAll((done) -> {
						g.removeAllListeners();
						done();
					});

					describe('on removing that IIP', () -> {
						afterEach((done) -> {
							#if !cpp
							haxe.Timer.delay(() -> {
								done();
							}, 1);
							#else
							// g.removeAllListeners();
							// Sys.sleep(1);
							done();
							#end
						});

						it('should emit a removeInitial event', (done) -> {
							g.once('removeInitial', (iips) -> {
								final iip:zenflo.graph.GraphIIP = iips[0];
								iip.from.data.should.be('Foo');
								iip.to.node.should.be('Split');
								iip.to.port.should.be('in');
								done();
							});

							g.removeInitial('Split', 'in');
						});

						it('should contain no IIPs', (done) -> {
							// #if cpp  Sys.sleep(2); #end
							g.initializers.length.should.be(0);
							done();
						});
					});
				});
				describe('with an Inport Initial Information Packet', {
					final g = new zenflo.graph.Graph();
					g.addNode('Split', 'Split');
					g.addInport('testinport', 'Split', 'in');
					g.addGraphInitial('Foo', 'testinport');

					it('should contain one node', () -> g.nodes.size.should.be(1));
					it('should contain no edges', () -> g.edges.size.should.be(0));
					it('should contain one IIP for the correct node', () -> {
						g.initializers.length.should.be(1);
						g.initializers[0].from.data.should.be('Foo');
						g.initializers[0].to.node.should.be('Split');
						g.initializers[0].to.port.should.be('in');
					});
					describe('on removing that IIP', {
						beforeEach((done) -> {
							//
							#if !cpp
							haxe.Timer.delay(() -> {
								done();
							}, 0);
							#else
							// g.removeAllListeners();
							// Sys.sleep(0.01);
							done();
							#end
						});
						it('should emit a removeInitial event', (done) -> {
							g.once('removeInitial', (vals) -> {
								final iip:zenflo.graph.GraphIIP = vals[0];
								iip.from.data.should.be('Foo');
								iip.to.node.should.be('Split');
								iip.to.port.should.be('in');

								done();
							});
							g.removeGraphInitial('testinport');
						});
						it('should contain no IIPs', () -> {
							// #if cpp  Sys.sleep(2); #end
							g.initializers.length.should.be(0);
						});
					});

					describe('on adding IIP for a non-existent inport', {
						g.addGraphInitial('Bar', 'nonexistent');

						it('should not add any IIP', () -> {
							g.initializers.length.should.be(0);
						});
					});
				});

				describe('with an indexed Inport Initial Information Packet', {
					final g = new zenflo.graph.Graph();
					g.addNode('Split', 'Split');
					g.addInport('testinport', 'Split', 'in');
					g.addGraphInitialIndex('Foo', 'testinport', 1);

					it('should contain one node', {
						g.nodes.size.should.be(1);
					});
					it('should contain no edges', {
						g.edges.size.should.be(0);
					});
					it('should contain one IIP for the correct node', {
						g.initializers.length.should.be(1);
						g.initializers[0].from.data.should.be('Foo');
						g.initializers[0].to.node.should.be('Split');
						g.initializers[0].to.port.should.be('in');
						g.initializers[0].to.index.should.be(1);
					});
					describe('on removing that IIP', {
						beforeEach((done) -> {
							#if !cpp
							haxe.Timer.delay(() -> {
								done();
							}, 0);
							#else
							// g.removeAllListeners();
							// Sys.sleep(0.01);
							done();
							#end
						});
						it('should emit a removeInitial event', (done) -> {
							g.once('removeInitial', (iips) -> {
								final iip:Dynamic = iips[0];
								iip.from.data.should.be('Foo');
								iip.to.node.should.be('Split');
								iip.to.port.should.be('in');

								done();
							});
							g.removeGraphInitial('testinport');
						});
						it('should contain no IIPs', () -> {
							g.initializers.length.should.be(0);
						});
					});
					describe('on adding IIP for a non-existent inport', {
						g.addGraphInitialIndex('Bar', 'nonexistent', 1);
						it('should not add any IIP', () -> g.initializers.length.should.be(0));
					});
				});

				describe('with no nodes', {
					final g = new zenflo.graph.Graph();
					it('should not allow adding edges', {
						g.addEdge('Foo', 'out', 'Bar', 'in');
						g.edges.size.should.be(0);
					});
					it('should not allow adding IIPs', {
						g.addInitial('Hello', 'Bar', 'in');
						g.initializers.length.should.be(0);
					});
				});
			});
			#if (sys || hxnodejs)
			describe('saving and loading files', {
				describe('with .json suffix', {
					var originalGraph = null;
					var graphPath = null;
					beforeEach({
						graphPath = haxe.io.Path.join([Sys.getCwd(), "foo.json"]);
					});

					it('should be possible to save a graph to a file', (done) -> {
						final g = new zenflo.graph.Graph();
						g.addNode('Foo', 'Bar');
						originalGraph = g.toJSON();
						g.save(graphPath).handle((s) -> {
							switch s {
								case Success(i): {
										done();
									}
								case Failure(e): {
										fail(e);
									}
							}
						});
					});

					it('should be possible to load a graph from a file', {
						zenflo.graph.Graph.loadFile(graphPath).handle((c) -> {
							switch c {
								case Success(g): {
										g.should.not.be(null);
										g.should.beType(zenflo.graph.Graph);
										equals.Equal.equals(g.toJSON(), originalGraph).should.be(true);
									}
								case _:
							}
						});
					});

					afterAll({
						sys.FileSystem.deleteFile(graphPath);
					});
				});

				describe('without .json suffix', {
					var graphPathLegacy = null;
					var graphPathLegacySuffix = null;
					var originalGraph = null;

					beforeEach({
						graphPathLegacySuffix = haxe.io.Path.join([Sys.getCwd(), "bar.json"]);
						graphPathLegacy = haxe.io.Path.join([Sys.getCwd(), "bar"]);
					});

					it('should be possible to save a graph to a file', (done) -> {
						final g = new zenflo.graph.Graph();
						g.addNode('Foo', 'Bar');
						originalGraph = g.toJSON();
						g.save(graphPathLegacy).handle((s) -> {
							switch s {
								case Success(i): {
										done();
									}
								case Failure(e): {
										fail(e);
									}
							}
						});
					});

					it('should be possible to load a graph from a file', (done) -> {
						zenflo.graph.Graph.loadFile(graphPathLegacySuffix).handle((c) -> {
							var graph = null;
							switch c {
								case Success(g): {
										if (g == null) {
											fail(new tink.core.Error('No graph'));
											return;
										}
										graph = g;
									}
								case Failure(e): {
										fail(e);
										return;
									}
							}

							equals.Equal.equals(graph.toJSON(), originalGraph).should.be(true);
							done();
						});
					});

					afterAll({
						sys.FileSystem.deleteFile(graphPathLegacySuffix);
					});
				});
			});
			#end
		});

		describe('without case sensitivity', {
			describe('Graph operations should convert port names to lowercase', {
				it('should have case sensitive property set to false', {
					var g = new zenflo.graph.Graph('Hola');
					g.caseSensitive.should.be(false);
				});
				it('should have case insensitive ports on edges', (done) -> {
					var g = new zenflo.graph.Graph('Hola');
					g.addNode('Foo', 'foo');
					g.addNode('Bar', 'bar');
					
					g.once('addEdge', (edges) -> {
						final edge:zenflo.graph.GraphEdge = edges[0];
						
							edge.from.node.should.be('Foo');
							edge.to.port.should.be('input');
							edge.from.port.should.be('output');

							#if !cpp haxe.Timer.delay(()->{ #end
							#if cpp Sys.sleep(0.01); #end
							function onRemoveEdge(done, _) {
								g.edges.size.should.be(0);
								done();
							};
							g.once('removeEdge', onRemoveEdge.bind(done));

							g.removeEdge('Foo', 'outPut', 'Bar', 'inPut');
							#if !cpp }, 0); #end
						
					});

					g.addEdge('Foo', 'outPut', 'Bar', 'inPut');
				});
			});
		});
	}
}
