# ZenFlo

## Flow Based Programming Kit.
ZenFlo is an implementation of [flow-based programming](http://en.wikipedia.org/wiki/Flow-based_programming) for Haxe running on and expected to run on all Haxe targets. It is a port of the infamouse [NoFlo](https://noflojs.org)

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

This project uses [lix.pm](https://github.com/lix-pm/lix.client) as Haxe package manager.
Run `npm install` to install the dependencies.

### Run Tests
```
npx run haxe test.hxml
```


