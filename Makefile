.PHONY: help build build-ios build-mac clean export-mac archive-mac install-mac

# Configuration
SCHEME_IOS = NotesApp
SCHEME_MAC = NotesAppMac
CONFIGURATION = Release
DESTINATION_IOS = "platform=iOS Simulator,name=iPhone 15 Pro"
DESTINATION_MAC = "platform=macOS,name=My Mac"
ARCHIVE_PATH = ~/Desktop/NotesApp.xcarchive
EXPORT_PATH = ~/Desktop/NotesAppExport
APP_NAME_MAC = NotesAppMac.app
DESKTOP_APP_PATH = ~/Desktop/NotesAppMac.app

# Disable code signing for local builds
CODE_SIGN_FLAGS = CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

help:
	@echo "NotesApp Build System"
	@echo ""
	@echo "Available commands:"
	@echo "  make build          - Build both iOS and macOS"
	@echo "  make build-ios      - Build iOS app"
	@echo "  make build-mac      - Build macOS app"
	@echo "  make export-mac     - Build and export macOS app to Desktop (recommended)"
	@echo "  make install-mac    - Build and install macOS app to Desktop (alias for export-mac)"
	@echo "  make archive-mac     - Create archive of macOS app (requires signing)"
	@echo "  make run-mac         - Build, export, and run macOS app"
	@echo "  make clean          - Clean build folders"
	@echo ""

build: build-ios build-mac

build-ios:
	@echo "📱 Building iOS app..."
	@xcodebuild -scheme $(SCHEME_IOS) \
		-configuration $(CONFIGURATION) \
		-destination $(DESTINATION_IOS) \
		$(CODE_SIGN_FLAGS) \
		build
	@echo "✅ iOS build complete!"

build-mac:
	@echo "🖥️  Building macOS app..."
	@xcodebuild -scheme $(SCHEME_MAC) \
		-configuration $(CONFIGURATION) \
		-destination $(DESTINATION_MAC) \
		$(CODE_SIGN_FLAGS) \
		build
	@echo "✅ macOS build complete!"

install-mac: build-mac
	@echo "📦 Installing macOS app to Desktop..."
	@find ~/Library/Developer/Xcode/DerivedData -name "$(APP_NAME_MAC)" -type d 2>/dev/null | \
		head -1 | \
		xargs -I {} cp -R {} $(DESKTOP_APP_PATH) 2>/dev/null || \
		echo "⚠️  App not found in DerivedData. Running build first..."
	@if [ -d "$(DESKTOP_APP_PATH)" ]; then \
		echo "✅ App installed to $(DESKTOP_APP_PATH)"; \
		ls -lh "$(DESKTOP_APP_PATH)" | head -1; \
	else \
		echo "❌ Failed to install app. Please check build output."; \
		exit 1; \
	fi

export-mac: build-mac
	@echo "📦 Exporting macOS app to Desktop..."
	@rm -rf $(DESKTOP_APP_PATH) 2>/dev/null || true
	@echo "🔍 Searching for built app..."
	@APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -name "$(APP_NAME_MAC)" -type d -path "*/Products/Release/*" 2>/dev/null | head -1); \
	if [ -z "$$APP_PATH" ]; then \
		APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -name "$(APP_NAME_MAC)" -type d -path "*/Products/Debug/*" 2>/dev/null | head -1); \
	fi; \
	if [ -z "$$APP_PATH" ]; then \
		APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -name "$(APP_NAME_MAC)" -type d 2>/dev/null | head -1); \
	fi; \
	if [ -z "$$APP_PATH" ]; then \
		echo "❌ App not found. Building first..."; \
		$(MAKE) build-mac; \
		sleep 2; \
		APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -name "$(APP_NAME_MAC)" -type d -path "*/Products/Release/*" 2>/dev/null | head -1); \
		if [ -z "$$APP_PATH" ]; then \
			APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -name "$(APP_NAME_MAC)" -type d -path "*/Products/Debug/*" 2>/dev/null | head -1); \
		fi; \
		if [ -z "$$APP_PATH" ]; then \
			APP_PATH=$$(find ~/Library/Developer/Xcode/DerivedData -name "$(APP_NAME_MAC)" -type d 2>/dev/null | head -1); \
		fi; \
	fi; \
	if [ -n "$$APP_PATH" ]; then \
		echo "📋 Found app at: $$APP_PATH"; \
		DESKTOP_PATH=$$HOME/Desktop/NotesAppMac.app; \
		cp -R "$$APP_PATH" "$$DESKTOP_PATH" && \
		echo ""; \
		echo "✅ App exported to $$DESKTOP_PATH"; \
		du -sh "$$DESKTOP_PATH" | awk '{print "📊 Size: " $$1}'; \
		echo ""; \
		echo "🚀 To run the app:"; \
		echo "   open \"$$DESKTOP_PATH\""; \
		echo ""; \
		echo "💡 Note: If macOS blocks the app, right-click and select 'Open'"; \
	else \
		echo "❌ Failed to find or export app."; \
		echo "   Try running: make build-mac"; \
		exit 1; \
	fi

archive-mac:
	@echo "📦 Creating macOS archive..."
	@echo "⚠️  Note: This requires code signing. Set your development team in Xcode."
	@xcodebuild -scheme $(SCHEME_MAC) \
		-configuration $(CONFIGURATION) \
		-destination $(DESTINATION_MAC) \
		-archivePath $(ARCHIVE_PATH) \
		archive
	@echo "✅ Archive created at $(ARCHIVE_PATH)"

clean:
	@echo "🧹 Cleaning build folders..."
	@xcodebuild clean -scheme $(SCHEME_IOS) 2>/dev/null || true
	@xcodebuild clean -scheme $(SCHEME_MAC) 2>/dev/null || true
	@rm -rf ~/Library/Developer/Xcode/DerivedData/NotesApp-* 2>/dev/null || true
	@echo "✅ Clean complete!"

run-mac: export-mac
	@echo "🚀 Running macOS app..."
	@open $(DESKTOP_APP_PATH)

