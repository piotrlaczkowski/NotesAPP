# 📤 Share Extension Setup Guide

This guide will help you configure the Share Extension so **NotesApp** appears in the iOS Share Sheet when browsing the web.

## ✅ Prerequisites

- Xcode project with Share Extension already created
- NotesApp installed on your iPhone
- App Group configured (should be: `group.com.piotrlaczkowski.NotesApp`)

---

## 🔧 Step 1: Configure Share Extension in Xcode

### 1.1 Verify Share Extension Target Exists

1. Open `NotesApp.xcodeproj` in Xcode
2. In the left sidebar, you should see:
   - **NotesApp** (main app target)
   - **ShareExtension** (extension target)

If you don't see ShareExtension, you may need to add it.

### 1.2 Check Signing & Capabilities

#### For NotesApp Target:
1. Select **NotesApp** in the left sidebar
2. Click the **NotesApp** target (under TARGETS)
3. Go to **Signing & Capabilities** tab
4. Ensure:
   - ✅ **Automatically manage signing** is checked
   - ✅ Your **Team** is selected
   - ✅ **App Groups** capability is added with: `group.com.piotrlaczkowski.NotesApp`

#### For ShareExtension Target:
1. Select **ShareExtension** in the left sidebar
2. Click the **ShareExtension** target (under TARGETS)
3. Go to **Signing & Capabilities** tab
4. Ensure:
   - ✅ **Automatically manage signing** is checked
   - ✅ **Same Team** as NotesApp
   - ✅ **App Groups** capability is added with: `group.com.piotrlaczkowski.NotesApp`
   - ✅ Bundle Identifier should be: `com.piotrlaczkowski.NotesApp.ShareExtension` (or similar)

### 1.3 Verify Bundle Identifier Format

- **NotesApp**: `com.piotrlaczkowski.NotesApp`
- **ShareExtension**: `com.piotrlaczkowski.NotesApp.ShareExtension`

The Share Extension should be a child identifier of the main app.

---

## 📱 Step 2: Build and Install Both Targets

### 2.1 Build Both Targets

When you build for iPhone, **both** targets must be built:

1. In Xcode, make sure **NotesApp scheme** is selected (top toolbar)
2. Select your **iPhone** as destination
3. Press **⌘B** (Build) - this should build both the app and extension
4. Press **⌘R** (Run) - this installs both on your iPhone

**Important:** If you only build the main app, the extension won't be installed!

### 2.2 Verify Extension is Installed

After installation, check:
1. On your iPhone: **Settings → General → VPN & Device Management**
2. You should see **two** entries:
   - NotesApp
   - NotesApp Share Extension (or similar)

---

## 🔍 Step 3: Enable Extension in iOS Share Sheet

### 3.1 Find the Extension (First Time)

When you first use Share Extension, it's **hidden** in the "More" section:

1. Open **Safari** (or any browser) on your iPhone
2. Navigate to any webpage (e.g., `https://github.com`)
3. Tap the **Share button** (square with arrow pointing up)
4. Scroll down and tap **"More"** (the three dots icon)
5. You should see **"Share to NotesApp"** or **"NotesApp"** in the list
6. **Toggle it ON** (swipe the switch to green)
7. Optionally, **drag it** to move it to a better position
8. Tap **Done**

### 3.2 Extension Should Now Appear

Now when you:
1. Tap **Share** from Safari
2. Scroll the Share Sheet
3. **NotesApp** should appear as an icon in the main Share Sheet!

---

## 🧪 Step 4: Test the Share Extension

### 4.1 Test from Safari

1. Open **Safari** on your iPhone
2. Visit any URL (e.g., `https://github.com/CopilotKit/canvas-with-mastra`)
3. Tap the **Share button**
4. Tap **"NotesApp"** icon in the Share Sheet
5. A modal should appear showing:
   - "Analyzing content..." (briefly)
   - Then a form with:
     - Title (editable)
     - Summary (editable)
     - Tags
     - "Save to Notes" button
6. Review/edit and tap **"Save to Notes"**
7. Open **NotesApp** - the new note should appear!

### 4.2 What Happens Behind the Scenes

1. Share Extension extracts the URL from Safari
2. Extracts content from the URL
3. Analyzes content using LLM (if available) or heuristics
4. Saves note to shared App Group storage
5. Main app receives notification and loads the note
6. Note appears in NotesApp!

---

## 🐛 Troubleshooting

### Extension Doesn't Appear in Share Sheet?

#### Solution 1: Check Extension is Built
1. In Xcode: `Product → Scheme → Edit Scheme`
2. Select **ShareExtension** from the left sidebar
3. Under **Build**, ensure it's checked ✅
4. Rebuild: `Product → Clean Build Folder` (⌘⇧K), then `Product → Build` (⌘B)

#### Solution 2: Reinstall App
1. Delete NotesApp from your iPhone
2. In Xcode: Clean build folder (`⌘⇧K`)
3. Rebuild and reinstall (`⌘R`)

#### Solution 3: Check Signing
1. Ensure both targets use the **same Team**
2. Ensure both have **App Groups** enabled
3. Ensure App Group ID matches: `group.com.piotrlaczkowski.NotesApp`

#### Solution 4: Check Info.plist
1. Open `ShareExtension/Info.plist`
2. Verify:
   - `NSExtensionPointIdentifier` = `com.apple.share-services`
   - `NSExtensionPrincipalClass` = `$(PRODUCT_MODULE_NAME).ShareViewController`
   - Activation rules include URL support

### Extension Appears But Doesn't Work?

#### Check App Group Configuration
1. Both targets must have **same App Group**:
   - `group.com.piotrlaczkowski.NotesApp`
2. Check in Xcode:
   - NotesApp target → Signing & Capabilities → App Groups
   - ShareExtension target → Signing & Capabilities → App Groups

#### Check Bundle Identifier
- Share Extension should be: `[MainAppBundleID].ShareExtension`
- Example: `com.piotrlaczkowski.NotesApp.ShareExtension`

### "Unable to Load" Error?

1. Check both targets are signed with the **same certificate**
2. Rebuild: Clean Build Folder → Build → Run

---

## 📝 Manual Verification Checklist

After setup, verify:

- [ ] Share Extension target exists in Xcode
- [ ] Both targets have App Groups capability enabled
- [ ] Both targets use the same Team/Apple ID
- [ ] Bundle Identifier follows pattern: `[AppID].ShareExtension`
- [ ] App builds and installs successfully
- [ ] Extension appears in Share Sheet "More" section
- [ ] Extension can be enabled and moved in Share Sheet
- [ ] Extension works when sharing URLs from Safari
- [ ] Notes created via Share Extension appear in NotesApp

---

## 🎯 Quick Enable Script

If you want to quickly test if the extension is installed:

1. In Safari, share any URL
2. Tap "More" at the bottom
3. Look for "Share to NotesApp" or "NotesApp"
4. Toggle it ON
5. Done!

---

## 📚 Additional Resources

- [Apple Share Extension Documentation](https://developer.apple.com/documentation/xcode/configuring-a-share-extension)
- [App Groups Guide](https://developer.apple.com/documentation/xcode/configuring-app-groups)

---

## ✅ Success Indicators

You know it's working when:

1. ✅ **NotesApp icon appears** in Share Sheet when sharing URLs
2. ✅ **Tapping NotesApp** opens a preview/editor
3. ✅ **"Save to Notes"** creates a note successfully
4. ✅ **Note appears** in NotesApp after sharing

---

**Happy Sharing! 🎉**

