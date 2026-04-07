# Android Testing Setup - Quick Start Guide

## ✅ Current Status

### What's Already Set Up

1. **✅ Android Platform Added**: Flutter Android platform support has been added to the project
2. **✅ Device Connected**: Your `motorola one 5G ace` (Android 11, API 30) is connected and detected
3. **✅ Environment Configured**: `.env.local` is set up with:
   - `SUPABASE_URL=http://192.168.0.107:54321`
   - `SUPABASE_ANON_KEY=sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH`
4. **✅ Supabase Running**: Local Supabase instance is running
5. **✅ AndroidManifest Updated**: Internet permissions and cleartext traffic enabled

### What Needs Attention

1. **⚠️ Android cmdline-tools**: Missing (optional, but recommended for building)
2. **⚠️ Java Version**: Java 25 detected (Flutter uses Java 11 by default, but should work)

---

## 🚀 Quick Start - Test on Your Phone

### Step 1: Verify Everything is Ready

```bash
cd /home/danielg/Documents/PhytoPi/dashboard

# Check Flutter setup
flutter doctor -v

# Check connected devices
adb devices

# Verify environment
export PLATFORM=android
source scripts/utils/load_env.sh
echo "SUPABASE_URL: $SUPABASE_URL"
echo "SUPABASE_ANON_KEY: ${SUPABASE_ANON_KEY:0:30}..."
```

### Step 2: Run the App on Your Phone

**Option A: Using the Test Script (Recommended)**
```bash
cd /home/danielg/Documents/PhytoPi/dashboard
./scripts/dev/test_android.sh
```

**Option B: Manual Run**
```bash
cd /home/danielg/Documents/PhytoPi/dashboard

# Load environment
export PLATFORM=android
source scripts/utils/load_env.sh

# Run the app
flutter run -d android
```

### Step 3: Verify the App Works

1. The app should launch on your phone
2. Check the console for any errors
3. The app should connect to your local Supabase instance
4. Test the app's features

---

## 📱 Testing on Android Emulator (Optional)

### Option 1: Using Android Studio (Recommended)

1. **Install Android Studio**:
   ```bash
   yay -S android-studio
   ```

2. **Set Up Android Studio**:
   - Open Android Studio
   - Go to **Tools** → **SDK Manager**
   - Install **Android SDK Platform** (API 30 or higher)
   - Install **Android SDK Build-Tools**
   - Install **Android Emulator**

3. **Create an Android Virtual Device (AVD)**:
   - Go to **Tools** → **Device Manager**
   - Click **Create Device**
   - Select a device (e.g., Pixel 5)
   - Select a system image (e.g., Android 13 - API 33)
   - Click **Finish**

4. **Start the Emulator**:
   - Click the **Play** button next to your AVD
   - Wait for the emulator to start

5. **Run the App**:
   ```bash
   cd /home/danielg/Documents/PhytoPi/dashboard
   export PLATFORM=android
   source scripts/utils/load_env.sh
   flutter run -d android
   ```

**Note**: For emulator testing, you may need to update `.env.local` to use `10.0.2.2` instead of your local IP:
```bash
SUPABASE_URL=http://10.0.2.2:54321
```

### Option 2: Using Flutter's Emulator Commands

```bash
# List available emulators
flutter emulators

# Launch an emulator
flutter emulators --launch <emulator_id>

# Run the app
flutter run -d <emulator_id>
```

---

## 🔧 Troubleshooting

### Issue: App Can't Connect to Supabase

**Check**:
1. ✅ Supabase is running: `cd infra/supabase && supabase status`
2. ✅ Phone and computer are on the same Wi-Fi network
3. ✅ Firewall allows port 54321
4. ✅ `.env.local` has the correct IP address (your computer's IP, not `localhost`)

**Test Connection**:
```bash
# From your phone's browser, try accessing:
# http://192.168.0.107:54321
# You should see Supabase API response
```

### Issue: Build Fails with Gradle Error

**Solution**:
```bash
cd /home/danielg/Documents/PhytoPi/dashboard/android

# Clean build
./gradlew clean

# Try building again
cd ..
flutter build apk --release
```

### Issue: Device Not Detected

**Solution**:
```bash
# Restart ADB server
adb kill-server
adb start-server
adb devices

# Check USB connection
# Try a different USB cable
# Try a different USB port
```

### Issue: Missing Android cmdline-tools

**Note**: This is optional. Flutter can build without cmdline-tools if the SDK is set up correctly. However, if you want to install it:

```bash
# Install Android SDK command-line tools
sudo pacman -S android-sdk android-sdk-build-tools android-sdk-platform-tools

# Set environment variables
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk
export PATH=$PATH:$ANDROID_HOME/tools/bin

# Accept licenses
yes | flutter doctor --android-licenses
```

---

## 📦 Building APK for Manual Installation

### Build Release APK

```bash
cd /home/danielg/Documents/PhytoPi/dashboard

# Build APK
./scripts/build/build_mobile_android.sh apk

# The APK will be at:
# build/app/outputs/flutter-apk/app-release.apk
```

### Install APK on Device

**Option 1: Using ADB**
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

**Option 2: Manual Transfer**
1. Copy `app-release.apk` to your phone
2. On your phone, enable **Install from Unknown Sources**
3. Open the APK file on your phone
4. Install the app

---

## 📚 Documentation

For more detailed information, see:
- [Android Testing Guide](docs/platform/ANDROID_TESTING_GUIDE.md) - Comprehensive testing guide
- [Android Setup Guide](docs/platform/ANDROID_SETUP.md) - Detailed setup instructions
- [Environment Configuration](docs/configuration/ENV_WORKFLOW.md) - Environment setup guide

---

## 🎯 Next Steps

1. ✅ **Android platform added** to Flutter project
2. ✅ **Environment configured** for Android testing
3. ✅ **Device connected** and detected
4. ⏳ **Test the app** on your device
5. ⏳ **Test the app** on emulator (optional)
6. ⏳ **Build release APK** for distribution

---

## 📝 Quick Reference

### Essential Commands

```bash
# Check Flutter setup
flutter doctor -v

# Check connected devices
adb devices

# List Flutter devices
flutter devices

# Run app on Android
cd /home/danielg/Documents/PhytoPi/dashboard
export PLATFORM=android
source scripts/utils/load_env.sh
flutter run -d android

# Build APK
./scripts/build/build_mobile_android.sh apk

# Install APK
adb install build/app/outputs/flutter-apk/app-release.apk
```

### File Locations

- **Environment config**: `/home/danielg/Documents/PhytoPi/dashboard/.env.local`
- **APK output**: `/home/danielg/Documents/PhytoPi/dashboard/build/app/outputs/flutter-apk/app-release.apk`
- **Android config**: `/home/danielg/Documents/PhytoPi/dashboard/android/`
- **Supabase config**: `/home/danielg/Documents/PhytoPi/infra/supabase/`

---

**Last Updated**: 2025-01-21
**Flutter Version**: 3.35.7
**Android SDK**: /opt/android-sdk
**Device**: motorola one 5G ace (Android 11, API 30)

