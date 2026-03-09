APP_NAME = MeetMute
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app

BUNDLE_ID = com.meetmute.app

.PHONY: build clean install run dev

build:
	swift build -c release
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	mkdir -p $(APP_BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_BUNDLE)/Contents/MacOS/
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/
	cp Resources/MeetMute.icns $(APP_BUNDLE)/Contents/Resources/
	codesign --force --sign - $(APP_BUNDLE)
	@echo "Built $(APP_BUNDLE)"

clean:
	swift package clean
	rm -rf $(APP_BUNDLE)

install: build
	cp -r $(APP_BUNDLE) /Applications/
	@echo "Installed to /Applications/$(APP_BUNDLE)"

run: build
	open $(APP_BUNDLE)

dev: build
	@-pkill -x $(APP_NAME) 2>/dev/null; sleep 0.5
	@-tccutil reset Accessibility $(BUNDLE_ID) 2>/dev/null
	@-tccutil reset AppleEvents $(BUNDLE_ID) 2>/dev/null
	rm -rf /Applications/$(APP_BUNDLE)
	cp -r $(APP_BUNDLE) /Applications/
	open /Applications/$(APP_BUNDLE)
	@echo "Dev install complete - grant permissions when prompted"
