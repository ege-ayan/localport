.PHONY: test fmt fmt-check analyze codegen build

test:
	@./scripts/test.sh

fmt:
	dart format lib test

fmt-check:
	dart format --set-exit-if-changed lib test

analyze:
	flutter analyze --fatal-infos

codegen:
	dart run build_runner build

build:
	flutter build macos --release
