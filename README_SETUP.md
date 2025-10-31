# Xcode Project Setup - Complete Guide

## Quick Start

### Step 1: Generate Xcode Project

Run one of these commands:

```bash
# Option A: Use the simple generator script
./generate_project.sh

# Option B: Use the full setup script (installs xcodegen if needed)
./setup_xcode_project.sh

# Option C: Manual xcodegen command
xcodegen generate
```

### Step 2: Open in Xcode

```bash
open NotesApp.xcodeproj
```

### Step 3: Configure Signing

1. Select **NotesApp** target
2. Go to **Signing & Capabilities** tab
3. Select your **Development Team**
4. Repeat for **ShareExtension** target

### Step 4: Add Capabilities

For **NotesApp** target:
- Add **App Groups** capability → Add `group.com.notesapp`
- Add **Keychain Sharing** capability
- Network access is already configured in entitlements

For **ShareExtension** target:
- Add **App Groups** capability → Add `group.com.notesapp`
- Add **Keychain Sharing** capability (same as main app)

### Step 5: Build and Run

1. Select a simulator or device
2. Press **Cmd+R** to build and run
3. The app should launch!

## What's Included

The generated project includes:

✅ **Main App Target (NotesApp)**
- All Swift source files
- Info.plist configuration
- Entitlements for App Groups and Keychain
- Supports iOS and macOS

✅ **Share Extension Target (ShareExtension)**
- Share Extension source files
- Shared models and services
- Proper entitlements configuration

✅ **Project Configuration**
- Swift 5.9
- iOS 17.0+ / macOS 14.0+
- Debug and Release configurations
- Proper build settings

## Project Structure

```
NotesApp/
├── NotesApp.xcodeproj/        # Generated Xcode project
├── NotesApp/                   # Main app source
│   ├── App/
│   ├── Views/
│   ├── Models/
│   ├── Services/
│   └── Utilities/
├── ShareExtension/             # Share Extension source
├── project.yml                # xcodegen configuration
└── generate_project.sh        # Simple generation script
```

## Troubleshooting

### "xcodegen: command not found"
Install xcodegen:
```bash
brew install xcodegen
```

### "Cannot find type 'Note' in scope"
- Clean build folder: **Cmd+Shift+K**
- Build again: **Cmd+B**
- Check that all files are included in target membership

### Share Extension not appearing
1. Check App Groups match between targets
2. Verify bundle identifiers:
   - Main app: `com.notesapp.NotesApp`
   - Extension: `com.notesapp.NotesApp.ShareExtension`
3. Ensure both targets build successfully

### Build errors about missing files
- Verify `project.yml` is correct
- Regenerate project: `xcodegen generate`
- Check file paths in Xcode project navigator

### Signing errors
- Select a valid development team
- Ensure bundle identifiers are unique
- Check provisioning profiles in Xcode Preferences

## Manual Project Creation (Alternative)

If xcodegen doesn't work, you can create the project manually:

1. Open Xcode → File → New → Project
2. Choose "App" template with SwiftUI
3. Add all files from `NotesApp/` folder
4. Create Share Extension target
5. Configure entitlements as described above

See `SETUP_GUIDE.md` for detailed manual instructions.

## Next Steps After Setup

1. ✅ Test the app in simulator
2. ✅ Configure GitHub settings in Settings
3. ✅ Test Share Extension from Safari
4. ⏳ Integrate actual LLM framework when available
5. ⏳ Add SwiftSoup for better HTML parsing

## Notes

- The project uses **xcodegen** for maintainable project configuration
- All source files are already in place
- LLM integration uses placeholder implementations until frameworks are added
- GitHub sync is fully implemented and ready to test

Happy coding! 🚀

