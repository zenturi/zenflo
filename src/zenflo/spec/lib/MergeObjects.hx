package zenflo.spec.lib;

import haxe.Json;
import haxe.ds.Either;
import zenflo.lib.Component;
import tink.core.Promise;

function getComponent() {
	final c = new Component({
		description: 'Merges two objects into one (cloning)',
		inPorts: Either.Left({
			obj1: {
				dataType: 'object',
				description: 'First object',
			},
			obj2: {
				dataType: 'object',
				description: 'Second object',
			},
			overwrite: {
				dataType: 'boolean',
				description: 'Overwrite obj1 properties with obj2',
				control: true,
			},
		}),
		outPorts: Either.Left({
			result: {
				dataType: 'object',
			},
			error: {
				dataType: 'object',
			},
		}),
	});

	

    return c.process((input:ProcessInput, output:ProcessOutput, _)->{
        var dst = null;
        var src  = null;
		final check = input.has('obj1', 'obj2', 'overwrite');
        if (check == false) { return null; }
        final v:Array<Any> = input.getData('obj1', 'obj2', 'overwrite');
        final obj1 = v[0];
        final obj2 = v[1];
        final overwrite:Bool = v[2];
        try {
            src = Json.parse(Json.stringify(overwrite ? obj1 : obj2));
            dst = Json.parse(Json.stringify(overwrite  ? obj2 : obj1));
        }catch(e){
            output.done(e);
            return null;
        }

        for (key in Reflect.fields(dst)){
            final val = Reflect.field(dst, key);
            Reflect.setField(src, key, val); 
        }
		input.activate();
        output.sendDone({ result: src });
        return null;
    });
}
