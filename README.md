# PhytoPi

An intelligent IoT-based plant monitoring and control system. PhytoPi combines a Raspberry Pi sensor controller with a Flutter kiosk dashboard and a Supabase cloud backend to automate plant cultivation with minimal human intervention.

---

## Quick Reference — Pi Commands

### Docker stack

```bash
# Start all services
cd /home/phytopi/PhytoPi
docker compose -f docker-compose.rpi.yml up -d

# Stop all services
docker compose -f docker-compose.rpi.yml down

# Restart a single service  (sensors | camera | ai | updater)
docker compose -f docker-compose.rpi.yml restart sensors

# View status of all containers
docker compose -f docker-compose.rpi.yml ps

# Live logs (line-buffered, real-time)
docker logs phytopi-sensors -f
docker logs phytopi-camera  -f
docker logs phytopi-ai      -f

# Resource usage
docker stats
```

### Kiosk UI (Flutter — runs natively via systemd)

```bash
sudo systemctl start   phytopi-ui.service
sudo systemctl stop    phytopi-ui.service
sudo systemctl restart phytopi-ui.service
sudo systemctl status  phytopi-ui.service

# Rebuild the Flutter bundle after UI source changes
cd /home/phytopi/PhytoPi/User_Interface
/home/phytopi/flutter/bin/flutter build linux --release \
  --dart-define=KIOSK_MODE=true \
  --dart-define=SUPABASE_URL="${SUPABASE_URL}" \
  --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY}"
# systemd auto-restarts the app once the binary changes
```

### Boot persistence (run once on first setup)

```bash
# Auto-start Docker stack on boot
sudo ln -s /home/phytopi/PhytoPi /opt/phyto
sudo cp systemd/docker-compose-phytopi.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now docker-compose-phytopi.service

# Auto-start kiosk UI on boot
sudo cp systemd/phytopi-ui.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now phytopi-ui.service
```

### Manual update (normally done automatically by CI)

```bash
cd /home/phytopi/PhytoPi
bash scripts/update.sh
```

### Rebuild a service after Dockerfile changes

```bash
docker compose -f docker-compose.rpi.yml build --no-cache sensors
docker compose -f docker-compose.rpi.yml up -d sensors
```

---

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

The controller runs as a Docker container (`phytopi-sensors`). It is built automatically inside the container using Ubuntu 24.04 + libgpiod 2.x compiled from source — no manual dependency installation is needed on the host.

1. **Copy `.env` to the project root** with your Supabase credentials and device/sensor IDs (see `.env` for the full list of required variables).

2. **Start the stack** (see Quick Reference above).

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
