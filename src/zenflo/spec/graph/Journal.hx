package zenflo.spec.graph;

import haxe.Timer;
import buddy.BuddySuite;

using equals.Equal;
using buddy.Should;

@colorize
class Journal extends buddy.BuddySuite {
	public function new() {
		describe('FBP Graph Journal', {
			describe('journalling operations', {
				describe('connected to initialized graph', {
					final g = new zenflo.graph.Graph();
					g.addNode('Foo', 'Bar');
					g.addNode('Baz', 'Foo');
					g.addEdge('Foo', 'out', 'Baz', 'in');
					final j = new zenflo.graph.Journal(g);
					it('should have just the initial transaction', {
						j.store.lastRevision.should.be(0);
					});
				});
				describe('following basic graph changes', {
					final g = new zenflo.graph.Graph();
					final j = new zenflo.graph.Journal(g);
					it('should create one transaction per change', {
						g.addNode('Foo', 'Bar');
						g.addNode('Baz', 'Foo');
						g.addEdge('Foo', 'out', 'Baz', 'in');
						j.store.lastRevision.should.be(3);
						g.removeNode('Baz');
						j.store.lastRevision.should.be(4);
					});
				});

				describe('pretty printing', {
					final g = new zenflo.graph.Graph();
					final j = new zenflo.graph.Journal(g);

					g.startTransaction('test1');
					g.addNode('Foo', 'Bar');
					g.addNode('Baz', 'Foo');
					g.addEdge('Foo', 'out', 'Baz', 'in');
					g.addInitial(42, 'Foo', 'in');
					g.removeNode('Foo');
					g.endTransaction('test1');

					g.startTransaction('test2');
					g.removeNode('Baz');
					g.endTransaction('test2');

					it('should be human readable', {
						final ref = '>>> 0: initial
<<< 0: initial
>>> 1: test1
Foo(Bar)
Baz(Foo)
Foo out -> in Baz
\'42\' -> in Foo
META Foo out -> in Baz
Foo out -X> in Baz
\'42\' -X> in Foo
META Foo
DEL Foo(Bar)
<<< 1: test1';
						j.toPrettyString(0, 2).should.be(ref);
					});
				});

				describe('jumping to revision', {
					final g = new zenflo.graph.Graph();
					final j = new zenflo.graph.Journal(g);
					g.addNode('Foo', 'Bar');
					g.addNode('Baz', 'Foo');
					g.addEdge('Foo', 'out', 'Baz', 'in');
					g.addInitial(42, 'Foo', 'in');
					g.removeNode('Foo');
					beforeEach((done) -> {
						haxe.Timer.delay(() -> {
							done();
						}, 0);
					});
					it('should change the graph', {
						j.moveToRevision(0);
						g.nodes.size.should.be(0);
						j.moveToRevision(2);
						g.nodes.size.should.be(2);
						j.moveToRevision(5);
						g.nodes.size.should.be(1);
					});
				});

				describe('linear undo/redo', {
					final g = new zenflo.graph.Graph();
					final j = new zenflo.graph.Journal(g);
					g.addNode('Foo', 'Bar');
					g.addNode('Baz', 'Foo');
					g.addEdge('Foo', 'out', 'Baz', 'in');
					g.addInitial(42, 'Foo', 'in');

					final graphBeforeError = g.toJSON();
					it('undo should restore previous revision',  ()->{
						g.nodes.size.should.be(2);
						g.removeNode('Foo');
						g.nodes.size.should.be(1);
						j.undo();
						g.nodes.size.should.be(2);
						g.toJSON().equals(graphBeforeError);
					});
					it('redo should apply the same change again', {
						j.redo();
						g.nodes.size.should.be(1);
					});
					it('undo should also work multiple revisions back', {
						g.removeNode('Baz');
						j.undo();
						j.undo();
						g.nodes.size.should.be(2);
						g.toJSON().equals(graphBeforeError);
					});
				});
				describe('undo/redo of metadata changes', {
					final g = new zenflo.graph.Graph();
					final j = new zenflo.graph.Journal(g);
					beforeEach((done)->{
						haxe.Timer.delay(()->{
							done();
						}, 0);
					});

					g.addNode('Foo', 'Bar');
					g.addNode('Baz', 'Foo');
					g.addEdge('Foo', 'out', 'Baz', 'in');

					it('adding group', {
						g.addGroup('all', ['Foo', 'Bax'], {label: 'all nodes'});
						g.groups.size.should.be(1);
						g.groups[0].name.should.be('all');
					});
					it('undoing group add', {
						j.undo();
						g.groups.size.should.be(0);
					});
					it('redoing group add', {
						j.redo();
						g.groups[0].metadata['label'].should.be('all nodes');
					});

					it('changing group metadata adds revision', {
						final r = j.store.lastRevision;
						g.setGroupMetadata('all', {label: 'ALL NODES!'});
						j.store.lastRevision.should.be(r + 1);
					});
				
					it('undoing group metadata change', {
						j.undo();
						g.groups[0].metadata["label"].should.be('all nodes');
					});
					
					it('redoing group metadata change', (done) -> {
						j.redo();
						haxe.Timer.delay(() -> {
							g.groups[0].metadata['label'].should.be('ALL NODES!');
							done();
						}, 10);
					});

					it('setting node metadata', {
						g.setNodeMetadata('Foo', {oneone: 11, '2': 'two'});
						g.getNode('Foo').metadata.keys().length.should.be(2);
					});
					it('undoing set node metadata', {
						j.undo();
						g.getNode('Foo').metadata.keys().length.should.be(0);
					});
					it('redoing set node metadata', () -> {
						j.redo();
						final node = g.getNode('Foo');
						Reflect.isObject(node).should.be(true);
						node.metadata['oneone'].should.be(11);
					});
				});
			});
			describe('journalling of graph merges', {
				final A = '
                {
                "properties": { "name": "Example", "foo": "Baz", "bar": "Foo" },
                "inports": {
                  "in": { "process": "Foo", "port": "in", "metadata": { "x": 5, "y": 100 } }
                },
                "outports": {
                  "out": { "process": "Bar", "port": "out", "metadata": { "x": 500, "y": 505 } }
                },
                "groups": [
                  { "name": "first", "nodes": [ "Foo" ], "metadata": { "label": "Main" } },
                  { "name": "second", "nodes": [ "Foo2", "Bar2" ], "metadata": {} }
                ],
                "processes": {
                  "Foo": { "component": "Bar", "metadata": { "display": { "x": 100, "y": 200 }, "hello": "World" } },
                  "Bar": { "component": "Baz", "metadata": {} },
                  "Foo2": { "component": "foo", "metadata": {} },
                  "Bar2": { "component": "bar", "metadata": {} }
                },
                "connections": [
                  { "src": { "process": "Foo", "port": "out" }, "tgt": { "process": "Bar", "port": "in" }, "metadata": { "route": "foo", "hello": "World" } },
                  { "src": { "process": "Foo", "port": "out2" }, "tgt": { "process": "Bar", "port": "in2" } },
                  { "data": "Hello, world!", "tgt": { "process": "Foo", "port": "in" } },
                  { "data": "Hello, world, 2!", "tgt": { "process": "Foo", "port": "in2" } },
                  { "data": "Cheers, world!", "tgt": { "process": "Foo", "port": "arr" } }
                ]
                }';
				final B = '
                {
                "properties": { "name": "Example", "foo": "Baz", "bar": "Foo" },
                "inports": {
                    "in": { "process": "Foo", "port": "in", "metadata": { "x": 500, "y": 1 } }
                },
                "outports": {
                    "out": { "process": "Bar", "port": "out", "metadata": { "x": 500, "y": 505 } }
                },
                "groups": [
                    { "name": "second", "nodes": [ "Foo", "Bar" ] }
                ],
                "processes": {
                    "Foo": { "component": "Bar", "metadata": { "display": { "x": 100, "y": 200 }, "hello": "World" } },
                    "Bar": { "component": "Baz", "metadata": {} },
                    "Bar2": { "component": "bar", "metadata": {} },
                    "Bar3": { "component": "bar2", "metadata": {} }
                },
                "connections": [
                    { "src": { "process": "Foo", "port": "out" }, "tgt": { "process": "Bar", "port": "in" }, "metadata": { "route": "foo", "hello": "World" } },
                    { "src": { "process": "Foo2", "port": "out2" }, "tgt": { "process": "Bar3", "port": "in2" } },
                    { "data": "Hello, world!", "tgt": { "process": "Foo", "port": "in" } },
                    { "data": "Hello, world, 2!", "tgt": { "process": "Bar3", "port": "in2" } },
                    { "data": "Cheers, world!", "tgt": { "process": "Bar2", "port": "arr" } }
                ]}';

				var a:zenflo.graph.Graph = null;
				var b:zenflo.graph.Graph = null;
				var g:zenflo.graph.Graph = null; // one we modify
				var j:zenflo.graph.Journal = null;

				describe('G -> B', {
					it('G starts out as A', (done) -> {
						zenflo.graph.Graph.loadJSON(haxe.Json.parse(A)).handle((c) -> {
							switch c {
								case Success(instance): {
										a = instance;
									}
								case Failure(err): {
										fail(err);
									}
							}
							zenflo.graph.Graph.loadJSON(haxe.Json.parse(A)).handle((c2) -> {
								switch c2 {
									case Success(instance2): {
											g = instance2;
										}
									case Failure(loadErr): {
											fail(loadErr);
										}
								}
								zenflo.graph.Graph.equivalent(a, g).should.be(true);
								done();
							});
						});
					});
					it('G and B starts out different', (done) -> {
						zenflo.graph.Graph.loadJSON(haxe.Json.parse(B)).handle((c) -> {
							switch c {
								case Success(instance): {
										b = instance;
									}
								case Failure(err): {
										fail(err);
									}
							}
							zenflo.graph.Graph.equivalent(g, b).should.be(false);
							done();
						});
					});
					it('merge should make G equivalent to B', (done) -> {
						j = new zenflo.graph.Journal(g);
						g.startTransaction('merge');
						zenflo.graph.Graph.mergeResolveTheirs(g, b);
						g.endTransaction('merge');
						zenflo.graph.Graph.equivalent(g, b).should.be(true);
						zenflo.graph.Graph.equivalent(g, a).should.be(false);
						done();
					});
					it('undoing merge should make G equivalent to A again', (done) -> {
						j.undo();
						final res = zenflo.graph.Graph.equivalent(g, a);
						res.should.be(true);
						done();
					});
				});
			});
		});
	}
}
