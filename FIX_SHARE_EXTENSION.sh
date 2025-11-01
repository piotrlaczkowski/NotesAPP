#!/bin/bash

# Fix Share Extension Configuration Script
# This script will regenerate the Xcode project with correct Bundle Identifiers

set -e

echo "🔧 Fixing Share Extension Configuration..."
echo ""

# Check if XcodeGen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "❌ XcodeGen is not installed!"
    echo "📦 Installing XcodeGen..."
    
    if command -v brew &> /dev/null; then
        brew install xcodegen
    else
        echo "Please install Homebrew first: https://brew.sh"
        echo "Then run: brew install xcodegen"
        exit 1
    fi
fi

echo "✅ XcodeGen found"
echo ""

# Regenerate Xcode project
echo "🔄 Regenerating Xcode project..."
xcodegen generate

if [ $? -eq 0 ]; then
    echo "✅ Xcode project regenerated successfully!"
else
    echo "❌ Failed to regenerate project"
    exit 1
fi

echo ""
echo "✅ Configuration fixed!"
echo ""
echo "📱 Next Steps:"
echo "1. Open NotesApp.xcodeproj in Xcode"
echo "2. Select NotesApp scheme"
echo "3. Select your iPhone as destination"
echo "4. In Xcode: Product → Scheme → Edit Scheme"
echo "5. Under 'Build', ensure 'ShareExtension' is checked ✅"
echo "6. Clean Build Folder: ⌘⇧K"
echo "7. Build and Run: ⌘R"
echo ""
echo "After installation:"
echo "- Open Safari on iPhone"
echo "- Tap Share button"
echo "- Scroll down, tap 'More'"
echo "- Enable 'Share to NotesApp'"
echo "- Tap Done"
echo ""
echo "🎉 Done!"

