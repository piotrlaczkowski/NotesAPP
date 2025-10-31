# Fixing Xcode "Cannot find AddURLView" Error

## Quick Fix

The file `AddURLView.swift` exists and is correct. This is an Xcode indexing issue.

### Option 1: Clean Build (Recommended)
1. In Xcode: **Product → Clean Build Folder** (Shift+Cmd+K)
2. Close Xcode
3. Reopen the project
4. Build again (Cmd+B)

### Option 2: Reset Xcode Index
1. Close Xcode
2. Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData/NotesApp-*`
3. Reopen Xcode
4. Wait for indexing to complete
5. Build (Cmd+B)

### Option 3: Manual File Check
1. In Xcode, right-click the `NotesApp/Views` folder
2. Select "Add Files to NotesApp..."
3. Navigate to `NotesApp/Views/AddURLView.swift`
4. Make sure it's checked and added to the target
5. Build again

### Verification
The file should be at:
```
NotesApp/Views/AddURLView.swift
```

It should contain the `AddURLView` struct definition.

