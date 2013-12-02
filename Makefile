BIN = node_modules/.bin

test:
	$(BIN)/mocha test/test.js -r should

cli:
	node test/cli.js

example:
	$(BIN)/coffee example/index.coffee

.PHONY: test example