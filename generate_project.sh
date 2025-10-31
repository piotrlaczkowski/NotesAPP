#!/bin/bash

# Simple script to generate Xcode project
# Usage: ./generate_project.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 Generating Xcode Project for NotesApp..."

# Check for xcodegen
if ! command -v xcodegen &> /dev/null; then
    echo ""
    echo "❌ xcodegen is not installed."
    echo ""
    echo "Please install it using one of these methods:"
    echo ""
    echo "Option 1: Install via Homebrew (recommended)"
    echo "  brew install xcodegen"
    echo ""
    echo "Option 2: Install via Mint"
    echo "  brew install mint"
    echo "  mint install yonaskolb/xcodegen"
    echo ""
    echo "Option 3: Download binary"
    echo "  Visit: https://github.com/yonaskolb/XcodeGen/releases"
    echo ""
    exit 1
fi

# Check for project.yml
if [ ! -f "project.yml" ]; then
    echo "❌ project.yml not found!"
    exit 1
fi

# Generate project
echo "📝 Generating project from project.yml..."
xcodegen generate

if [ -d "NotesApp.xcodeproj" ]; then
    echo ""
    echo "✅ Success! Xcode project generated."
    echo ""
    echo "📂 Project location: $SCRIPT_DIR/NotesApp.xcodeproj"
    echo ""
    echo "🎯 Next steps:"
    echo "   1. Open NotesApp.xcodeproj in Xcode"
    echo "   2. Select your development team in Signing & Capabilities"
    echo "   3. Build and run (Cmd+R)"
    echo ""
    
    # Try to open in Xcode if available
    if command -v open &> /dev/null; then
        read -p "Open in Xcode now? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            open NotesApp.xcodeproj
        fi
    fi
else
    echo "❌ Project generation failed. Check errors above."
    exit 1
fi

