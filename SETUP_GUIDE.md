# NotesApp - Xcode Setup Guide

## Creating the Xcode Project

Since we've created the source files, you need to create the Xcode project file. Follow these steps:

### 1. Create New Project in Xcode

1. Open Xcode
2. File → New → Project
3. Select **App** under iOS or macOS
4. Choose:
   - **Product Name**: NotesApp
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Minimum Deployment**: iOS 17.0 / macOS 14.0
5. Save to a **different location** temporarily (we'll move files)

### 2. Add Existing Files

1. **Delete** the default `ContentView.swift` that Xcode created
2. **Remove** the default App file
3. Right-click on the project → **Add Files to "NotesApp"**
4. Navigate to `/Users/piotrlaczkowski/Desktop/NotesApp/NotesApp`
5. Select all files and folders EXCEPT `Info.plist` (we have custom ones)
6. Check **"Copy items if needed"** and **"Create groups"**
7. Click Add

### 3. Add Share Extension Target

1. File → New → Target
2. Select **Share Extension**
3. Name it "ShareExtension"
4. Use SwiftUI (if option available)
5. Add the ShareExtension files:
   - Right-click ShareExtension target → Add Files
   - Add `ShareExtension/ShareViewController.swift`
   - Add `ShareExtension/Info.plist`
   - Add `ShareExtension/ShareExtension.entitlements`

### 4. Configure Entitlements

1. Select the main app target
2. Signing & Capabilities → Add Capability
   - **App Groups**: Add `group.com.notesapp`
   - **Keychain Sharing**: Enable
   - **Network**: Enable (Outgoing Connections)

3. Select ShareExtension target
4. Signing & Capabilities → Add Capability
   - **App Groups**: Add `group.com.notesapp`
   - **Keychain Sharing**: Enable (same identifier as main app)

### 5. Configure Info.plist Files

1. Replace Xcode-generated Info.plist with our custom ones:
   - Main app: Use `NotesApp/Info.plist`
   - Extension: Use `ShareExtension/Info.plist`

2. In Xcode project settings:
   - Select target → Info tab
   - Ensure URL Types are configured if needed

### 6. Add Frameworks (When Available)

When MLC-LLM or llama.cpp Swift bindings become available:

1. File → Add Package Dependencies
2. Add the package URL
3. Link to appropriate targets

For SwiftSoup (HTML parsing):
1. File → Add Package Dependencies
2. URL: `https://github.com/scinfu/SwiftSoup.git`
3. Add to main app target

### 7. Create Core Data Model

1. File → New → File
2. Data Model → **NotesDataModel**
3. Add Entity: **NoteEntity**
4. Add attributes:
   - `id`: String (UUID)
   - `title`: String
   - `summary`: String
   - `content`: String
   - `url`: String (optional)
   - `tags`: Transformable ([String])
   - `dateCreated`: Date
   - `dateModified`: Date
   - `syncStatus`: String (SyncStatus enum)

### 8. Build Settings

Verify these settings for both targets:

- **iOS Deployment Target**: 17.0
- **macOS Deployment Target**: 14.0
- **Swift Language Version**: Swift 5.9
- **Development Team**: Your team

### 9. Bundle Identifiers

- Main App: `com.yourdomain.NotesApp`
- Share Extension: `com.yourdomain.NotesApp.ShareExtension`

### 10. First Build

1. Clean Build Folder (Cmd+Shift+K)
2. Build (Cmd+B)
3. Fix any import issues or missing files

## Common Issues

### "Cannot find type 'Note' in scope"
- Ensure all Model files are added to the target

### "Missing Info.plist"
- Check that custom Info.plist files are used
- Verify file is in target membership

### Share Extension not appearing
- Ensure App Groups match between app and extension
- Check entitlements are properly configured
- Verify bundle identifier follows pattern

### Network errors
- Check Info.plist has proper NSAppTransportSecurity settings
- Verify entitlements include network access

## Next Steps After Setup

1. Run the app on simulator/device
2. Test Share Extension from Safari
3. Configure GitHub settings
4. Test model download (will need framework)
5. Test content extraction

## Dependencies to Add Later

When available, add these Swift packages:
- MLC-LLM Swift bindings (or llama.cpp)
- SwiftSoup for HTML parsing
- Any other LLM-related frameworks

The app is structured to work with placeholder implementations until these are available.

