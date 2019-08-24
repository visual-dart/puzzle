
build:
	dart2aot bin/xdml.dart bin/xdml.dart.aot

start:
	cd bin && dart xdml.dart --config=demo.config.yaml