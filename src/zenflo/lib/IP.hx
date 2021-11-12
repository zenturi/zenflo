package zenflo.lib;

enum IPType {
	DATA;
	OpenBracket;
	CloseBracket;
}

typedef IPDynamic = {
	?type:IPType,
	?data:Any,
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
	?initial:Bool
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
            initial: false
        };

        if(Reflect.isObject(options)){
            for (_ => value in Reflect.fields(options)) {
                Reflect.setField(this, value, Reflect.field(options, value));
            }
        }
	}


    /**
        Creates a new IP copying its contents by value not reference
    **/
    public function clone():IP {
        final ip = new IP(this.type);
        for (_=> key in Reflect.fields(this)) {
            final val = Reflect.field(this, key);
            if (key == 'owner') { return ip; }
            if (val == null) { return ip; }
            Reflect.setField(ip, key, val);
        }

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


