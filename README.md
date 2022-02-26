# ZenFlo

## Flow Based Programming Kit.
ZenFlo is an implementation of [flow-based programming](http://en.wikipedia.org/wiki/Flow-based_programming) for Haxe running on and expected to run on all Haxe targets. It is a port of the [NoFlo](https://noflojs.org) library.

## Scope
ZenFlo is a way to coordinate and reorganize data flow in any application. If you are building no-code/low-code programs or editors, ZenFlo handles that. Each node is a black-box or small unit of your program, and ZenFlo helps you connect these nodes in such a way that they are portable and reusable.

### Dependencies

 * [Haxe](https://haxe.org/)
 * [Node.js](https://nodejs.org/)
 * [hxnodejs](https://lib.haxe.org/p/hxnodejs)
 * [Neko](https://nekovm.org)
 * [HashLink](https://hashlink.haxe.org)
 * [hxjava](https://lib.haxe.org/p/hxjava)
 * [hxcpp](https://lib.haxe.org/p/hxcpp)
 * [hxcs](https://lib.haxe.org/p/hxcs)
 * [tink_core](https://github.com/haxetink/tink_core)
 * [ds](https://github.com/zenturi/ds)

This project uses [lix.pm](https://github.com/lix-pm/lix.client) as Haxe package manager.
Run `npm install` to install the dependencies.

### Run Tests
```
npx run haxe test.hxml
```


### Usage 
Read the [NoFlo Documentation](https://noflojs.org/documentation/components/) on how components are loaded. 

To convert an Haxe function into a ZenFlo component:
```hx
import zenflo.lib.loader.ManifestLoader;
import zenflo.lib.Macros.asComponent;
import zenflo.lib.Macros.asCallback;
import zenflo.lib.Utils.deflate;

ManifestLoader.init();
final loader = new ComponentLoader(Sys.getCwd()));
final component = (_) -> asComponent(deflate(Math.random), {});
loader.registerComponent('math', 'random', component, (e) -> done());

loader.load('math.random').handle(cb -> {
    switch cb {
        case Success(_): {
            final wrapped = asCallback('math.random', {loader: loader});
            wrapped('bang', (err, res) -> {
                if (err != null) return;
                trace(Std.isOfType(res, Float)); // True
            });
        }
        case Failure(err):{
            // throw error
        }
    }
});
```

See the [Component Spec](src/zenflo/spec/lib/Component.hx) for more examples of how components send data to eachother.

