APP_NAME  = ZipShare
BUILD_DIR = .build/release
BUNDLE    = $(APP_NAME).app

.PHONY: build app run install clean

build:
	swift build -c release

app: build
	rm -rf $(BUNDLE)
	mkdir -p $(BUNDLE)/Contents/MacOS
	mkdir -p $(BUNDLE)/Contents/Resources
	cp $(BUILD_DIR)/$(APP_NAME) $(BUNDLE)/Contents/MacOS/$(APP_NAME)
	cp Info.plist $(BUNDLE)/Contents/Info.plist
	codesign --force --deep --sign - $(BUNDLE)

run: app
	open $(BUNDLE)

install: app
	rm -rf /Applications/$(BUNDLE)
	cp -R $(BUNDLE) /Applications/
	@echo "Installed to /Applications/$(BUNDLE)."
	@echo "Add it to Login Items in System Settings > General if you want it to launch at boot."

clean:
	rm -rf .build $(BUNDLE)
