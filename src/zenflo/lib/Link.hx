package zenflo.lib;

import zenflo.lib.BasePort;
import zenflo.lib.BaseNetwork.NetworkProcess;

typedef Link = {
    ?id:String,
    ?process:NetworkProcess,
    ?port:String,
    ?index:Int,
    ?node:String
}