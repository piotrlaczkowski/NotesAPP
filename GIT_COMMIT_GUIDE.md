# Git Commit Guide

## What Gets Committed

The `.gitignore` is configured to commit only relevant project files:

### ✅ Included (Source Code & Config)
- All `.swift` source files
- Configuration files: `project.yml`, `.plist`, `.entitlements`
- Documentation: `*.md` files
- Scripts: `*.sh` files
- Core Data models: `*.xcdatamodeld`
- Project structure files that need to be shared

### ❌ Ignored (Build Artifacts & User Data)
- Xcode build products (`build/`, `DerivedData/`)
- User-specific settings (`xcuserdata/`)
- Generated Xcode project files (except `project.pbxproj`)
- Model files (`.gguf`, `.bin`) - too large
- Swift Package Manager build artifacts
- macOS system files (`.DS_Store`)

## Recommended Commit Structure

```bash
# Initialize git repo (if not already)
git init

# Add all source files
git add .

# Commit
git commit -m "Initial commit: NotesApp with LLM integration and GitHub sync"
```

## What to Commit

1. **Source Code**: All Swift files in `NotesApp/` and `ShareExtension/`
2. **Configuration**: `project.yml`, `.plist`, `.entitlements`
3. **Documentation**: All `.md` files
4. **Scripts**: `*.sh` setup scripts

## What NOT to Commit

- `NotesApp.xcodeproj/` (will be generated from `project.yml`)
- Build folders
- Downloaded model files
- User-specific Xcode settings

## Regenerating Project

If someone clones your repo, they can regenerate the Xcode project:

```bash
# Install xcodegen if needed
brew install xcodegen

# Generate project
./generate_project.sh

# Open in Xcode
open NotesApp.xcodeproj
```

This way, the repo stays clean with only source code and configuration!

