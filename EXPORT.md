# 🚀 Build & Installation Guide for NotesApp

This guide will help you build and install **NotesApp** on your Mac and iPhone.

## 📋 Prerequisites

Before building, make sure you have:

- **Xcode 15.0+** installed from the App Store
- **macOS 13.0+** or **iOS 16.0+**
- **Apple Developer Account** (free tier works for personal use)
- **Git** (usually comes with Xcode Command Line Tools)

### Install Xcode Command Line Tools (if needed)

```bash
xcode-select --install
```

---

## 🔧 Project Setup

### 1. Clone or Navigate to Project

```bash
cd /Users/piotrlaczkowski/Desktop/NotesApp
```

### 2. Install Dependencies

The project uses Swift Package Manager (SPM), which is built into Xcode. No additional package installations needed.

### 3. Verify Project Structure

```bash
ls -la
# Should show: NotesApp.xcodeproj, Package.swift, etc.
```

---

## 🏗️ Building for Mac

### Method 1: Build via Xcode (Recommended for First-Time Users)

#### 1. Open the Project in Xcode

```bash
open NotesApp.xcodeproj
```

#### 2. Configure Build Settings

- Select **NotesApp** scheme from the top toolbar
- Select **My Mac** as the destination
- Make sure you're set to **Release** configuration (for production)

#### 3. Build the App

```bash
Product → Build (⌘B)
```

#### 4. Archive for Distribution

```bash
Product → Archive (⌘⇧B)
```

#### 5. Export for macOS App Store or Direct Installation

- In the Archives window, click **Distribute App**
- Choose **Direct Distribution**
- Follow the wizard to create an `.app` bundle

### Method 2: Build via Command Line

#### Build for Mac

```bash
xcodebuild -scheme NotesApp -configuration Release -destination 'generic/platform=macOS' build
```

#### Archive

```bash
xcodebuild -scheme NotesApp -configuration Release -destination 'generic/platform=macOS' archive \
-archivePath ~/Desktop/NotesApp.xcarchive
```

#### Export the App

```bash
xcodebuild -exportArchive -archivePath ~/Desktop/NotesApp.xcarchive \
-exportOptionsPlist ExportOptions.plist -exportPath ~/Desktop/NotesApp
```

### Running on Mac Directly

After building, run with:

```bash
open ~/Desktop/NotesApp/NotesApp.app
```

---

## 📱 Building for iPhone

### Prerequisites for iPhone Builds

1. **Apple Developer Account** (enrollment may be required)
2. **iPhone physically connected via USB** OR use **Simulator**
3. **Valid signing certificate and provisioning profile**

### Method 1: Using Xcode (Easiest)

#### 1. Set Signing & Capabilities

- Open `NotesApp.xcodeproj` in Xcode
- Select **NotesApp** target
- Go to **Signing & Capabilities** tab
- Select your **Team** from the dropdown
- Verify **Bundle Identifier** is unique (e.g., `com.piotrlaczkowski.NotesApp`)

#### 2. Select iPhone Destination

```bash
In the top toolbar: Select your iPhone or iOS Simulator
Device selector → Select your iPhone or preferred simulator
```

#### 3. Build & Run

```bash
Product → Run (⌘R)
```

The app will build and automatically install on your iPhone!

#### 4. Trust Developer Certificate (If Using Physical Device)

On your iPhone:

```bash
Settings → General → VPN & Device Management
→ Tap your Developer App Certificate
→ Tap "Trust" → Confirm
```

### Method 2: Build via Command Line

#### Build for iPhone Simulator

```bash
xcodebuild -scheme NotesApp -configuration Release \
-destination 'generic/platform=iOS Simulator,name=iPhone 15' build
```

#### Build for Physical iPhone

```bash
xcodebuild -scheme NotesApp -configuration Release \
-destination 'generic/platform=iOS,name=*' build
```

#### Archive for Distribution

```bash
xcodebuild -scheme NotesApp -configuration Release \
-destination 'generic/platform=iOS' archive \
-archivePath ~/Desktop/NotesApp.xcarchive
```

---

## 📦 Distribution Options

### Option 1: Direct Installation (Personal Use)

#### Via Xcode

1. Connect iPhone via USB
2. `Product → Run` in Xcode
3. App installs and runs immediately

#### Via Command Line

```bash
# Build and install to connected device
xcodebuild -scheme NotesApp -configuration Release \
-destination 'generic/platform=iOS' install
```

### Option 2: App Store Distribution

#### Requirements

- Enroll in Apple Developer Program ($99/year)
- Create an App ID
- Create a provisioning profile
- Set up App Store Connect account

#### Steps

1. **Create App Store listing** on App Store Connect
2. **Configure app signing** with App Store profile
3. **Archive the app**:
```bash
Product → Archive
```
4. **Upload to App Store**:
- Archives window → Select archive
- Click "Distribute App"
- Choose "App Store"
- Follow the upload wizard

### Option 3: Ad-Hoc Distribution (Limited Device List)

1. **Create Ad-Hoc provisioning profile** on Apple Developer
2. **Sign app with Ad-Hoc profile**:
```bash
xcodebuild -scheme NotesApp -configuration Release \
-exportOptionsPlist AdHocExportOptions.plist build
```
3. **Share `.ipa` file** with approved devices

---

## 🧪 Testing Before Release

### Run Tests

```bash
xcodebuild test -scheme NotesApp -destination 'generic/platform=iOS Simulator'
```

### Test on Multiple Simulators

```bash
# iPhone 14
xcodebuild test -scheme NotesApp -destination 'platform=iOS Simulator,name=iPhone 14'

# iPhone 15
xcodebuild test -scheme NotesApp -destination 'platform=iOS Simulator,name=iPhone 15'

# iPad
xcodebuild test -scheme NotesApp -destination 'platform=iOS Simulator,name=iPad Pro (11-inch)'
```

### Manual Testing Checklist

- [ ] Create a new note from URL
- [ ] Add notes to different categories
- [ ] Filter and search notes
- [ ] Edit existing notes
- [ ] Delete notes (swipe & button)
- [ ] Change theme settings
- [ ] Configure GitHub sync (optional)
- [ ] Test on light and dark modes
- [ ] Check all UI elements on different screen sizes

---

## 🐛 Troubleshooting

### Build Errors

#### "No profile matching identifier found"

```bash
# Delete derived data and try again
rm -rf ~/Library/Developer/Xcode/DerivedData/*
xcodebuild clean
xcodebuild build
```

#### "Code signing error"

1. Go to Xcode Preferences (`Cmd + ,`)
2. Accounts → Select your Apple ID
3. Click "Manage Certificates"
4. Ensure a valid "iOS Development" certificate exists
5. Download/create if needed

#### "Module NotesApp not found"

```bash
# Clean build folder
xcodebuild clean
Product → Clean Build Folder (Shift + Cmd + K)
xcodebuild build
```

### Runtime Issues

#### App crashes on launch

1. Check console for error messages: `Product → Scheme → Edit Scheme → Run → Console`
2. Ensure all required files are in the app bundle
3. Check Info.plist for correct values

#### Features not working

1. Check GitHub configuration in Settings
2. Verify internet connection
3. Check user permissions (Files, Camera, etc.)

---

## 📊 Build Configurations

### Release vs Debug

```bash
# Debug build (faster, includes debug symbols)
xcodebuild -configuration Debug build

# Release build (optimized, smaller)
xcodebuild -configuration Release build
```

### Architecture Support

```bash
# Show supported architectures
lipo -info NotesApp.app/Contents/MacOS/NotesApp

# Check iOS build
xcrun lipo -info NotesApp.app/NotesApp
```

---

## 📝 Environment Variables

Optional build environment variables:

```bash
# Increase verbosity
xcodebuild -verbose build

# Show build timing
xcodebuild -showBuildTimingSummary build

# Disable parallelization (if having issues)
xcodebuild -jobs 1 build
```

---

## 🚀 Quick Start Commands

### One-Command Mac Build & Run

```bash
xcodebuild -scheme NotesApp -configuration Release -destination 'generic/platform=macOS' build && \
open ~/Library/Developer/Xcode/DerivedData/NotesApp-*/Build/Products/Release/NotesApp.app
```

### One-Command iPhone Simulator Build & Run

```bash
xcodebuild -scheme NotesApp -configuration Release \
-destination 'platform=iOS Simulator,name=iPhone 15' build && \
open ~/Library/Developer/Xcode/DerivedData/NotesApp-*/Build/Products/Release-iphonesimulator/NotesApp.app
```

### One-Command Physical iPhone Build & Run

```bash
# Make sure iPhone is connected and unlocked
xcodebuild -scheme NotesApp -configuration Release \
-destination 'platform=iOS,name=*' install
```

---

## 📚 Additional Resources

- **Apple Developer Documentation**: https://developer.apple.com/documentation/
- **Xcode Help**: `Help → Xcode Help` in Xcode
- **Swift Package Manager**: https://www.swift.org/package-manager/
- **App Store Connect**: https://appstoreconnect.apple.com/

---

## ✅ Verification Checklist

After building, verify:

- [ ] App opens without crashing
- [ ] All UI elements render correctly
- [ ] Core features work (create, edit, delete notes)
- [ ] Theme switching works
- [ ] Search and filter functions work
- [ ] Settings persist after app restart
- [ ] No console warnings or errors
- [ ] Performance is acceptable
- [ ] Memory usage is reasonable

---

## 📞 Support

If you encounter issues:

1. Check the **Troubleshooting** section above
2. Review Xcode build logs: `Product → Scheme → Edit Scheme → Run → Console`
3. Try cleaning and rebuilding:
```bash
xcodebuild clean
rm -rf ~/Library/Developer/Xcode/DerivedData/*
xcodebuild build
```
4. Restart Xcode and your device

---

**Happy building! 🎉**

Last Updated: November 2025
Version: 1.0.0
