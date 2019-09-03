
build:
	dart2aot bin/puzzle.dart bin/puzzle.dart.aot

start:
	cd bin && dart puzzle.dart --config=demo.config.yaml