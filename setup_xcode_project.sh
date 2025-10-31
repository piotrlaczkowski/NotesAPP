#!/bin/bash

# Setup script for NotesApp Xcode Project
set -e

echo "🚀 Setting up NotesApp Xcode Project..."

# Check if xcodegen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "📦 xcodegen not found. Installing via Homebrew..."
    
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew not found. Please install Homebrew first:"
        echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    
    brew install xcodegen
    echo "✅ xcodegen installed"
fi

# Check if we're in the right directory
if [ ! -f "project.yml" ]; then
    echo "❌ project.yml not found. Please run this script from the NotesApp directory."
    exit 1
fi

# Generate Xcode project
echo "📝 Generating Xcode project..."
xcodegen generate

if [ $? -eq 0 ]; then
    echo "✅ Xcode project generated successfully!"
    echo ""
    echo "📂 Project file: NotesApp.xcodeproj"
    echo ""
    echo "🎯 Next steps:"
    echo "   1. Open NotesApp.xcodeproj in Xcode"
    echo "   2. Select your development team in Signing & Capabilities"
    echo "   3. Build and run (Cmd+R)"
    echo ""
else
    echo "❌ Failed to generate Xcode project"
    exit 1
fi

