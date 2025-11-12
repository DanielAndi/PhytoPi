# Development Scripts

This directory contains development and testing scripts.

## Scripts

### `run_local.sh`
Starts Supabase locally and runs the Flutter app for local development.

**Usage:**
```bash
./scripts/dev/run_local.sh
```

**What it does:**
- Checks if Supabase is running, starts it if needed
- Retrieves Supabase URL and anon key
- Runs Flutter app with local configuration
- Opens browser at http://localhost:3000

### `test_android.sh`
Quick script to test Android setup and run the app.

**Usage:**
```bash
./scripts/dev/test_android.sh
```

**What it does:**
- Checks ADB connection
- Verifies environment variables
- Runs Flutter app on Android device

## Environment Variables

All scripts automatically load environment variables from `.env` files. See [../README.md](../README.md) for details.

## See Also

- [../README.md](../README.md) - Scripts documentation
- [../../docs/getting-started/](../../docs/getting-started/) - Getting started guides
- [../../docs/platform/](../../docs/platform/) - Platform-specific guides

