# AutoRecall Makefile
#
# This Makefile provides commands for building, testing, and maintaining
# the AutoRecall application. It replaces individual shell scripts with
# a centralized set of commands.

.PHONY: all build test clean repair lint run package test-all fix-entitlements format-plist optimize help

APP_NAME = AutoRecall
BUILD_DIR = .build/release
APP_BUNDLE = $(BUILD_DIR)/$(APP_NAME).app
SOURCES = $(shell find Sources -name "*.swift")
TOOLS_DIR = Tools
SWIFT = swift

# Default target
all: build

# Build the application in release mode
build:
	@echo "Building $(APP_NAME)..."
	@# Check for available disk space
	@FREE_SPACE=$$(df -k . | awk 'NR==2 {print $$4}'); \
	FREE_SPACE_MB=$$((FREE_SPACE / 1024)); \
	MIN_REQUIRED=2048; \
	if [ $$FREE_SPACE_MB -lt $$MIN_REQUIRED ]; then \
		echo "⚠️ Error: Not enough disk space to build. Only $$FREE_SPACE_MB MB available, need at least $$MIN_REQUIRED MB"; \
		echo "Please free up some disk space and try again"; \
		exit 1; \
	fi
	$(SWIFT) build -c release
	@echo "✅ Build completed"

# Run the application
run: build
	@echo "Running $(APP_NAME)..."
	open $(BUILD_DIR)/$(APP_NAME)

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	$(SWIFT) package clean
	rm -rf $(BUILD_DIR)
	@echo "✅ Clean completed"

# Create application bundle
package: build
	@echo "Creating app bundle structure..."
	mkdir -p $(APP_NAME).app/Contents/{MacOS,Resources}
	cp $(BUILD_DIR)/$(APP_NAME) $(APP_NAME).app/Contents/MacOS/
	
	@echo "Copying Info.plist..."
	if [ -f "Sources/$(APP_NAME)/SupportFiles/Info.plist" ]; then \
		cp Sources/$(APP_NAME)/SupportFiles/Info.plist $(APP_NAME).app/Contents/; \
	elif [ -f "Info.plist" ]; then \
		cp Info.plist $(APP_NAME).app/Contents/; \
	else \
		echo "Error: Info.plist not found!"; \
		exit 1; \
	fi
	
	@echo "Copying resources..."
	if [ -d "Sources/$(APP_NAME)/Resources" ]; then \
		cp -r Sources/$(APP_NAME)/Resources $(APP_NAME).app/Contents/Resources/; \
	else \
		mkdir -p $(APP_NAME).app/Contents/Resources/; \
	fi
	
	@echo "Copying assets..."
	if [ -d "Sources/$(APP_NAME)/Assets.xcassets" ]; then \
		cp -r Sources/$(APP_NAME)/Assets.xcassets $(APP_NAME).app/Contents/Resources/; \
	fi
	
	@echo "Copying entitlements..."
	if [ -f "Sources/$(APP_NAME)/$(APP_NAME).entitlements" ]; then \
		cp Sources/$(APP_NAME)/$(APP_NAME).entitlements $(APP_NAME).app/Contents/Resources/; \
	fi
	
	@echo "Setting permissions..."
	chmod +x $(APP_NAME).app/Contents/MacOS/$(APP_NAME)
	
	@echo "✅ App bundle created at: $(PWD)/$(APP_NAME).app"
	@echo "Run with: open $(APP_NAME).app"

# Run tests
test:
	@echo "Running tests..."
	$(SWIFT) test
	@echo "✅ Tests completed"

# Run consolidated tests using TestUtility
test-all:
	@echo "Running all tests with TestUtility..."
	chmod +x $(TOOLS_DIR)/TestUtility.swift
	$(TOOLS_DIR)/TestUtility.swift --all
	@echo "✅ All tests completed"

# Repair and optimize database
repair:
	@echo "Repairing database..."
	$(SWIFT) run -c release $(APP_NAME) --repair-database
	@echo "✅ Database repaired"

# Verify data integrity
verify:
	@echo "Verifying data integrity..."
	$(SWIFT) run -c release $(APP_NAME) --verify-integrity
	@echo "✅ Verification completed"

# Check for and fix memory leaks
check-memory:
	@echo "Analyzing memory usage..."
	$(SWIFT) run -c release $(APP_NAME) --analyze-memory
	@echo "✅ Memory analysis completed"

# Update entitlements file with required permissions
fix-entitlements:
	@echo "Fixing entitlements file..."
	mkdir -p Sources/$(APP_NAME)
	echo '<?xml version="1.0" encoding="UTF-8"?>' > Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '<plist version="1.0">' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '<dict>' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '    <key>com.apple.security.app-sandbox</key>' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '    <true/>' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '    <key>com.apple.security.automation.apple-events</key>' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '    <true/>' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '    <key>com.apple.security.files.user-selected.read-write</key>' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '    <true/>' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '    <key>com.apple.security.device.camera</key>' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '    <true/>' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '    <key>com.apple.security.device.audio-input</key>' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '    <true/>' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '    <key>com.apple.security.device.usb</key>' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '    <true/>' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '    <key>com.apple.security.screen-recording</key>' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '    <true/>' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '</dict>' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	echo '</plist>' >> Sources/$(APP_NAME)/$(APP_NAME).entitlements
	@echo "✅ Updated entitlements file"

# Format plist files
format-plist:
	@echo "Formatting plist files..."
	if [ -f "Sources/$(APP_NAME)/SupportFiles/Info.plist" ]; then \
		plutil -convert xml1 Sources/$(APP_NAME)/SupportFiles/Info.plist; \
		echo "✅ Formatted SupportFiles/Info.plist"; \
	fi
	
	if [ -f "Info.plist" ]; then \
		plutil -convert xml1 Info.plist; \
		echo "✅ Formatted root Info.plist"; \
	fi
	@echo "✅ Plist formatting completed"

# Optimize performance
optimize:
	@echo "Optimizing performance..."
	$(SWIFT) run -c release $(APP_NAME) --optimize
	@echo "✅ Optimization completed"

# Run all fix commands
fix-all: fix-entitlements format-plist repair verify optimize
	@echo "✅ All fixes have been applied"

# Help command
help:
	@echo "AutoRecall Makefile Usage:"
	@echo "  make              Build the application in release mode"
	@echo "  make build        Build the application in release mode"
	@echo "  make run          Build and run the application"
	@echo "  make clean        Clean build artifacts"
	@echo "  make package      Create application bundle"
	@echo "  make test         Run Swift tests"
	@echo "  make test-all     Run all tests using TestUtility"
	@echo "  make repair       Repair and optimize database"
	@echo "  make verify       Verify data integrity"
	@echo "  make check-memory Analyze memory usage"
	@echo "  make fix-entitlements  Update entitlements file"
	@echo "  make format-plist      Format plist files"
	@echo "  make optimize     Optimize application performance"
	@echo "  make fix-all      Run all fix and maintenance tasks"
	@echo "  make help         Show this help message" 