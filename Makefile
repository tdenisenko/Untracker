APP_NAME := Untracker
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
DMG := $(BUILD_DIR)/$(APP_NAME).dmg
APP_ICONSET := $(BUILD_DIR)/AppIcon.iconset
DMG_BACKGROUND := $(BUILD_DIR)/dmg-background.png
RELEASE_BINARY := .build/release/$(APP_NAME)

.PHONY: app build bundle clean run test

build:
	swift build -c release --product $(APP_NAME)

bundle: build
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	swift Packaging/GenerateInstallerAssets.swift "$(APP_ICONSET)" "$(DMG_BACKGROUND)"
	cp "$(RELEASE_BINARY)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp Packaging/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	iconutil -c icns "$(APP_ICONSET)" -o "$(APP_BUNDLE)/Contents/Resources/AppIcon.icns"
	printf 'APPL????' > "$(APP_BUNDLE)/Contents/PkgInfo"
	codesign --force --deep --sign - "$(APP_BUNDLE)"

app: bundle
	bash Packaging/create-dmg.sh "$(APP_NAME)" "$(APP_BUNDLE)" "$(DMG)" "$(BUILD_DIR)" "$(DMG_BACKGROUND)"

run: bundle
	open "$(APP_BUNDLE)"

test:
	swift test

clean:
	rm -rf .build build
