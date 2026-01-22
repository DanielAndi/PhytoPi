# Android Emulator - Quick Start

## Quick Setup (Easiest)

### Step 1: Install Android Studio

```bash
yay -S android-studio
```

Or download from: https://developer.android.com/studio

### Step 2: Create Emulator in Android Studio

1. Open Android Studio
2. **Tools** → **Device Manager**
3. Click **Create Device**
4. Select a device (e.g., **Pixel 5**)
5. Select a system image (e.g., **Android 13 - API 33**)
6. Click **Finish**

### Step 3: Start Emulator

1. In Android Studio: Click **Play** button next to your AVD
2. Or from command line:
   ```bash
   flutter emulators --launch <emulator-name>
   ```

### Step 4: Run the App

```bash
cd /home/danielg/Documents/PhytoPi/dashboard
./scripts/dev/test_android_emulator.sh
```

## Alternative: Use Flutter to Create Emulator

```bash
# Create emulator
flutter emulators --create --name phytopi_emulator

# Start emulator
flutter emulators --launch phytopi_emulator

# Run app (wait for emulator to boot)
./scripts/dev/test_android_emulator.sh
```

## Important Notes

- **Emulator uses `10.0.2.2` for host machine**: The test script automatically configures this
- **Supabase must be running**: `cd infra/supabase && supabase start`
- **Emulator takes time to boot**: Wait 1-2 minutes for first boot

## Troubleshooting

If emulator won't start:
1. Install Android Studio
2. Install system images via Android Studio
3. Create AVD via Android Studio

For more details, see: `docs/platform/EMULATOR_SETUP.md`

