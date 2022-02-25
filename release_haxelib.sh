#!/bin/sh
rm -f ZenFlo.zip
zip -r ZenFlo.zip src *.hxml *.json *.md run.n
haxelib submit ZenFlo.zip $HAXELIB_PWD --always