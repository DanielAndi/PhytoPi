# PhytoPi Dashboard

A comprehensive Flutter web dashboard for the PhytoPi IoT plant monitoring system.

## Features

- 🌱 Real-time plant monitoring
- 📊 Data visualization and analytics
- 🔔 Smart alerts and notifications
- 🤖 ML-powered insights
- 📱 Responsive web design
- 🔐 Secure authentication

## Getting Started

### Prerequisites

- Flutter SDK (3.10.0 or higher)
- Dart SDK (3.0.0 or higher)
- Supabase CLI (for local development)
- Docker (for local Supabase)
- Vercel account (for deployment)

### Quick Start

**Local Development:**
```bash
# Start Supabase locally
cd infra/supabase
supabase start

# Run dashboard (from dashboard directory)
cd dashboard
./scripts/run_local.sh
```

**Production Deployment:**
See [QUICKSTART.md](./QUICKSTART.md) for detailed deployment instructions.

### Installation

1. **Install Flutter dependencies:**
   ```bash
   cd dashboard
   flutter pub get
   ```

2. **Configure environment variables:**
   See [env.example](./env.example) for environment variable template.
   
   For local development, the script automatically detects Supabase configuration.
   For production, set environment variables in Vercel dashboard.

3. **Run the development server:**
   ```bash
   ./scripts/run_local.sh
   ```
   
   Or manually:
   ```bash
   flutter run -d chrome --web-port 3000 \
     --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
     --dart-define=SUPABASE_ANON_KEY=<your-local-anon-key>
   ```

### Project Structure

```
lib/
├── core/
│   ├── config/          # App configuration
│   ├── constants/        # App constants
│   └── utils/           # Utility functions
├── features/
│   ├── auth/            # Authentication
│   ├── dashboard/       # Main dashboard
│   ├── devices/         # Device management
│   └── analytics/       # Analytics and reports
├── shared/
│   ├── widgets/        # Reusable widgets
│   └── services/        # API services
└── main.dart
```

## Development

### Running Tests
```bash
flutter test
```

### Building for Production
```bash
# Set environment variables
export SUPABASE_URL=https://your-project.supabase.co
export SUPABASE_ANON_KEY=your-anon-key

# Build
./scripts/build_prod.sh
```

Or use the Vercel build script:
```bash
./scripts/build.sh
```

### Code Quality
```bash
flutter analyze
dart format .
```

## Deployment

This project is configured for deployment on Vercel.

### Quick Deploy

1. **Using Vercel CLI:**
   ```bash
   cd dashboard
   vercel env add SUPABASE_URL production
   vercel env add SUPABASE_ANON_KEY production
   vercel --prod
   ```

2. **Using Vercel Dashboard:**
   - Import repository
   - Set root directory to `dashboard`
   - Add environment variables
   - Deploy

### Documentation

- **[QUICKSTART.md](./QUICKSTART.md)** - Quick start guide for local and production
- **[DEPLOYMENT.md](./DEPLOYMENT.md)** - Detailed deployment guide
- **[scripts/README.md](./scripts/README.md)** - Scripts documentation

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and linting
5. Submit a pull request

## License

This project is part of the PhytoPi IoT system. See the main project LICENSE for details.

