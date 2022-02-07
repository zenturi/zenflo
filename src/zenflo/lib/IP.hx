package zenflo.lib;

import tink.core.Ref;
import haxe.Json;
import haxe.DynamicAccess;

enum abstract IPType(String) from String to String {
	final DATA = "data";
	final OpenBracket = "openBracket";
	final CloseBracket = "closeBracket";
}

typedef IPDynamic = {
	?type:IPType,
	?data:Dynamic,
	?isIP:Bool,
	?scope:String, // sync scope id
    // packet owner process
	?owner:Component,
    // cloning safety flag
	?clonable:Bool,
    // addressable port index
	?index:Int,
	?schema:Any,
	?dataType:String,
	?initial:Bool,
	?___cloneData:DynamicAccess<Dynamic>
}

/**
	Information Packets

	IP objects are the way information is transmitted between
	components running in a ZenFlo network. IP objects contain
	a `type` that defines whether they're regular `data` IPs
	or whether they are the beginning or end of a stream
	(`openBracket`, `closeBracket`).

	The component currently holding an IP object is identified
	with the `owner` key.

	By default, IP objects may be sent to multiple components.
	If they're set to be clonable, each component will receive
	its own clone of the IP. This should be enabled for any
	IP object working with data that is safe to clone.

	It is also possible to carry metadata with an IP object.
	For example, the `datatype` and `schema` of the sending
	port is transmitted with the IP object.

	Valid IP types:
	- 'data'
	- 'openBracket'
	- 'closeBracket'
**/

@:forward
abstract IP(IPDynamic) from IPDynamic to IPDynamic {
	/**
		Detects if an arbitrary value is an IP
	**/
	public static function isIP(obj:Dynamic):Bool {
		return Reflect.isObject(obj) && Reflect.hasField(obj, "isIP") == true && obj.isIP == true;
	}

	/**
		Creates as new IP object
		Valid types: 'data', 'openBracket', 'closeBracket'
	**/
	public function new(type:IPType = DATA, ?data:Any, ?options:Any) {
        this = {
            type: type,
            data: data,
            isIP: true,
            // cloning safety flag
            clonable: false,
            dataType: "all",
            initial: false,
			scope: "null"
        };

        if(Reflect.isObject(options)){
			this.___cloneData = Reflect.copy(options);
            for (_ => value in Reflect.fields(options)) {
                Reflect.setField(this, value, Reflect.field(options, value));
            }
        }
	}


    /**
        Creates a new IP copying its contents by value not reference
		[FIX: Haxe does seems to only copy by reference]
    **/
    public function clone():IP {
		final opts =  Reflect.copy(this.___cloneData);
		final copy = Reflect.copy(this);
        for (_=> key in Reflect.fields(copy)) {
            final val = Reflect.field(copy, key);
            if (key == 'owner') { break; }
            if (val == null) { break; }
			if (key == "data" && Reflect.isObject(val)) { continue; }
			if (key == "___cloneData") { continue; }
            Reflect.setField(opts, key, val);
        }
		
	
		var d = this.data;
		if(Reflect.isObject(this.data) && !Std.isOfType(this.data, Array) && !Std.isOfType(this.data, String) && !Std.isOfType(this.data, Float) && !Std.isOfType(this.data, Int) && !Std.isOfType(this.data, Bool)){
			d = Reflect.copy(this.data);
			for (_=> key in Reflect.fields(d)) {
				final val = Reflect.field(d, key);
				if(Reflect.isFunction(val)){
					Reflect.setField(d, key, null);
					continue;
				}
				Reflect.setField(d, key, val);
			}
			opts["data"] = d;
		}

		if(Std.isOfType(this.data, Array)){
			d = [];
			var arr:Array<Dynamic> = this.data;
			for(val in arr){
				if(Reflect.isFunction(val)){
					continue;
				}
				d.push(val);
			}
		}
		
		
		// trace(opts);
        var ip = new IP(this.type, d,  opts);
		// trace(ip);
		return ip;
    }

	@:arrayAccess
	public function setField(key:String, value:Any){
		Reflect.setField(this, key, value);
	}

	@:arrayAccess
	public function getField(key:String):Dynamic {
		return Reflect.field(this, key);
	}
    public function move(owner:Component):IP {
        this.owner = owner;
        return this;
    }

    /**
        Frees IP contents
    **/
    public function drop() {
        for (_=> key in Reflect.fields(this)) {
            Reflect.deleteField(this, key);
        }
    }
}


