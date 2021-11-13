package zenflo.spec.graph;

import haxe.DynamicAccess;
import zenflo.graph.GraphJson;

using buddy.Should;

class Graph extends buddy.SingleSuite {
	public function new() {
		describe("FBP Graph", {
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
						g.nodes.length.should.be(0);
					});

					it('should have no edges initially', {
						g.edges.length.should.be(0);
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

					describe('New node', {
						var n = null;
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
							g.nodes.length.should.be(1);
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
							g.nodes.length.should.be(0);
							g.nodes.indexOf(n).should.be(-1);
						});
					});
					describe('New edge', {
						it('should emit an event', (done) -> {
							g.addNode('Foo', 'foo');
							g.addNode('Bar', 'bar');
							g.once('addEdge', (edges) -> {
								final edge:zenflo.graph.GraphEdge = edges[0];
								edge.from.node.should.be('Foo');
								edge.to.port.should.be('In');
								done();
							});
							g.addEdge('Foo', 'Out', 'Bar', 'In');
						});
						it('should add an edge', {
							g.addEdge('Foo', 'out', 'Bar', 'in2');
							g.edges.length.should.be(2);
						});
						it('should refuse to add a duplicate edge', {
							final edge = g.edges[0];
							g.addEdge(edge.from.node, edge.from.port, edge.to.node, edge.to.port);
							g.edges.length.should.be(2);
						});
					});
					describe('New edge with index', {
						it('should emit an event', (done) -> {
							g.once('addEdge', (edges) -> {
								final edge:zenflo.graph.GraphEdge = edges[0];
								edge.from.node.should.be('Foo');
								edge.to.port.should.be('in');
								edge.to.index.should.be(1);
								edge.from.index.should.be(null);
								g.edges.length.should.be(3);
								done();
							});
							g.addEdgeIndex('Foo', 'out', null, 'Bar', 'in', 1);
						});
						it('should add an edge', {
							g.addEdgeIndex('Foo', 'out', 2, 'Bar', 'in2');
							g.edges.length.should.be(4);
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
					// it('should produce same JSON when serialized', {
					// 	Reflect.compare(g.toJSON(), json).should.be(0);
					// });
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
						g.nodes.length.should.be(4);
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
					it('should allow modifying node metadata', (done) -> {
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
						g.edges.length.should.be(2);
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
						g.groups.length.should.be(2);
					});
					it('should allow modifying group metadata', (done) -> {
						final group = g.groups[0];
						g.once('changeGroup', (grps) -> {
							final grp:zenflo.graph.GraphGroup = grps[0];
							grp.should.be(group);
							var metadata:Dynamic = grp.metadata;
							metadata.label.should.be('Main');
							metadata.foo.should.be('Bar');
							haxe.Json.stringify(g.groups[1].metadata).should.be("{}");

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
				});
			});
		});
	}
}
