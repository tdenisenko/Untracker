APP_NAME := Untracker
APP_BUNDLE := build/$(APP_NAME).app
RELEASE_BINARY := .build/release/$(APP_NAME)

.PHONY: app build clean run test

build:
	swift build -c release --product $(APP_NAME)

app: build
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "$(RELEASE_BINARY)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp Packaging/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	codesign --force --deep --sign - "$(APP_BUNDLE)"

run: app
	open "$(APP_BUNDLE)"

test:
	swift test

clean:
	rm -rf .build build
