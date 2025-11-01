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

1. **Apple Developer Account** (free tier works - use your Apple ID)
2. **iPhone on same WiFi network as Mac** (after initial USB setup) OR **USB cable** (for first-time setup)
3. **Valid signing certificate** (Xcode will create this automatically)

### ⚠️ **Can I Use AirDrop?**

**Unfortunately, no.** AirDrop cannot directly install iOS apps because:
- iOS apps must be **code-signed** and installed through Apple's secure installation system
- iOS security prevents installing apps from random sources (even via AirDrop)
- Apps need to be built and signed by Xcode or distributed through official channels (App Store, TestFlight)

**However, there are better wireless options!** See **Method 2: Wireless Installation** below.

### 🚀 **Quick Guide: Which Method Should I Use?**

| Method | When to Use | Requirements |
|--------|-------------|--------------|
| **Method 1: USB** | First-time setup only | USB cable, iPhone nearby |
| **Method 2: Wireless** ⭐ | **Easiest for daily use!** | One-time USB setup, then just WiFi |
| **Method 3: Simulator** | Quick testing | No iPhone needed |
| **TestFlight** | Install from anywhere | $99/year Developer account |

---

## 🔌 **STEP-BY-STEP: Transfer App to Physical iPhone**

### **Method 1: USB Cable Connection (First-Time Setup Only)**

> ⚡ **Pro Tip:** You only need USB for the **first installation**. After that, use **Method 2 (Wireless)** - it's much easier!

#### Step 1: Connect Your iPhone to Mac

1. **Use a USB cable** (Lightning or USB-C depending on your iPhone)
2. **Plug one end into your iPhone**, the other into your **Mac**
3. **Unlock your iPhone** - you may see a prompt asking "Trust This Computer?"
4. **Tap "Trust"** on your iPhone
5. **Enter your iPhone passcode** if prompted

#### Step 2: Trust Your Computer on iPhone

If you see "Trust This Computer?":
- Tap **"Trust"**
- Enter your **iPhone passcode**

#### Step 3: Open Xcode

```bash
cd /Users/piotrlaczkowski/Desktop/NotesApp
open NotesApp.xcodeproj
```

#### Step 4: Configure Signing in Xcode

1. In Xcode, click on **"NotesApp"** in the left sidebar (blue project icon at the top)
2. Select the **"NotesApp"** target (under TARGETS)
3. Click the **"Signing & Capabilities"** tab
4. Check ✅ **"Automatically manage signing"**
5. In the **"Team"** dropdown, select **your Apple ID** (or your Developer Team)
6. If you see a warning about Bundle Identifier, Xcode will automatically fix it
7. Xcode will show: ✅ **"Signing Certificate"** - this means it's ready!

#### Step 5: Select Your iPhone as Destination

1. **Look at the top toolbar** in Xcode (near the Play/Stop buttons)
2. You'll see a device selector (usually shows "Any iOS Device" or a simulator name)
3. **Click the device selector dropdown**
4. Under **"iOS Device"**, you should see **your iPhone name** (e.g., "Piotr's iPhone")
5. **Select your iPhone**

⚠️ **If your iPhone doesn't appear:**
- Make sure iPhone is **unlocked**
- Make sure iPhone shows **"Trusted"** 
- Try **unplugging and replugging** the USB cable
- In Xcode: `Window → Devices and Simulators` → Check if iPhone appears there

#### Step 6: Build and Install to iPhone

1. **Press `⌘R`** (Command + R) OR click the **▶️ Play button** in Xcode
2. Xcode will:
   - ✅ Build the app
   - ✅ Install it on your iPhone
   - ✅ Launch it automatically

🎉 **The app should now appear on your iPhone!**

#### Step 7: Trust Developer Certificate on iPhone (First Time Only)

When you try to open the app on your iPhone for the first time, you'll see:

```
"Untrusted Developer"
```

**To fix this:**

1. On your iPhone, go to: **Settings → General → VPN & Device Management**
   (On older iOS: Settings → General → Device Management or Profiles & Device Management)
2. Tap on your **developer certificate** (should show your Apple ID email)
3. Tap **"Trust [Your Apple ID]"**
4. Tap **"Trust"** in the confirmation popup
5. **Go back and open NotesApp** - it should work now!

---

### **Method 2: Wireless Installation (No USB After First Setup!) ⚡ EASIEST**

> 🎉 **This is the easiest way!** After the initial USB connection, you never need a cable again - just build and run from Xcode wirelessly!

#### Prerequisites

- ✅ You've already installed the app once via USB (Method 1, Steps 1-7)
- ✅ Your iPhone and Mac are on the **same WiFi network**
- ✅ iPhone is unlocked

#### Step 1: Enable Wireless Debugging (One-Time Setup)

1. **Connect iPhone via USB** (just this once to set it up)
2. **Unlock your iPhone**
3. In Xcode, open: `Window → Devices and Simulators` (⌘⇧2)
4. **Select your iPhone** in the left sidebar
5. Check ✅ **"Connect via network"** checkbox
6. Wait a few seconds - you'll see a **network icon** 🌐 appear next to your iPhone name
7. **Unplug the USB cable** - your iPhone should still appear in Xcode!

🎉 **Wireless connection is now active!**

#### Step 2: Build & Install Wirelessly

Now you can install apps **without any cable**:

1. **Open the project** in Xcode:
   ```bash
   open NotesApp.xcodeproj
   ```

2. **Select your iPhone** in the device selector (top toolbar)
   - You'll see a 🌐 icon next to it, indicating wireless connection

3. **Press `⌘R`** (or click ▶️ Play button)
   - Xcode will build, install, and launch the app **wirelessly**!

4. Your iPhone doesn't need to be physically connected - just make sure:
   - Both devices are on the same WiFi
   - iPhone is unlocked
   - Xcode can "see" your iPhone in the device list

#### Troubleshooting Wireless Connection

**iPhone disappeared after unplugging?**
- Make sure both devices are on the same WiFi network
- Try reconnecting via USB briefly, then check "Connect via network" again
- In Xcode: `Window → Devices and Simulators` → Select iPhone → Uncheck and re-check "Connect via network"

**Build fails with "Unable to connect to device"?**
- Make sure iPhone is unlocked
- Check WiFi is active on both devices
- Restart Xcode and try again

**Can't see "Connect via network" option?**
- Make sure iPhone is unlocked and trusted
- Try disconnecting and reconnecting USB
- Update Xcode to the latest version

---

### **Method 3: iOS Simulator (No Physical Device Needed)**

If you don't have your iPhone nearby or want to test quickly:

#### Step 1: Open Xcode

```bash
open NotesApp.xcodeproj
```

#### Step 2: Select Simulator

1. In the **device selector** (top toolbar)
2. Choose any **iPhone Simulator** (e.g., "iPhone 15", "iPhone 14 Pro")
3. If you don't have simulators, Xcode will download them automatically

#### Step 3: Build & Run

Press **`⌘R`** - the simulator will open and your app will run!

**Note:** Simulator apps don't transfer to your physical iPhone. Use Method 1 (USB) or Method 2 (Wireless) for that.

---

## 🔍 **Troubleshooting: iPhone Connection Issues**

### iPhone Not Appearing in Xcode?

1. **Check USB cable** - try a different cable
2. **Unlock iPhone** - must be unlocked to appear
3. **Trust the computer** - Settings → General → About → Trust
4. **Restart Xcode** - Quit and reopen Xcode
5. **Restart iPhone** - Power off and on
6. **Check Xcode Devices window**: `Window → Devices and Simulators` (⌘⇧2)

### "Unable to install NotesApp" Error?

1. **Check storage** - iPhone might be full
2. **Check signing** - Go to Signing & Capabilities, ensure Team is selected
3. **Clean build**: `Product → Clean Build Folder` (⌘⇧K)
4. **Restart Xcode**

### "Untrusted Developer" Error?

1. Go to iPhone: **Settings → General → VPN & Device Management**
2. Tap your developer certificate
3. Tap **"Trust"**

### iPhone Keeps Disconnecting?

1. Check USB port - try a different port
2. Use original Apple cable if possible
3. Disable "USB Restricted Mode" in iPhone Settings → Face ID & Passcode

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

### Option 2: TestFlight Distribution (Easiest Remote Option) ⚡

**This is like having your own private App Store!** Install the app on your iPhone from anywhere, no Mac required after initial setup.

#### Requirements

- **Apple Developer Account** (free tier works, but TestFlight requires **$99/year** paid enrollment)
- iPhone with TestFlight app installed (free from App Store)

#### Steps

1. **Enroll in Apple Developer Program** ($99/year) at [developer.apple.com](https://developer.apple.com)

2. **Create App ID** on App Store Connect:
   - Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
   - Create a new app listing
   - Fill in basic info (can be a draft)

3. **Archive the app in Xcode**:
   ```bash
   Product → Archive
   ```

4. **Upload to TestFlight**:
   - In Archives window, select your archive
   - Click **"Distribute App"**
   - Choose **"TestFlight & App Store"**
   - Follow the upload wizard
   - Wait for processing (usually 10-30 minutes)

5. **Install TestFlight on iPhone**:
   - Download **TestFlight** app from App Store (free)

6. **Add yourself as a tester**:
   - In App Store Connect → TestFlight → Internal Testing
   - Add your Apple ID email as an internal tester

7. **Install on iPhone**:
   - Open TestFlight app on iPhone
   - Your app will appear
   - Tap **"Install"** - done! 🎉

**Benefits:**
- ✅ Install from anywhere (no Mac needed after upload)
- ✅ Works like App Store installation
- ✅ Easy to share with friends/family
- ✅ Automatic updates when you upload new builds

**Limitations:**
- Requires paid Developer account ($99/year)
- Apps expire after 90 days (re-upload to renew)
- Takes 10-30 minutes to process after upload

---

### Option 3: App Store Distribution

#### Requirements

- Enroll in Apple Developer Program ($99/year)
- Create an App ID
- Create a provisioning profile
- Set up App Store Connect account
- App Review process (can take days/weeks)

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
5. **Submit for Review** (public distribution)

---

### Option 4: Ad-Hoc Distribution (Limited Device List)

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
