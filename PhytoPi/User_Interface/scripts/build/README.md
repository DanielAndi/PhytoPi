# Build Scripts

This directory contains build scripts for different platforms and deployment targets.

## Scripts

### `build_web.sh`
Builds the Flutter app for web deployment.

**Usage:**
```bash
./scripts/build/build_web.sh
```

**Output:** `build/web/`

### `build_mobile_android.sh`
Builds the Flutter app for Android mobile devices.

**Usage:**
```bash
./scripts/build/build_mobile_android.sh [apk|appbundle]
```

**Options:**
- `apk` (default): Builds an APK file for direct installation
- `appbundle`: Builds an App Bundle for Google Play Store

**Output:** `build/app/outputs/`

### `build_mobile_ios.sh`
Builds the Flutter app for iOS mobile devices.

**Usage:**
```bash
./scripts/build/build_mobile_ios.sh
```

**Note:** iOS builds can only be performed on macOS with Xcode installed.

**Output:** `build/ios/iphoneos/`

### `build_kiosk.sh`
Builds the Flutter app for kiosk mode (Linux/Raspberry Pi).

**Usage:**
```bash
./scripts/build/build_kiosk.sh
```

**Output:** `build/linux/x64/release/bundle/`

### `build_prod.sh`
Builds the Flutter app for production deployment (web).

**Usage:**
```bash
./scripts/build/build_prod.sh
```

**Output:** `build/web/`

### `build.sh`
Build script for Vercel deployment. Used automatically by Vercel during deployment.

**Usage:** Automatically called by Vercel

**Output:** `build/web/`

## Environment Variables

All build scripts automatically load environment variables from `.env` files. See [../README.md](../README.md) for details.

## See Also

- [../README.md](../README.md) - Scripts documentation
- [../../docs/deployment/](../../docs/deployment/) - Deployment guides
- [../../docs/platform/](../../docs/platform/) - Platform-specific guides

