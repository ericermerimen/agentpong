VERSION := $(shell cat VERSION | tr -d '[:space:]')
APP_NAME := AgentPong
BUILD_DIR := build
APP_BUNDLE := $(BUILD_DIR)/$(APP_NAME).app
ARCHIVE := $(BUILD_DIR)/$(APP_NAME)-v$(VERSION)-macos.tar.gz

.PHONY: build release app test clean install uninstall link archive

# Development build
build:
	swift build

# Release build
release:
	swift build -c release

# Build .app bundle (release)
app:
	./Scripts/build-app.sh release

# Build signed .app bundle
app-signed:
	./Scripts/build-app.sh release sign

# Run tests
test:
	swift test

# Run the app (debug)
run:
	swift run $(APP_NAME)

# Run the .app bundle
run-app: app
	open $(APP_BUNDLE)

# Symlink .app to /Applications for Launchpad visibility
link: app
	@echo "Linking $(APP_BUNDLE) to /Applications/$(APP_NAME).app..."
	ln -sf "$(shell pwd)/$(APP_BUNDLE)" "/Applications/$(APP_NAME).app"
	@echo "Done. $(APP_NAME) is now in Launchpad."

# Remove from /Applications
unlink:
	rm -f "/Applications/$(APP_NAME).app"

# Install: build + link + setup hooks
install: link
	"$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)" setup
	@echo ""
	@echo "$(APP_NAME) v$(VERSION) installed."
	@echo "Run: open /Applications/$(APP_NAME).app"

# Uninstall completely
uninstall: unlink
	rm -rf ~/.agentpong
	@echo "Uninstalled. Remove AgentPong hooks from ~/.claude/settings.json manually."

# Create release archive (for Homebrew formula)
# Uses --no-mac-metadata to avoid macOS extended attributes in the tarball.
# Homebrew auto-strips one directory level on extraction, so we put
# AgentPong.app at the root of a wrapper directory.
archive: app
	@mkdir -p $(BUILD_DIR)/$(APP_NAME)-v$(VERSION)
	cp -R $(APP_BUNDLE) $(BUILD_DIR)/$(APP_NAME)-v$(VERSION)/
	cp LICENSE $(BUILD_DIR)/$(APP_NAME)-v$(VERSION)/ 2>/dev/null || true
	cd $(BUILD_DIR) && tar --no-mac-metadata -czf "$(APP_NAME)-v$(VERSION)-macos.tar.gz" "$(APP_NAME)-v$(VERSION)"
	@rm -r $(BUILD_DIR)/$(APP_NAME)-v$(VERSION)
	@echo ""
	@echo "Archive: $(ARCHIVE)"
	@echo "SHA256:  $$(shasum -a 256 $(ARCHIVE) | cut -d' ' -f1)"

# Clean build artifacts
clean:
	swift package clean
	rm -rf $(BUILD_DIR)
	rm -rf .build

# Print current version
version:
	@echo $(VERSION)
