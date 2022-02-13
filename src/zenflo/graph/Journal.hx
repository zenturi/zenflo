package zenflo.graph;

#if sys
import sys.io.File;
import sys.FileSystem;
#end
import haxe.Json;
import tink.core.Promise;
import cloner.Cloner;
import haxe.Rest;
import zenflo.lib.EventEmitter;
import haxe.DynamicAccess;
import tink.core.Error;

function entryToPrettyString(entry:TransactionEntry):String {
	final a = entry.args;
	switch (entry.cmd) {
		case 'addNode':
			return '${a.id}(${a.component})';
		case 'removeNode':
			return 'DEL ${a.id}(${a.component})';
		case 'renameNode':
			return 'RENAME ${a.oldId} ${a.newId}';
		case 'changeNode':
			return 'META ${a.id}';
		case 'addEdge':
			return '${a.from.node} ${a.from.port} -> ${a.to.port} ${a.to.node}';
		case 'removeEdge':
			return '${a.from.node} ${a.from.port} -X> ${a.to.port} ${a.to.node}';
		case 'changeEdge':
			return 'META ${a.from.node} ${a.from.port} -> ${a.to.port} ${a.to.node}';
		case 'addInitial':
			return '\'${a.from.data}\' -> ${a.to.port} ${a.to.node}';
		case 'removeInitial':
			return '\'${a.from.data}\' -X> ${a.to.port} ${a.to.node}';
		case 'startTransaction':
			return '>>> ${entry.rev}: ${a.id}';
		case 'endTransaction':
			return '<<< ${entry.rev}: ${a.id}';
		case 'changeProperties':
			return 'PROPERTIES';
		case 'addGroup':
			return 'GROUP ${a.name}';
		case 'renameGroup':
			return 'RENAME GROUP ${a.oldName} ${a.newName}';
		case 'removeGroup':
			return 'DEL GROUP ${a.name}';
		case 'changeGroup':
			return 'META GROUP ${a.name}';
		case 'addInport':
			return 'INPORT ${a.name}';
		case 'removeInport':
			return 'DEL INPORT ${a.name}';
		case 'renameInport':
			return 'RENAME INPORT ${a.oldId} ${a.newId}';
		case 'changeInport':
			return 'META INPORT ${a.name}';
		case 'addOutport':
			return 'OUTPORT ${a.name}';
		case 'removeOutport':
			return 'DEL OUTPORT ${a.name}';
		case 'renameOutport':
			return 'RENAME OUTPORT ${a.oldId} ${a.newId}';
		case 'changeOutport':
			return 'META OUTPORT ${a.name}';
		default:
			throw new Error('Unknown journal entry: ${entry.cmd}');
	}
}

// To set, not just update (append) metadata
function calculateMeta(oldMeta:JournalMetadata, newMeta:JournalMetadata):JournalMetadata {
	final setMeta:JournalMetadata = {};
	for(k in oldMeta.keys()){
		setMeta[k] = null;
	}
	
	for(k in newMeta.keys()){
		final v = newMeta[k];
		setMeta[k] = v;
	}

	return setMeta;
}

/**
	## Journalling graph changes

	The Journal can follow graph changes, store them
	and allows to recall previous revisions of the graph.

	Revisions stored in the journal follow the transactions of the graph.
	It is not possible to operate on smaller changes than individual transactions.
	Use startTransaction and endTransaction on Graph to structure the revisions logical changesets.
**/
class Journal extends EventEmitter {
	public var graph:Graph;
	public var entries:ZArray<TransactionEntry>;
	public var history:ZArray<ZArray<TransactionEntry>>;
	public var actionList:ZArray<JournalAction>;
	public var actionHistory:ZArray<ZArray<JournalAction>>;
	public var queueStackNormal:JournalStack<ZArray<JournalAction>>;
	public var queueStackReverse:JournalStack<ZArray<JournalAction>>;
	public var subscribed:Bool;
	public var store:JournalStore;
	public var currentRevision:Int;

	public function new(graph:Graph, ?metadata:JournalMetadata, ?store:JournalStore) {
		super();

		this.graph = graph;
		// Entries added during this revision
		this.entries = [];
		this.history = [];
		this.actionList = [];
		this.actionHistory = [];
		this.queueStackNormal = new JournalStack<ZArray<JournalAction>>();
		this.queueStackReverse = new JournalStack<ZArray<JournalAction>>();
		// Whether we should respond to graph change notifications or not
		this.subscribed = true;
		this.store = store != null ? store : new MemoryJournalStore(this.graph);

		if (this.store.countTransactions() == 0) {
			// Sync journal with current graph to start transaction history
			this.currentRevision = -1;

			this.startTransaction('initial', metadata != null ? metadata : {});
			this.graph.nodes.iter((node) -> {
				this.appendCommand('addNode', node);
			});
			this.graph.edges.iter((edge) -> {
				this.appendCommand('addEdge', edge);
			});

			Lambda.iter(this.graph.initializers, (iip) -> {
				this.appendCommand('addInitial', iip);
			});

			if (this.graph.properties.keys().length > 0) {
				this.appendCommand('changeProperties', this.graph.properties);
			}

			Lambda.iter(this.graph.inports.keys(), (name) -> {
				final port = this.graph.inports[name];
				this.appendCommand('addInport', {
					name: name,
					port: port
				});
			});

			Lambda.iter(this.graph.outports.keys(), (name) -> {
				final port = this.graph.outports[name];
				this.appendCommand('addOutport', {
					name: name,
					port: port
				});
			});

			this.graph.groups.iter((group) -> {
				this.appendCommand('addGroup', group);
			});

			this.endTransaction('initial', metadata != null ? metadata : {});
		} else {
			// Persistent store, start with its latest rev
			this.currentRevision = this.store.lastRevision;
		}

		// Subscribe to graph changes
		this.graph.on('addNode', (node) -> {
			this.appendCommand('addNode', node[0]);
		});
		this.graph.on('removeNode', (node) -> {
			this.appendCommand('removeNode', node[0]);
		});
		this.graph.on('renameNode', (ids) -> {
			final args = {
				oldId: ids[0],
				newId: ids[1],
			};
			this.appendCommand('renameNode', args);
		});
		this.graph.on('changeNode', (vals) -> {
			final node:GraphNode = vals[0];
			final oldMeta = vals[1];
			this.appendCommand('changeNode', {
				id: node.id,
				"_new": node.metadata,
				old: oldMeta,
			});
		});
		this.graph.on('addEdge', (edge) -> {
			this.appendCommand('addEdge', edge[0]);
		});
		this.graph.on('removeEdge', (edge) -> {
			this.appendCommand('removeEdge', edge[0]);
		});
		this.graph.on('changeEdge', (vals) -> {
			final edge:GraphEdge = vals[0];
			final oldMeta = vals[1];
			this.appendCommand('changeEdge', {
				from: edge.from,
				to: edge.to,
				"_new": edge.metadata,
				old: oldMeta,
			});
		});
		this.graph.on('addInitial', (iip) -> {
			this.appendCommand('addInitial', iip[0]);
		});
		this.graph.on('removeInitial', (iip) -> {
			this.appendCommand('removeInitial', iip[0]);
		});

		this.graph.on('changeProperties', (vals) -> {
			final newProps = vals[0], oldProps = vals[1];
			this.appendCommand('changeProperties', {"_new": newProps, old: oldProps});
		});

		this.graph.on('addGroup', (group) -> this.appendCommand('addGroup', group[0]));
		this.graph.on('renameGroup', (names) -> {
			this.appendCommand('renameGroup', {
				oldName: names[0],
				newName: names[1],
			});
		});
		this.graph.on('removeGroup', (group) -> this.appendCommand('removeGroup', group[0]));
		this.graph.on('changeGroup', (vals) -> {
			final n:Dynamic = vals[0];
			this.appendCommand('changeGroup', {name: n.name, "_new": n.metadata, old: vals[1]});
		});

		this.graph.on('addExport', (exported) -> this.appendCommand('addExport', exported[0]));
		this.graph.on('removeExport', (exported) -> this.appendCommand('removeExport', exported[0]));

		this.graph.on('addInport', (vals:Array<Dynamic>) -> this.appendCommand('addInport', {name: vals[0], port: vals[1]}));
		this.graph.on('removeInport', (vals:Array<Dynamic>) -> this.appendCommand('removeInport', {name: vals[0], port: vals[1]}));
		this.graph.on('renameInport', (vals:Array<Dynamic>) -> this.appendCommand('renameInport', {oldId: vals[0], newId: vals[1]}));
		this.graph.on('changeInport', (vals:Array<Dynamic>) -> this.appendCommand('changeInport', {name: vals[0], "_new": vals[1].metadata, old: vals[2]}));
		this.graph.on('addOutport', (vals:Array<Dynamic>) -> this.appendCommand('addOutport', {name: vals[0], port: vals[1]}));
		this.graph.on('removeOutport', (vals:Array<Dynamic>) -> this.appendCommand('removeOutport', {name: vals[0], port: vals[1]}));
		this.graph.on('renameOutport', (vals:Array<Dynamic>) -> this.appendCommand('renameOutport', {oldId: vals[0], newId: vals[1]}));
		this.graph.on('changeOutport', (vals:Array<Dynamic>) -> this.appendCommand('changeOutport', {name: vals[0], "_new": vals[1].metadata, old: vals[2]}));

		this.graph.on('startTransaction', (vals) -> {
			// id, meta
			this.startTransaction(vals[0], vals[1]);
		});
		this.graph.on('endTransaction', (vals) -> {
			// id, meta
			this.endTransaction(vals[0], vals[1]);
		});
	}

	public function startTransaction(id:String, meta:Null<JournalMetadata>) {
		if (!this.subscribed) {
			return;
		}
		if (this.entries.size > 0) {
			throw new Error('Inconsistent @entries');
		}
		this.currentRevision += 1;
		this.appendCommand('startTransaction', {
			id: id,
			metadata: meta,
		}, this.currentRevision);
	}

	public function appendCommand(cmd:String, args:Dynamic, rev:Int = 0) {
		if (!this.subscribed) {
			return;
		}

		final a:DynamicAccess<Any> = args;
		final entry:TransactionEntry = {
			cmd: cmd,
			args: a.copy(),
			rev: rev,
		};
		this.entries.push(entry);
		// this.actionList.add(new JournalAction(cmd, executeEntry.bind(entry), executeEntryInversed.bind(entry)));
	}

	public function endTransaction(id:String, meta:Null<JournalMetadata>) {
		if (!this.subscribed) {
			return;
		}

		this.appendCommand('endTransaction', {
			id: id,
			metadata: meta,
		}, this.currentRevision);
		// TODO: this would be the place to refine @entries into
		// a minimal set of changes, like eliminating changes early in transaction
		// which were later reverted/overwritten
		this.store.putTransaction(this.currentRevision, this.entries);
		// this.history.insert(this.currentRevision, this.entries);
		// this.queueStackNormal.push(this.actionList);
		// this.actionHistory.insert(this.currentRevision, this.actionList);
		this.entries = [];
	}

	public function executeEntry(entry:TransactionEntry) {
		final a = entry.args;
		switch (entry.cmd) {
			case 'addNode':
				{
					this.graph.addNode(a.id, a.component);
				}
			case 'removeNode':
				{
					this.graph.removeNode(a.id);
				}
			case 'renameNode':
				{
					this.graph.renameNode(a.oldId, a.newId);
				}
			case 'changeNode':
				{
					this.graph.setNodeMetadata(a.id, calculateMeta(a.old, a._new));
				}
			case 'addEdge':
				{
					this.graph.addEdge(a.from.node, a.from.port, a.to.node, a.to.port);
				}
			case 'removeEdge':
				{
					this.graph.removeEdge(a.from.node, a.from.port, a.to.node, a.to.port);
				}
			case 'changeEdge':
				{
					this.graph.setEdgeMetadata(a.from.node, a.from.port, a.to.node, a.to.port, calculateMeta(a.old, a._new));
				}
			case 'addInitial':
				{
					if (Std.isOfType(a.to.index, Int)) {
						this.graph.addInitialIndex(a.from.data, a.to.node, a.to.port, a.to.index, a.metadata);
					} else {
						this.graph.addInitial(a.from.data, a.to.node, a.to.port, a.metadata);
					}
				}
			case 'removeInitial':
				{
					this.graph.removeInitial(a.to.node, a.to.port);
				}
			case 'startTransaction':
				{}
			case 'endTransaction':
				{}
			case 'changeProperties':
				{
					this.graph.setProperties(a._new);
				}
			case 'addGroup':
				{
					this.graph.addGroup(a.name, a.nodes, a.metadata);
				}
			case 'renameGroup':
				{
					this.graph.renameGroup(a.oldName, a.newName);
				}
			case 'removeGroup':
				{
					this.graph.removeGroup(a.name);
				}
			case 'changeGroup':
				{
					this.graph.setGroupMetadata(a.name, calculateMeta(a.old, a._new));
				}
			case 'addInport':
				{
					this.graph.addInport(a.name, a.port.process, a.port.port, a.port.metadata);
				}
			case 'removeInport':
				{
					this.graph.removeInport(a.name);
				}
			case 'renameInport':
				{
					this.graph.renameInport(a.oldId, a.newId);
				}
			case 'changeInport':
				{
					this.graph.setInportMetadata(a.name, calculateMeta(a.old, a._new));
				}
			case 'addOutport':
				{
					this.graph.addOutport(a.name, a.port.process, a.port.port, a.port.metadata(a.name));
				}
			case 'removeOutport':
				{
					this.graph.removeOutport(a.name);
				}
			case 'renameOutport':
				{
					this.graph.renameOutport(a.oldId, a.newId);
				}
			case 'changeOutport':
				{
					this.graph.setOutportMetadata(a.name, calculateMeta(a.old, a._new));
				}
			default:
				throw new Error('Unknown journal entry: ${entry.cmd}');
		}
	}

	public function executeEntryInversed(entry:TransactionEntry) {
		final a = entry.args;
		switch (entry.cmd) {
			case 'addNode':
				{
					this.graph.removeNode(a.id);
				}
			case 'removeNode':
				{
					this.graph.addNode(a.id, a.component);
				}
			case 'renameNode':
				{
					this.graph.renameNode(a.newId, a.oldId);
				}
			case 'changeNode':
				{
					this.graph.setNodeMetadata(a.id, calculateMeta(a._new, a.old));
				}
			case 'addEdge':
				{
					this.graph.removeEdge(a.from.node, a.from.port, a.to.node, a.to.port);
				}
			case 'removeEdge':
				{
					this.graph.addEdge(a.from.node, a.from.port, a.to.node, a.to.port);
				}
			case 'changeEdge':
				{
					this.graph.setEdgeMetadata(a.from.node, a.from.port, a.to.node, a.to.port, calculateMeta(a._new, a.old));
				}
			case 'addInitial':
				{
					this.graph.removeInitial(a.to.node, a.to.port);
				}
			case 'removeInitial':
				{
					if (Std.isOfType(a.to.index, Int)) {
						this.graph.addInitialIndex(a.from.data, a.to.node, a.to.port, a.to.index, a.metadata);
					} else {
						this.graph.addInitial(a.from.data, a.to.node, a.to.port, a.metadata);
					}
				}
			case 'startTransaction':
				{}
			case 'endTransaction':
				{}
			case 'changeProperties':
				{
					this.graph.setProperties(a.old);
				}
			case 'addGroup':
				{
					this.graph.removeGroup(a.name);
				}
			case 'renameGroup':
				{
					this.graph.renameGroup(a.newName, a.oldName);
				}
			case 'removeGroup':
				{
					this.graph.addGroup(a.name, a.nodes, a.metadata);
				}
			case 'changeGroup':
				{
					this.graph.setGroupMetadata(a.name, calculateMeta(a._new, a.old));
				}
			case 'addInport':
				{
					this.graph.removeInport(a.name);
				}
			case 'removeInport':
				{
					this.graph.addInport(a.name, a.port.process, a.port.port, a.port.metadata);
				}
			case 'renameInport':
				{
					this.graph.renameInport(a.newId, a.oldId);
				}
			case 'changeInport':
				{
					this.graph.setInportMetadata(a.name, calculateMeta(a._new, a.old));
				}
			case 'addOutport':
				{
					this.graph.removeOutport(a.name);
				}
			case 'removeOutport':
				{
					this.graph.addOutport(a.name, a.port.process, a.port.port, a.port.metadata);
				}
			case 'renameOutport':
				{
					this.graph.renameOutport(a.newId, a.oldId);
				}
			case 'changeOutport':
				{
					this.graph.setOutportMetadata(a.name, calculateMeta(a._new, a.old));
				}
			default:
				throw new Error('Unknown journal entry: ${entry.cmd}');
		}
	}

	public function moveToRevision(revId:Int) {
		if (revId == this.currentRevision) {
			return;
		}

		this.subscribed = false;

		if (revId > this.currentRevision) {
			// Forward replay journal to revId
			// #if !js
			var start =  this.currentRevision + 1;
			var r = start;
			var end = revId;
			var asc = start <= end;
			
			while (asc ? r <= end : r >= end) {
				Lambda.iter(this.store.fetchTransaction(r), (entry) -> {
					this.executeEntry(entry);
				});

				if (asc)
					r += 1;
				else
					r -= 1;
			}
			// #else 
			// js.Syntax.code('
			// for (let start = {2} + 1, r = start, end = {3}, asc = start <= end;
			// 	asc ? r <= end : r >= end;
			// 	asc ? r += 1 : r -= 1) {
			// 	{0}.fetchTransaction(r).forEach((entry) => {
			// 	  {1}(entry);
			// 	});
			//   }
			// ', this.store, this.executeEntry, this.currentRevision, revId);
			// #end
		} else {
			
			// Move backwards, and apply inverse changes
			var r = this.currentRevision;
			var end = revId + 1;
			
			while (r >= end) {
				// Apply entries in reverse order
				final e:Array<TransactionEntry> = this.store.fetchTransaction(r).slice(0);
				e.reverse();
				Lambda.iter(e, (entry)->{
					this.executeEntryInversed(entry);
				});

				r -= 1;
			}
		}

		this.currentRevision = revId;
		this.subscribed = true;
	}

	/**
		## Undoing & redoing

		Undo the last graph change
	**/
	public function undo() {
		if (!this.canUndo()) {
			return;
		}
		this.moveToRevision(this.currentRevision - 1);
	}

	/**
		If there is something to undo
	**/
	public function canUndo():Bool {
		return this.currentRevision > 0;
	}

	/**
		Redo the last undo
	**/
	public function redo() {
		if (!this.canRedo()) {
			return;
		}
		this.moveToRevision(this.currentRevision + 1);
	}

	/**
		If there is something to redo
	**/
	public function canRedo():Bool {
		return this.currentRevision < this.store.lastRevision;
	}

	/**
		# Serializing

		Render a pretty printed string of the journal. Changes are abbreviated
	**/
	public function toPrettyString(startRev:Int = 0, ?endRevParam:Int):String {
		final endRev = endRevParam != null ? endRevParam : this.store.lastRevision;
		final lines:Array<String> = [];
		var r = startRev;
		var end = endRev;
		var asc = startRev <= end;
		while (asc?r<end:r>end) {
			final e = this.store.fetchTransaction(r);
			Lambda.foreach(e, (entry) -> {
				lines.push(entryToPrettyString(entry));
				return true;
			});
			if (asc)
				r += 1;
			else
				r -= 1;
		}
		return lines.join('\n');
	}

	public function toJSON(startRev:Int = 0, ?endRevParam:Int):Array<String> {
		final endRev = endRevParam != null ? endRevParam : this.store.lastRevision;
		final entries:Array<String> = [];
		var r = startRev;
		var end = endRev;
		while (r < end) {
			final e = this.store.fetchTransaction(r);
			for (entry in e) {
				entries.push(entryToPrettyString(entry));
			}
			r += 1;
		}
		return entries;
	}

	public function save(file:String):Promise<String> {
		return new Promise<String>((resolve, reject) -> {
			final json = Json.stringify(this.toJSON(), null, '\t');
			try {
				#if sys
				File.saveContent('${file}.json', json);
				#else
				throw new Error("File saving not yet supported on this platform");
				#end
				resolve('${file}.json');
			} catch (e) {
				reject(new Error(e.toString()));
			}
			return null;
		});
	}
}
