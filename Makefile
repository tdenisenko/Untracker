APP_NAME := Untracker
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
INSTALLER_DIR := $(BUILD_DIR)/Install $(APP_NAME)
DMG := $(BUILD_DIR)/$(APP_NAME).dmg
RELEASE_BINARY := .build/release/$(APP_NAME)

.PHONY: app build bundle clean run test

build:
	swift build -c release --product $(APP_NAME)

bundle: build
	rm -rf "$(APP_BUNDLE)"
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "$(RELEASE_BINARY)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	cp Packaging/Info.plist "$(APP_BUNDLE)/Contents/Info.plist"
	codesign --force --deep --sign - "$(APP_BUNDLE)"

app: bundle
	rm -rf "$(INSTALLER_DIR)" "$(DMG)"
	mkdir -p "$(INSTALLER_DIR)"
	cp -R "$(APP_BUNDLE)" "$(INSTALLER_DIR)/$(APP_NAME).app"
	ln -s /Applications "$(INSTALLER_DIR)/Applications"
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(INSTALLER_DIR)" -ov -format UDZO "$(DMG)"
	open "$(DMG)"

run: bundle
	open "$(APP_BUNDLE)"

test:
	swift test

clean:
	rm -rf .build build
