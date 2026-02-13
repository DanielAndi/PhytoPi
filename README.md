# PhytoPi
<<<<<<< HEAD
This project is an IoT-based controlled environment system that enables plants to grow through their entire life cycle with minimal human intervention through use of embedded hardware and software solutions.

[Execution]
Run 'make clean' first for a fresh compilation.
Run 'make' to build all the files required for execution.
Run 'sudo .bin/phytopi' to run the generated executable.
=======

An intelligent IoT-based plant monitoring and control system that enables automated plant cultivation through embedded hardware and software solutions. PhytoPi monitors environmental conditions, manages resources, and provides real-time insights to help plants thrive with minimal human intervention.

## Overview

PhytoPi combines a Raspberry Pi-based sensor controller with a modern Flutter dashboard to create a complete plant monitoring ecosystem. The system tracks temperature, humidity, soil moisture, and water levels, while providing real-time data visualization, automated alerts, and AI-powered insights through a responsive web and mobile interface.

## Project Structure

```
PhytoPi/
├── User_Interface/          # Flutter Dashboard (Web, Mobile, Kiosk)
├── PhytoPI_Controler/       # Raspberry Pi Controller (C)
├── Data_Infraestructure/    # Supabase Database & Backend
│   └── supabase/
└── Documentation/           # Project Documentation
```

## Components

### User Interface (Flutter Dashboard)
A cross-platform Flutter application that provides:
- Real-time sensor data visualization
- Interactive charts and analytics
- Device management and monitoring
- Camera streaming for visual plant observation
- AI-powered health insights
- Responsive design for web, mobile, and kiosk deployments

### Raspberry Pi Controller
Embedded C application running on Raspberry Pi that:
- Interfaces with sensors via GPIO
- Collects environmental data (temperature, humidity, soil moisture, water level)
- Stores data locally in SQLite
- Syncs data to Supabase backend
- Manages camera streaming for remote monitoring

### Data Infrastructure (Supabase)
PostgreSQL-based backend that provides:
- Secure data storage and management
- Real-time data synchronization
- User authentication and authorization
- Device onboarding and management
- Row-level security policies

## Quick Start

### Prerequisites

- **For Dashboard**: Flutter SDK (3.12.0 or higher), Dart SDK (3.0.0 or higher)
- **For Controller**: Raspberry Pi with libgpiod, SQLite, curl, and json-c libraries
- **For Infrastructure**: Docker and Supabase CLI (for local development)

### Dashboard Setup

1. **Navigate to the User Interface directory:**
   ```bash
   cd User_Interface
   ```

2. **Install Flutter dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure environment variables:**
   ```bash
   ./scripts/utils/setup_env.sh web
   ```
   See `User_Interface/docs/configuration/ENV_SETUP.md` for detailed configuration.

4. **Run the development server:**
   ```bash
   ./scripts/dev/run_local.sh
   ```
   Or manually:
   ```bash
   flutter run -d chrome --web-port 3000
   ```

### Infrastructure Setup (Supabase)

1. **Navigate to the Supabase directory:**
   ```bash
   cd Data_Infraestructure/supabase
   ```

2. **Start Supabase locally:**
   ```bash
   supabase start
   ```

3. **Apply migrations:**
   ```bash
   supabase db reset
   ```

For detailed setup instructions, see `Data_Infraestructure/supabase/LOCAL_DEVELOPMENT.md`.

### Raspberry Pi Controller Setup

1. **Navigate to the controller directory:**
   ```bash
   cd PhytoPI_Controler
   ```

2. **Install dependencies (Arch Linux):**
   ```bash
   sudo pacman -S libgpiod sqlite curl json-c
   ```

3. **Build the application:**
   ```bash
   make clean
   make
   ```

4. **Configure environment variables:**
   ```bash
   export SUPABASE_URL="http://127.0.0.1:54321"
   export SUPABASE_ANON_KEY="your-anon-key-here"
   export SUPABASE_DEVICE_ID="your-device-uuid"
   # ... additional sensor IDs
   ```

5. **Run the controller:**
   ```bash
   sudo ./bin/phytopi
   ```

For detailed controller setup, see `PhytoPI_Controler/README.md`.

## Features

- **Real-time Monitoring**: Track temperature, humidity, soil moisture, and water levels with live updates
- **Data Visualization**: Interactive charts and graphs for historical data analysis
- **Smart Alerts**: Automated notifications for plant health conditions and system status
- **AI Insights**: Machine learning-powered growth predictions and health assessments
- **Multi-Platform Support**: Web dashboard, mobile apps (iOS/Android), and kiosk mode for Raspberry Pi
- **Camera Streaming**: Live video feed from connected camera for visual plant monitoring
- **Secure Authentication**: User management with role-based access control
- **Device Management**: Easy onboarding and configuration of multiple PhytoPi devices

## Documentation

Comprehensive documentation is available in each component directory:

- **User Interface**: See `User_Interface/docs/` for platform guides, deployment instructions, and configuration
- **Controller**: See `PhytoPI_Controler/README.md` and `PhytoPI_Controler/TESTING_GUIDE.md`
- **Infrastructure**: See `Data_Infraestructure/supabase/` for database schema, migrations, and setup guides

## Development

This project is actively being developed. Key areas of focus include:

- Enhanced sensor accuracy and calibration
- Advanced AI/ML models for plant health prediction
- Improved user experience and interface design
- Expanded device compatibility
- Performance optimizations

## License

See the [LICENSE](LICENSE) file for details.

## Contributing

This is a group project. For contributions, please coordinate with the project team.
>>>>>>> 01cb287a9e697e9da8227d833f491846421f9309
