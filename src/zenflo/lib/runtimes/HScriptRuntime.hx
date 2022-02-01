package zenflo.lib.runtimes;

class HScriptRuntime {
    public static var variables:Map<String, Dynamic> = [];

    public static function setVariable(name:String, value:Dynamic) return variables.set(name, value);

}