# PhytoPi Dashboard Scripts

This directory contains build and development scripts for the PhytoPi Dashboard.

## Scripts

### `run_local.sh`
Starts Supabase locally and runs the Flutter app for local development.

**Usage:**
```bash
./scripts/run_local.sh
```

**What it does:**
- Checks if Supabase is running, starts it if needed
- Retrieves Supabase URL and anon key
- Runs Flutter app with local configuration
- Opens browser at http://localhost:3000

### `build_prod.sh`
Builds the Flutter app for production deployment.

**Usage:**
```bash
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_ANON_KEY=your-anon-key
./scripts/build_prod.sh
```

**What it does:**
- Validates environment variables
- Gets Flutter dependencies
- Cleans previous build
- Builds Flutter web app for production
- Outputs build to `build/web/`

### `build.sh`
Build script for Vercel deployment. Used automatically by Vercel during deployment.

**What it does:**
- Installs Flutter if not available
- Gets Flutter dependencies
- Builds Flutter web app with environment variables from Vercel
- Outputs to `build/web/` for Vercel to serve

## Environment Variables

### Local Development
- `SUPABASE_URL`: http://127.0.0.1:54321 (auto-detected)
- `SUPABASE_ANON_KEY`: Auto-detected from Supabase status

### Production
- `SUPABASE_URL`: Your production Supabase URL
- `SUPABASE_ANON_KEY`: Your production Supabase anon key

## Troubleshooting

### Scripts not executable
```bash
chmod +x scripts/*.sh
```

### Flutter not found
- Ensure Flutter is installed and in PATH
- Run `flutter doctor` to verify installation

### Supabase not running
```bash
cd ../../infra/supabase
supabase start
```

### Build fails
- Check environment variables are set
- Verify Flutter version (3.10.0+)
- Check build logs for specific errors

