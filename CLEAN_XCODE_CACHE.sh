#!/bin/bash

# Script to clean Xcode cache and fix compilation issues

echo "🧹 Cleaning Xcode cache and derived data..."

# Clean build folder
echo "1. Cleaning build folder..."
rm -rf ~/Library/Developer/Xcode/DerivedData/NotesApp-*

# Clean module cache
echo "2. Cleaning module cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex

# Clean Swift package caches
echo "3. Cleaning Swift package caches..."
rm -rf ~/Library/Caches/org.swift.swiftpm

# Clean Xcode build caches
echo "4. Cleaning Xcode build caches..."
rm -rf ~/Library/Developer/Xcode/Archives
rm -rf ~/Library/Caches/com.apple.dt.Xcode

echo ""
echo "✅ Cache cleaned!"
echo ""
echo "Next steps:"
echo "1. Quit Xcode completely (Cmd+Q)"
echo "2. Reopen NotesApp.xcodeproj"
echo "3. Clean Build Folder: Cmd+Shift+K"
echo "4. Build: Cmd+B"
echo ""

