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
- Node.js (for web development)
- Supabase account

### Installation

1. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

2. **Configure environment variables:**
   Create a `.env` file in the root directory:
   ```
   SUPABASE_URL=your_supabase_url
   SUPABASE_ANON_KEY=your_supabase_anon_key
   API_BASE_URL=your_api_base_url
   ```

3. **Run the development server:**
   ```bash
   flutter run -d chrome --web-port 3000
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
flutter build web --release
```

### Code Quality
```bash
flutter analyze
dart format .
```

## Deployment

This project is configured for deployment on Vercel. See the deployment section in the main project README for detailed instructions.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests and linting
5. Submit a pull request

## License

This project is part of the PhytoPi IoT system. See the main project LICENSE for details.
