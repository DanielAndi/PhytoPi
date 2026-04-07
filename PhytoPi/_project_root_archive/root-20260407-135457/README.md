# PhytoPi
This project is an IoT-based controlled environment system that enables plants to grow through their entire life cycle with minimal human intervention through use of embedded hardware and software solutions.

## Project Structure

```
PhytoPi/
├── dashboard/           # Flutter Web Dashboard
├── infra/             # Infrastructure (Supabase)
│   └── supabase/
├── pi-controller/     # Raspberry Pi Controller Code
└── docs/             # Documentation
```

## Quick Start

### Dashboard (Flutter Web)
```bash
cd dashboard
flutter pub get
flutter run -d chrome --web-port 3000
```

### Infrastructure (Supabase)
```bash
cd infra/supabase
supabase start
```

## Features

- 🌱 **Real-time Plant Monitoring**: Track temperature, humidity, light, and soil conditions
- 📊 **Data Visualization**: Interactive charts and analytics
- 🔔 **Smart Alerts**: Automated notifications for plant health
- 🤖 **ML Insights**: AI-powered growth predictions
- 📱 **Responsive Design**: Works on desktop, tablet, and mobile
- 🔐 **Secure Authentication**: User management and access control

## Development Status

- ✅ **Milestone 1**: Project Setup & Architecture (Completed)
- 🚧 **Milestone 2**: UI/UX Design & Wireframing (In Progress)
- ⏳ **Milestone 3**: Authentication & User Management
- ⏳ **Milestone 4**: Core Dashboard Features
- ⏳ **Milestone 5**: Device Management
- ⏳ **Milestone 6**: Analytics & Reporting
- ⏳ **Milestone 7**: Vercel Deployment
- ⏳ **Milestone 8**: Advanced Features & Polish

