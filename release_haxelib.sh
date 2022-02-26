#!/bin/sh
rm -f ZenFlo.zip
zip -r ZenFlo.zip src *.hxml *.json *.md haxe_libraries
haxelib submit ZenFlo.zip $HAXELIB_PWD --always