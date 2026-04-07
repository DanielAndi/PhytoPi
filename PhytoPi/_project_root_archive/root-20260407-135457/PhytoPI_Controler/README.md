# PhytoPi
This project is an IoT-based controlled environment system that enables plants to grow through their entire life cycle with minimal human intervention through use of embedded hardware and software solutions.

## Dependencies

- `libgpiod` - GPIO interface library
- `libsqlite3` - SQLite database
- `libcurl` - HTTP client library (for Supabase sync)
- `libjson-c` - JSON parsing library (for Supabase sync)

Install on Arch Linux:
```bash
sudo pacman -S libgpiod sqlite curl json-c
```

## Sensor connections (ADS7830 / ADS7030)

Wiring and code are aligned as follows. Connect sensors to the ADC and Pi as in this table:

| Sensor / signal   | ADC channel | Connection (schematic)                                      | Code variable   | Pi / bus      |
|-------------------|------------|-------------------------------------------------------------|-----------------|---------------|
| **Light (LDR03)** | **CH0**    | LDR03+R2 voltage divider → Soil_Moisture connector **'S'** → CH0 | `light_level`   | I2C (SDA1/SCL1) |
| **Soil moisture** | **CH1**    | Soil moisture probe signal → CH1                           | `soil_moisture` | I2C (SDA1/SCL1) |
| **Water level**   | **CH2**    | Water level sensor signal → CH2                             | `water_level`   | I2C (SDA1/SCL1) |
| **DHT11** (temp/humidity) | —   | Direct to GPIO (no ADC)                                     | `temperature`, `humidity` | GPIO 21   |

- **ADC (U2):** VDD → 3.3 V, GND → GND, SDA → SDA1 (J1), SCL → SCL1 (J1). A0, A1 to GND set I2C address (e.g. 0x48 for ADS7030; code uses 0x4b for ADS7830—change in `lib/gpio.h` if needed).

### Light sensor (LDR) cabling — do not connect A0 to VCC

The ADC measures **voltage**. A0 must see a voltage that **changes with light**. If A0 is wired straight to 3.3 V (VCC), the reading is always max and does not change.

**Correct setup (voltage divider):**

1. **Remove** any wire that goes from **A0 directly to VCC**. That forces a constant high reading.
2. Build a **voltage divider** with the LDR and a fixed resistor (e.g. 10 kΩ):
   - **LDR (e.g. LDR03):** one leg → **3.3 V (VCC)**; other leg → **middle node** (the “signal”).
   - **R2 (fixed resistor, e.g. 10 kΩ):** one leg → **middle node**; other leg → **GND**.
3. **A0** → connect **only** to the **middle node** (where LDR and R2 meet). That node’s voltage goes up in light and down in dark; A0 reads that.

```
    3.3 V (VCC) ---- LDR ----+---- R2 ---- GND
                             |
                            A0 (ADC input)
```

- In **light:** LDR resistance is low → middle node voltage is higher → higher ADC value.
- In **dark:** LDR resistance is high → middle node voltage is lower → lower ADC value.

**Summary:** A0 = middle of the LDR–R2 divider only. Do **not** connect A0 to VCC or GND.

## Execution

Run 'make clean' first for a fresh compilation.
Run 'make' to build all the files required for execution.
Run 'sudo ./bin/phytopi' to run the generated executable.

## Supabase Integration

The application supports batch syncing sensor data to Supabase. Data is stored locally in SQLite first, then periodically synced to Supabase in batches.

### Configuration

Set the following environment variables to enable Supabase sync:

```bash
export SUPABASE_URL="http://127.0.0.1:54321"  # or your remote Supabase URL
export SUPABASE_ANON_KEY="your-anon-key-here"
export SUPABASE_DEVICE_ID="your-device-uuid"  # Optional
export SUPABASE_HUMIDITY_SENSOR_ID="sensor-uuid"
export SUPABASE_TEMPERATURE_SENSOR_ID="sensor-uuid"
export SUPABASE_SOIL_MOISTURE_SENSOR_ID="sensor-uuid"
export SUPABASE_WATER_LEVEL_SENSOR_ID="sensor-uuid"
```

### Setup Steps

1. **Create device and sensors in Supabase:**
   - Insert a device record in the `devices` table
   - Insert sensor records in the `sensors` table for each sensor type (humidity, temperature, soil_moisture, water_level)
   - Note the UUIDs for each sensor

2. **Set environment variables** with the sensor UUIDs

3. **Run the application** - it will automatically sync data every 60 seconds

### Local Storage

Data is always stored locally in `sensor_data.db` (SQLite) first, ensuring data persistence even if Supabase is unavailable. The sync process marks records as synced after successful upload, so failed syncs will be retried on the next sync cycle.

## Camera Streaming

To visualize the camera input (Arducam 5MP/OV5647) from a remote computer:

1. **Enable the camera interface** on the Pi (usually enabled by default on modern OS with `camera_auto_detect=1` in `/boot/config.txt`).
2. **Run the streaming script**:
   ```bash
   ./scripts/stream_camera.sh
   ```
3. **View the stream on your computer** using VLC Media Player:
   - Open VLC
   - Go to **Media** -> **Open Network Stream**
   - Enter `tcp/h264://<PI_IP>:8888` (replace `<PI_IP>` with your Pi's IP address)
