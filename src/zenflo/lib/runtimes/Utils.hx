package zenflo.lib.runtimes;

import haxe.io.Path;

function parseId(source:String, filePath:String){
    final re = ~/@name ([A-Za-z0-9]+)/;
    if(re.match(source)){
       return re.matched(1);
    }
    return Path.withoutDirectory(Path.withExtension(filePath, Path.extension(filePath)));
}


function parsePlatform(source:String){
    final re = ~/@runtime ([a-z-]+)/;
    if(re.match(source)){
        return re.matched(1);
    }

    return null;
}