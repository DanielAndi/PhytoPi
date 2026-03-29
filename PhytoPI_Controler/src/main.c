#include "../lib/gpio.h"
#include "../lib/sql.h"
#include "../lib/supabase.h"
#include "../lib/commands.h"
#include "../lib/bme680.h"
#include <json-c/json.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <math.h>
#include <sys/wait.h>
#include <sys/stat.h>

#define SYNC_INTERVAL 5       // Sync to Supabase every 5 seconds
#define BATCH_SIZE 50         // Maximum readings per batch
#define DATA_READ_INTERVAL 2  // Read sensors every 2 seconds

// Deadband Thresholds
#define THRESH_TEMP 1         // 1 degree C
#define THRESH_HUM 2          // 2 percent
#define THRESH_SOIL 5         // 5 raw units (approx 2%)
#define THRESH_WATER 5        // 5 raw units
#define THRESH_LIGHT 10       // 10 raw units
#define THRESH_PRESSURE 2     // 2 hPa
#define THRESH_GAS 5          // 5 kOhm
#define THRESH_PHOTO_WATER 5  // 5 Hz
#define WATER_LEVEL_LOW_HZ_DEFAULT 50   // Default low-water cutoff (Hz) if threshold row has no value
/* 5-state frequency bands (Hz): 20=empty, 50=DP1, 100=DP2, 200=DP3, 400=DP4. Hysteresis 8 Hz. */
#define WATER_BAND_0_MAX 35     /* <35 Hz = Empty (0) */
#define WATER_BAND_1_MIN 27     /* 35-75 = Low (1), hysteresis: exit at 27 */
#define WATER_BAND_1_MAX 83
#define WATER_BAND_2_MIN 67
#define WATER_BAND_2_MAX 158
#define WATER_BAND_3_MIN 142
#define WATER_BAND_3_MAX 308
#define WATER_BAND_4_MIN 292    /* >300 = Full (4), hysteresis: enter at 292 */
#define WATER_ALERT_COOLDOWN 1800  // 30 min cooldown between water-low alerts
#define THRESHOLD_ALERT_COOLDOWN 900  // 15 min cooldown per metric
#define SENSOR_FAIL_ALERT_AFTER 5   // Alert after N consecutive failures
#define SENSOR_ALERT_COOLDOWN 3600 // 1 hour cooldown between sensor-fail alerts
#define FAN_MIN_DUTY_WHEN_ON 80    // Minimum duty when "on" requested (avoid 0%)

// Heartbeat
// Force a recording every X seconds even if values haven't changed
#define HEARTBEAT_INTERVAL 300 // 5 minutes

/* Dorm controller baseline behavior parity */
#define DORM_LIGHT_ON_HOURS 14
#define DORM_LIGHT_OFF_HOURS 10
#define DORM_LIGHT_ON_SECS (DORM_LIGHT_ON_HOURS * 3600)
#define DORM_LIGHT_OFF_SECS (DORM_LIGHT_OFF_HOURS * 3600)
#define DORM_SOIL_CHECK_INTERVAL 300
#define DORM_DRY_THRESHOLD 130
#define DORM_WET_THRESHOLD 95
#define DORM_PUMP_PULSE_SEC 10
#define DORM_PUMP_COOLDOWN_SEC 120
#define DORM_BME_CHECK_INTERVAL 30
#define DORM_VENT_FAN_TEMP_C 28.333f /* 83F */
#define DORM_ELEC_FAN_DUTY 100
#define DORM_VENT_FAN_DUTY 100

// Sensor ID mapping - these should match your Supabase sensors table
// Set via environment variables: SUPABASE_HUMIDITY_SENSOR_ID, etc.
static char *humidity_sensor_id = NULL;
static char *temperature_sensor_id = NULL;
static char *soil_moisture_sensor_id = NULL;
static char *water_level_sensor_id = NULL;
static char *light_level_sensor_id = NULL;
static char *pressure_sensor_id = NULL;
static char *gas_sensor_id = NULL;
static char *water_level_photoelectric_sensor_id = NULL;

/*
 * Map photoelectric frequency (Hz) to 5-state water level (0-4) with hysteresis.
 * 0=Empty, 1=Low, 2=Mid, 3=High, 4=Full
 */
static int frequency_to_water_state(int hz, int last_state)
{
    if (hz < 0) return last_state >= 0 ? last_state : 0;
    if (hz < WATER_BAND_0_MAX) return 0;
    if (hz < WATER_BAND_1_MIN) return (last_state == 0) ? 0 : 1;
    if (hz < WATER_BAND_1_MAX) return 1;
    if (hz < WATER_BAND_2_MIN) return (last_state == 1) ? 1 : 2;
    if (hz < WATER_BAND_2_MAX) return 2;
    if (hz < WATER_BAND_3_MIN) return (last_state == 2) ? 2 : 3;
    if (hz < WATER_BAND_3_MAX) return 3;
    if (hz < WATER_BAND_4_MIN) return (last_state == 3) ? 3 : 4;
    return 4;
}

/*
 * Sync unsynced readings to Supabase
 */
void sync_to_supabase(sqlite3 *db, supabase_config_t *supabase_cfg)
{
    if (!supabase_cfg || !supabase_cfg->api_url || !supabase_cfg->api_key)
    {
        return;  // Supabase not configured, skip sync
    }

    sqlite_reading_t *readings = NULL;
    int count = 0;

    // Get unsynced readings
    if (sql_get_unsynced_readings(db, &readings, &count) != 0 || count == 0)
    {
        if (readings)
            free(readings);
        return;
    }

    printf("Found %d unsynced readings, syncing to Supabase...\n", count);

    // First, count how many Supabase readings we'll need
    // temp_hum_data: 2, bme680_data: 4, others: 1 each
    int max_supabase_count = count * 4;
    
    // Convert SQLite readings to Supabase readings
    supabase_reading_t *supabase_readings = (supabase_reading_t *)malloc(max_supabase_count * sizeof(supabase_reading_t));
    if (!supabase_readings)
    {
        fprintf(stderr, "Failed to allocate memory for Supabase readings\n");
        free(readings);
        return;
    }

    int supabase_count = 0;
    for (int i = 0; i < count; i++)
    {
        // Safety check to prevent buffer overflow
        if (supabase_count >= max_supabase_count)
        {
            fprintf(stderr, "Warning: Reached maximum Supabase readings limit, some readings may be skipped\n");
            break;
        }
        
        // Map based on table name
        if (strcmp(readings[i].table_name, "temp_hum_data") == 0)
        {
            // Humidity reading
            if (humidity_sensor_id && supabase_count < max_supabase_count)
            {
                supabase_readings[supabase_count].sensor_id = humidity_sensor_id;
                supabase_readings[supabase_count].value = readings[i].value1;
                supabase_readings[supabase_count].unit = "percent";
                supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                supabase_readings[supabase_count].metadata = NULL;
                supabase_count++;

                // Temperature reading
                if (temperature_sensor_id && supabase_count < max_supabase_count)
                {
                    supabase_readings[supabase_count].sensor_id = temperature_sensor_id;
                    supabase_readings[supabase_count].value = readings[i].value2;
                    supabase_readings[supabase_count].unit = "celsius";
                    supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                    supabase_readings[supabase_count].metadata = NULL;
                    supabase_count++;
                }
            }
        }
        else if (strcmp(readings[i].table_name, "soil_moisture_data") == 0)
        {
            if (soil_moisture_sensor_id && supabase_count < max_supabase_count)
            {
                supabase_readings[supabase_count].sensor_id = soil_moisture_sensor_id;
                supabase_readings[supabase_count].value = readings[i].value1;
                supabase_readings[supabase_count].unit = "percent";
                supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                supabase_readings[supabase_count].metadata = NULL;
                supabase_count++;
            }
        }
        else if (strcmp(readings[i].table_name, "water_level_data") == 0)
        {
            if (water_level_sensor_id && supabase_count < max_supabase_count)
            {
                supabase_readings[supabase_count].sensor_id = water_level_sensor_id;
                supabase_readings[supabase_count].value = readings[i].value1;
                supabase_readings[supabase_count].unit = "raw";
                supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                supabase_readings[supabase_count].metadata = NULL;
                supabase_count++;
            }
        }
        else if (strcmp(readings[i].table_name, "light_level_data") == 0)
        {
            if (light_level_sensor_id && supabase_count < max_supabase_count)
            {
                supabase_readings[supabase_count].sensor_id = light_level_sensor_id;
                supabase_readings[supabase_count].value = readings[i].value1;
                supabase_readings[supabase_count].unit = "raw";
                supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                supabase_readings[supabase_count].metadata = NULL;
                supabase_count++;
            }
        }
        else if (strcmp(readings[i].table_name, "bme680_data") == 0)
        {
            if (temperature_sensor_id && supabase_count < max_supabase_count)
            {
                supabase_readings[supabase_count].sensor_id = temperature_sensor_id;
                supabase_readings[supabase_count].value = readings[i].value1;
                supabase_readings[supabase_count].unit = "celsius";
                supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                supabase_readings[supabase_count].metadata = NULL;
                supabase_count++;
            }
            if (humidity_sensor_id && supabase_count < max_supabase_count)
            {
                supabase_readings[supabase_count].sensor_id = humidity_sensor_id;
                supabase_readings[supabase_count].value = readings[i].value2;
                supabase_readings[supabase_count].unit = "percent";
                supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                supabase_readings[supabase_count].metadata = NULL;
                supabase_count++;
            }
            if (pressure_sensor_id && supabase_count < max_supabase_count)
            {
                supabase_readings[supabase_count].sensor_id = pressure_sensor_id;
                supabase_readings[supabase_count].value = readings[i].value3;
                supabase_readings[supabase_count].unit = "hPa";
                supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                supabase_readings[supabase_count].metadata = NULL;
                supabase_count++;
            }
            if (gas_sensor_id && supabase_count < max_supabase_count)
            {
                supabase_readings[supabase_count].sensor_id = gas_sensor_id;
                supabase_readings[supabase_count].value = readings[i].value4;
                supabase_readings[supabase_count].unit = "kOhm";
                supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                supabase_readings[supabase_count].metadata = NULL;
                supabase_count++;
            }
        }
        else if (strcmp(readings[i].table_name, "water_level_photoelectric") == 0)
        {
            if (water_level_photoelectric_sensor_id && supabase_count < max_supabase_count)
            {
                supabase_readings[supabase_count].sensor_id = water_level_photoelectric_sensor_id;
                supabase_readings[supabase_count].value = readings[i].value1; /* 0-4 state */
                supabase_readings[supabase_count].unit = "level";
                supabase_readings[supabase_count].timestamp = readings[i].timestamp;
                supabase_readings[supabase_count].metadata = NULL;
                supabase_count++;
            }
        }
    }

    if (supabase_count > 0)
    {
        // Send in batches
        int sent = 0;
        int all_sent = 1;
        
        while (sent < supabase_count)
        {
            int batch_size = (supabase_count - sent > BATCH_SIZE) ? BATCH_SIZE : (supabase_count - sent);
            
            if (supabase_send_batch(supabase_cfg, &supabase_readings[sent], batch_size) == 0)
            {
                sent += batch_size;
            }
            else
            {
                fprintf(stderr, "Failed to sync batch, will retry later\n");
                all_sent = 0;
                break;
            }
        }
        
        // Mark all readings as synced only if all were successfully sent
        if (all_sent)
        {
            for (int i = 0; i < count; i++)
            {
                sql_mark_as_synced(db, readings[i].table_name, readings[i].id);
            }
            printf("Marked %d readings as synced\n", count);
        }
    }

    free(supabase_readings);
    free(readings);
}

int main()
{
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);

    int fd = i2c_init("/dev/i2c-1"); // You need a FD to read from ADS7830 channels
    if (fd < 0)
    {
        fprintf(stderr, "Warning: I2C bus initialization failed. Soil moisture readings may not work.\n");
        fprintf(stderr, "To enable I2C: sudo raspi-config -> Interface Options -> I2C -> Enable\n");
    }

    // Variables to hold sensor data (temp/humidity from BME680, not DHT11)
    int soil_moisture = 0;
    int water_level = 0;
    // light_level removed — no analog light sensor connected

    // State variables for Deadband/Heartbeat logic
    int last_soil_moisture = -999;
    int last_water_level = -999;

    time_t last_soil_ts = 0;  // Last time soil moisture was sent
    time_t last_water_ts = 0; // Last time water level was sent

    // Initialize the database — use writable path to avoid "readonly database" errors.
    // PHYTOPI_DB_PATH overrides; else /var/lib/phytopi (systemd) or ~/.phytopi (manual run).
    const char *db_path = getenv("PHYTOPI_DB_PATH");
    if (!db_path || db_path[0] == '\0')
    {
        static char db_path_buf[1024];
        const char *home = getenv("HOME");
        if (home && home[0] != '\0')
        {
            // Use ~/.phytopi for manual runs (always writable)
            char dir[512];
            snprintf(dir, sizeof(dir), "%s/.phytopi", home);
            mkdir(dir, 0755);
            snprintf(db_path_buf, sizeof(db_path_buf), "%s/sensor_data.db", dir);
            db_path = db_path_buf;
        }
        else
        {
            db_path = "/var/lib/phytopi/sensor_data.db";
        }
    }
    sqlite3 *db = db_init(db_path);
    if (!db)
    {
        fprintf(stderr, "Failed to open %s, trying ./sensor_data.db\n", db_path);
        db = db_init("sensor_data.db");
    }
    if (!db)
    {
        fprintf(stderr, "Failed to initialize database. Try: export PHYTOPI_DB_PATH=$HOME/.phytopi/sensor_data.db\n");
        return 1;
    }

    // Initialize Supabase configuration
    supabase_config_t supabase_cfg = {0};
    supabase_cfg.api_url = getenv("SUPABASE_URL");
    supabase_cfg.api_key = getenv("SUPABASE_ANON_KEY");
    supabase_cfg.device_id = getenv("SUPABASE_DEVICE_ID");

    // Get sensor IDs from environment variables
    humidity_sensor_id = getenv("SUPABASE_HUMIDITY_SENSOR_ID");
    temperature_sensor_id = getenv("SUPABASE_TEMPERATURE_SENSOR_ID");
    soil_moisture_sensor_id = getenv("SUPABASE_SOIL_MOISTURE_SENSOR_ID");
    water_level_sensor_id = getenv("SUPABASE_WATER_LEVEL_SENSOR_ID");
    light_level_sensor_id = getenv("SUPABASE_LIGHT_SENSOR_ID");
    pressure_sensor_id = getenv("SUPABASE_PRESSURE_SENSOR_ID");
    gas_sensor_id = getenv("SUPABASE_GAS_SENSOR_ID");
    water_level_photoelectric_sensor_id = getenv("SUPABASE_WATER_LEVEL_PHOTOELECTRIC_SENSOR_ID");

    // Initialize Supabase if configured
    int supabase_enabled = 0;
    if (supabase_cfg.api_url && supabase_cfg.api_key)
    {
        if (supabase_init(&supabase_cfg) == 0)
        {
            supabase_enabled = 1;
            printf("Supabase sync enabled: %s\n", supabase_cfg.api_url);
        }
        else
        {
            fprintf(stderr, "Failed to initialize Supabase, continuing with local storage only\n");
        }
    }
    else
    {
        printf("Supabase not configured (set SUPABASE_URL and SUPABASE_ANON_KEY), using local storage only\n");
    }

    // SQL insert statements
    char sql_soil_moisture[256] = "INSERT INTO soil_moisture_data (humidity, timestamp) VALUES (?, ?);";
    char sql_water_level[256] = "INSERT INTO water_level_data (has_water, timestamp) VALUES (?, ?);";
    char sql_water_photo[256] = "INSERT INTO water_level_photoelectric (frequency_hz, timestamp) VALUES (?, ?);";

    time_t last_sync = time(NULL);
    time_t last_command_poll = time(NULL);
    time_t last_threshold_fetch = 0;
    time_t last_schedule_fetch = 0;
    time_t light_cycle_start = time(NULL);
    time_t last_soil_control_check = 0;
    time_t last_pump_pulse = 0;
    time_t last_dorm_bme_control_check = 0;
    int vent_fan_on = 0;

    /* Cached thresholds — fetched from Supabase every 60s, evaluated every loop iteration */
    device_threshold_t *cached_thresholds = NULL;
    int cached_thr_count = 0;
    time_t last_thr_alert_temp = 0, last_thr_alert_hum = 0;
    time_t last_thr_alert_gas = 0, last_thr_alert_pressure = 0;
    time_t last_thr_alert_water = 0;
    int lights_on = 0;
    time_t lights_off_at = 0;     /* Auto-off lights at this time (0 = no timeout) */
    int pump_on = 0;
    time_t pump_off_at = 0;       /* Auto-off pump at this time (0 = no timeout) */
    time_t ventilation_off_at = 0; /* Auto-off fans at this time (0 = no ventilation run) */
    time_t last_bme_read = 0;
    int iteration = 0;

    /* Sensor health: consecutive failure counts */
    int bme680_fail_count = 0;
    int photoelectric_fail_count = 0;
    static time_t last_bme_alert = 0, last_photo_alert = 0;

    // BME680 init (replaces DHT11)
    float bme_temp = -999, bme_hum = -999, bme_pressure = -999, bme_gas = -999;
    float last_bme_temp = -999, last_bme_hum = -999, last_bme_pressure = -999, last_bme_gas = -999;
    time_t last_bme_ts = 0;
    int bme680_ok = (bme680_init() == 0);

    if (!bme680_ok)
        fprintf(stderr, "Warning: BME680 init failed. Temp/humidity/pressure/gas readings disabled.\n");

    /* Initialize actuators with the same baseline behavior as dorm controller. */
    if (lights_init() == 0 && lights_set(1) == 0)
    {
        lights_on = 1;
        light_cycle_start = time(NULL);
        lights_off_at = 0;
        printf("Dorm config: Lights ON - %dh light period\n", DORM_LIGHT_ON_HOURS);
    }
    if (pump_init() != 0)
        fprintf(stderr, "Dorm config: pump_init() failed, auto-watering disabled\n");
    if (fans_init() == 0)
    {
        fans_set_speed(1, DORM_ELEC_FAN_DUTY); /* Electronics fan always on */
        fans_set_speed(2, 0);                  /* Vent fan starts off */
        printf("Dorm config: Electronics fan ON (fan1)\n");
    }

    printf("Starting sensor loop (Interval: %ds, Heartbeat: %ds)\n", DATA_READ_INTERVAL, HEARTBEAT_INTERVAL);

    while (1)
    {
        soil_moisture = (fd >= 0) ? read_pcf8591_channel(fd, 0) : -1;  /* pcf8591 Ch0 */
        water_level   = -1;  /* No legacy analog water sensor; use photoelectric (Photo Hz) */
        /* light_level: no analog light sensor connected */

        time_t now = time(NULL);

        // BME680 read (every 3s for stability)
        if (bme680_ok && (now - last_bme_read >= 3))
        {
            bme680_data_t bme_data;
            if (bme680_read(&bme_data) == 0 && bme_data.valid)
            {
                bme_temp = bme_data.temperature;
                bme_hum = bme_data.humidity;
                bme_pressure = bme_data.pressure;
                bme_gas = bme_data.gas_resistance;
                last_bme_read = now;
                bme680_fail_count = 0;
            }
            else
            {
                bme680_fail_count++;
                if (iteration % 10 == 0)
                    fprintf(stderr, "Warning: BME680 read failed (consecutive: %d)\n", bme680_fail_count);
                if (bme680_fail_count >= SENSOR_FAIL_ALERT_AFTER && supabase_enabled && supabase_cfg.device_id &&
                    (now - last_bme_alert) >= SENSOR_ALERT_COOLDOWN)
                {
                    if (supabase_insert_alert(&supabase_cfg, supabase_cfg.device_id,
                            "sensor_failure", "BME680 sensor unreachable after repeated failures",
                            "high", "automated") == 0)
                        last_bme_alert = now;
                }
            }
        }

        /* Dorm parity: temperature-based vent fan control on fan2 every 30s. */
        if (bme680_ok && bme_temp > -900 && (now - last_dorm_bme_control_check) >= DORM_BME_CHECK_INTERVAL)
        {
            last_dorm_bme_control_check = now;
            if (fans_init() == 0)
            {
                /* Keep electronics fan (fan1) always on. */
                fans_set_speed(1, DORM_ELEC_FAN_DUTY);
                if (bme_temp >= DORM_VENT_FAN_TEMP_C && !vent_fan_on)
                {
                    fans_set_speed(2, DORM_VENT_FAN_DUTY);
                    vent_fan_on = 1;
                    printf("  -> Vent fan ON (%.1fC >= %.1fC)\n", bme_temp, DORM_VENT_FAN_TEMP_C);
                }
                else if (bme_temp < DORM_VENT_FAN_TEMP_C && vent_fan_on)
                {
                    fans_set_speed(2, 0);
                    vent_fan_on = 0;
                    printf("  -> Vent fan OFF (%.1fC < %.1fC)\n", bme_temp, DORM_VENT_FAN_TEMP_C);
                }
            }
        }

        // Photoelectric water level (every 2nd iteration to avoid blocking)
        int photo_freq = -1;
        if (iteration % 2 == 0)
        {
            if (read_photoelectric_water_level(&photo_freq) != 0 || photo_freq < 0)
                photoelectric_fail_count++;
            else
                photoelectric_fail_count = 0;
        }
        if (photoelectric_fail_count >= SENSOR_FAIL_ALERT_AFTER && supabase_enabled && supabase_cfg.device_id &&
            (now - last_photo_alert) >= SENSOR_ALERT_COOLDOWN)
        {
            if (supabase_insert_alert(&supabase_cfg, supabase_cfg.device_id,
                    "sensor_failure", "Photoelectric water level sensor unreachable",
                    "high", "automated") == 0)
                last_photo_alert = now;
        }

        /* Dorm parity: autonomous 14h/10h light cycle. */
        {
            time_t cycle_elapsed = now - light_cycle_start;
            if (lights_on && cycle_elapsed >= DORM_LIGHT_ON_SECS)
            {
                if (lights_init() == 0 && lights_set(0) == 0)
                {
                    lights_on = 0;
                    light_cycle_start = now;
                    lights_off_at = 0;
                    printf("  -> Dorm light cycle: Lights OFF (%dh dark period)\n", DORM_LIGHT_OFF_HOURS);
                }
            }
            else if (!lights_on && cycle_elapsed >= DORM_LIGHT_OFF_SECS)
            {
                if (lights_init() == 0 && lights_set(1) == 0)
                {
                    lights_on = 1;
                    light_cycle_start = now;
                    lights_off_at = 0;
                    printf("  -> Dorm light cycle: Lights ON (%dh light period)\n", DORM_LIGHT_ON_HOURS);
                }
            }
        }

        /* Lights timeout: auto-off when duration_sec elapsed */
        if (lights_on && lights_off_at && now >= lights_off_at)
        {
            lights_set(0);
            lights_on = 0;
            lights_off_at = 0;
            printf("  -> Lights auto-off (timeout)\n");
        }

        /* Pump timeout: auto-off when duration_sec elapsed */
        if (pump_on && pump_off_at && now >= pump_off_at)
        {
            pump_set(0);
            pump_on = 0;
            pump_off_at = 0;
            printf("  -> Pump auto-off (timeout)\n");
        }

        /* Ventilation timeout: auto-off fans when run_ventilation duration elapsed */
        if (ventilation_off_at && now >= ventilation_off_at)
        {
            if (fans_init() == 0)
            {
                fans_set_both(0);
                fans_set_speed(1, DORM_ELEC_FAN_DUTY); /* Restore dorm baseline */
            }
            ventilation_off_at = 0;
            printf("  -> Ventilation auto-off (timeout)\n");
        }

        /* Dorm parity: soil-driven watering pulses with cooldown. */
        if (soil_moisture >= 0 && (now - last_soil_control_check) >= DORM_SOIL_CHECK_INTERVAL)
        {
            last_soil_control_check = now;
            printf("  -> Soil control check: %d (dry>%d, wet<%d)\n",
                   soil_moisture, DORM_DRY_THRESHOLD, DORM_WET_THRESHOLD);
            if (soil_moisture > DORM_DRY_THRESHOLD)
            {
                if ((now - last_pump_pulse) >= DORM_PUMP_COOLDOWN_SEC)
                {
                    if (pump_init() == 0 && pump_set(1) == 0)
                    {
                        pump_on = 1;
                        printf("  -> Soil dry (%d), watering for %ds\n", soil_moisture, DORM_PUMP_PULSE_SEC);
                        sleep(DORM_PUMP_PULSE_SEC);
                        pump_set(0);
                        pump_on = 0;
                        last_pump_pulse = time(NULL);
                        pump_off_at = 0;
                        printf("  -> Pump pulse complete\n");
                    }
                }
                else
                {
                    int remaining = (int)(DORM_PUMP_COOLDOWN_SEC - (now - last_pump_pulse));
                    if (remaining < 0) remaining = 0;
                    printf("  -> Soil dry but cooldown active (%ds remaining)\n", remaining);
                }
            }
            else if (soil_moisture < DORM_WET_THRESHOLD)
            {
                printf("  -> Soil sufficiently moist (%d), no watering needed\n", soil_moisture);
            }
            else
            {
                printf("  -> Soil in acceptable range (%d)\n", soil_moisture);
            }
        }

        printf("[%ld] L=%d Pump=%d T=%.1fC H=%.1f%% Press=%.1f hPa G=%.1f Soil=%d Photo=%dHz\n",
               now, lights_on, pump_on, bme_temp, bme_hum, bme_pressure, bme_gas, soil_moisture, photo_freq);

        int timestamp = (int)now;

        // --- Deadband Logic ---

        // 1. BME680 (temp, humidity, pressure, gas)
        if (bme680_ok && bme_temp > -900 && bme_hum > -900)
        {
            if (fabsf(bme_temp - last_bme_temp) >= THRESH_TEMP ||
                fabsf(bme_hum - last_bme_hum) >= THRESH_HUM ||
                fabsf(bme_pressure - last_bme_pressure) >= THRESH_PRESSURE ||
                fabsf(bme_gas - last_bme_gas) >= THRESH_GAS ||
                (now - last_bme_ts) >= HEARTBEAT_INTERVAL)
            {
                if (sql_execute_insert_bme680(db, bme_temp, bme_hum, bme_pressure, bme_gas, timestamp) == SQLITE_OK)
                {
                    printf("  -> Saved BME680 T=%.1f H=%.1f P=%.1f G=%.1f\n", bme_temp, bme_hum, bme_pressure, bme_gas);
                    last_bme_temp = bme_temp;
                    last_bme_hum = bme_hum;
                    last_bme_pressure = bme_pressure;
                    last_bme_gas = bme_gas;
                    last_bme_ts = now;
                }
            }
        }

        // 2. Check Soil Moisture
        if (soil_moisture != -1) {
            if (abs(soil_moisture - last_soil_moisture) >= THRESH_SOIL ||
                (now - last_soil_ts) >= HEARTBEAT_INTERVAL)
            {
                if (sql_execute_insert(db, sql_soil_moisture, soil_moisture, 0, timestamp) == SQLITE_OK) {
                    printf("  -> Saved Soil (Val: %d->%d)\n", last_soil_moisture, soil_moisture);
                    last_soil_moisture = soil_moisture;
                    last_soil_ts = now;
                }
            }
        }

        // 3. Check Water Level
        if (water_level != -1) {
            if (abs(water_level - last_water_level) >= THRESH_WATER ||
                (now - last_water_ts) >= HEARTBEAT_INTERVAL)
            {
                if (sql_execute_insert(db, sql_water_level, water_level, 0, timestamp) == SQLITE_OK) {
                    printf("  -> Saved Water (Val: %d->%d)\n", last_water_level, water_level);
                    last_water_level = water_level;
                    last_water_ts = now;
                }
            }
        }

        // 4. Photoelectric water level (5-state with hysteresis)
        static int last_photo_freq = -999;
        static int last_water_state = -1;
        static time_t last_photo_ts = 0;
        if (photo_freq >= 0) {
            int water_state = frequency_to_water_state(photo_freq, last_water_state);
            if (water_state != last_water_state ||
                abs(photo_freq - last_photo_freq) >= THRESH_PHOTO_WATER ||
                (now - last_photo_ts) >= HEARTBEAT_INTERVAL)
            {
                if (sql_execute_insert(db, sql_water_photo, water_state, 0, timestamp) == SQLITE_OK) {
                    printf("  -> Saved Photo Water state=%d (%dHz)\n", water_state, photo_freq);
                    last_photo_freq = photo_freq;
                    last_water_state = water_state;
                    last_photo_ts = now;
                }
            }
        }

        // Sync to Supabase periodically
        if (supabase_enabled)
        {
            if (now - last_sync >= SYNC_INTERVAL)
            {
                sync_to_supabase(db, &supabase_cfg);
                last_sync = now;
                /* Heartbeat for offline detection */
                if (supabase_cfg.device_id)
                    supabase_heartbeat(&supabase_cfg);
            }

            // Poll for pending commands
            if (now - last_command_poll >= 2)
            {
                last_command_poll = now;

                device_command_t cmd = {0};
                while (fetch_next_command(&supabase_cfg, &cmd) > 0)
                {
                    int ok = 0;
                    if (strcmp(cmd.command_type, "toggle_light") == 0)
                    {
                        int desired = 0;
                        int duration_sec = 0;
                        json_object *obj = json_tokener_parse(cmd.payload_json);
                        if (obj)
                        {
                            json_object *s = NULL, *d = NULL;
                            if (json_object_object_get_ex(obj, "state", &s))
                                desired = json_object_get_boolean(s) ? 1 : 0;
                            if (json_object_object_get_ex(obj, "duration_sec", &d))
                                duration_sec = json_object_get_int(d);
                            json_object_put(obj);
                        }
                        if (lights_init() == 0 && lights_set(desired) == 0)
                        {
                            lights_on = desired;
                            lights_off_at = (desired && duration_sec > 0) ? (time(NULL) + duration_sec) : 0;
                            ok = 1;
                            printf("  -> Lights %s (duration=%ds, auto-off=%s)\n",
                                   desired ? "ON" : "OFF", duration_sec,
                                   lights_off_at ? "yes" : "no");
                        }
                    }
                    else if (strcmp(cmd.command_type, "toggle_pump") == 0)
                    {
                        int desired = 0;
                        int duration_sec = 0;
                        json_object *obj = json_tokener_parse(cmd.payload_json);
                        if (obj)
                        {
                            json_object *s = NULL, *d = NULL;
                            if (json_object_object_get_ex(obj, "state", &s))
                                desired = json_object_get_boolean(s) ? 1 : 0;
                            if (json_object_object_get_ex(obj, "duration_sec", &d))
                                duration_sec = json_object_get_int(d);
                            json_object_put(obj);
                        }
                        if (pump_init() != 0)
                        {
                            fprintf(stderr, "toggle_pump: pump_init() failed - check GPIO permissions and wiring\n");
                        }
                        else if (pump_set(desired) != 0)
                        {
                            fprintf(stderr, "toggle_pump: pump_set(%d) failed\n", desired);
                        }
                        else
                        {
                            pump_on = desired;
                            pump_off_at = (desired && duration_sec > 0) ? (time(NULL) + duration_sec) : 0;
                            ok = 1;
                            printf("  -> Pump %s (duration=%ds, auto-off=%s)\n",
                                   desired ? "ON" : "OFF", duration_sec,
                                   pump_off_at ? "yes" : "no");
                        }
                    }
                    else if (strcmp(cmd.command_type, "toggle_fans") == 0)
                    {
                        int desired = 0;
                        json_object *obj = json_tokener_parse(cmd.payload_json);
                        if (obj)
                        {
                            json_object *s = NULL;
                            if (json_object_object_get_ex(obj, "state", &s))
                                desired = json_object_get_boolean(s) ? 1 : 0;
                            json_object_put(obj);
                        }
                        if (fans_init() == 0)
                        {
                            /* Avoid 0% when "on" requested - use minimum duty */
                            int duty = desired ? FAN_MIN_DUTY_WHEN_ON : 0;
                            fans_set_both(duty);
                            ok = 1;
                        }
                    }
                    else if (strcmp(cmd.command_type, "run_ventilation") == 0)
                    {
                        int duration_sec = 300, duty = 80;
                        json_object *obj = json_tokener_parse(cmd.payload_json);
                        if (obj)
                        {
                            json_object *d = NULL, *p = NULL;
                            if (json_object_object_get_ex(obj, "duration_sec", &d))
                                duration_sec = json_object_get_int(d);
                            if (json_object_object_get_ex(obj, "duty_percent", &p))
                                duty = json_object_get_int(p);
                            if (duty <= 0) duty = FAN_MIN_DUTY_WHEN_ON;
                            if (duty > 100) duty = 100;
                            json_object_put(obj);
                        }
                        if (fans_init() == 0)
                        {
                            fans_set_both(duty);
                            ventilation_off_at = time(NULL) + duration_sec;
                            ok = 1;
                        }
                    }
                    else if (strcmp(cmd.command_type, "set_fan_speed") == 0)
                    {
                        int fan_id = 1, duty = 0;
                        json_object *obj = json_tokener_parse(cmd.payload_json);
                        if (obj)
                        {
                            json_object *f = NULL, *d = NULL;
                            if (json_object_object_get_ex(obj, "fan_id", &f))
                                fan_id = json_object_get_int(f);
                            if (json_object_object_get_ex(obj, "duty_percent", &d))
                                duty = json_object_get_int(d);
                            json_object_put(obj);
                        }
                        if (duty < 0) duty = 0;
                        if (duty > 100) duty = 100;
                        if (fans_init() == 0 && fans_set_speed(fan_id, duty) == 0)
                            ok = 1;
                    }
                    else if (strcmp(cmd.command_type, "capture_image") == 0 && supabase_cfg.device_id)
                    {
                        const char *script = getenv("CAPTURE_SCRIPT_PATH");
                        if (!script) script = "scripts/capture_and_upload.py";
                        pid_t pid = fork();
                        if (pid == 0)
                        {
                            execl("/usr/bin/python3", "python3", script,
                                  supabase_cfg.device_id, (char *)NULL);
                            _exit(127);
                        }
                        else if (pid > 0)
                        {
                            int status;
                            waitpid(pid, &status, 0);
                            ok = (WIFEXITED(status) && WEXITSTATUS(status) == 0);
                        }
                    }

                    mark_command_processed(&supabase_cfg, cmd.id, ok ? "executed" : "failed");
                }
            }

            /* Refresh threshold cache from Supabase every 60s */
            if (now - last_threshold_fetch >= 60)
            {
                last_threshold_fetch = now;
                device_threshold_t *fetched = NULL;
                int fetched_count = 0;
                if (supabase_fetch_thresholds(&supabase_cfg, &fetched, &fetched_count) >= 0 && fetched)
                {
                    if (cached_thresholds) free(cached_thresholds);
                    cached_thresholds = fetched;
                    cached_thr_count = fetched_count;
                    printf("  [Thresholds] Refreshed %d threshold(s) from Supabase\n", cached_thr_count);
                }
                else
                {
                    fprintf(stderr, "  [Thresholds] Failed to fetch from Supabase (using cached %d)\n", cached_thr_count);
                }
            }

            /* Evaluate cached thresholds on every iteration so spikes are never missed */
            for (int t = 0; t < cached_thr_count; t++)
            {
                if (!cached_thresholds[t].enabled) continue;
                double val = -999;
                time_t *cooldown_ptr = NULL;
                const char *metric = cached_thresholds[t].metric;
                int cooldown_seconds = THRESHOLD_ALERT_COOLDOWN;
                if (strcmp(metric, "temp_c") == 0)          { val = bme_temp;     cooldown_ptr = &last_thr_alert_temp; }
                else if (strcmp(metric, "humidity") == 0)   { val = bme_hum;      cooldown_ptr = &last_thr_alert_hum; }
                else if (strcmp(metric, "pressure") == 0)   { val = bme_pressure; cooldown_ptr = &last_thr_alert_pressure; }
                else if (strcmp(metric, "gas_resistance") == 0) { val = bme_gas;  cooldown_ptr = &last_thr_alert_gas; }
                else if (strcmp(metric, "water_level_low") == 0) {
                    val = (double)photo_freq;
                    cooldown_ptr = &last_thr_alert_water;
                    cooldown_seconds = WATER_ALERT_COOLDOWN;
                }
                if (val < -900 && strcmp(metric, "water_level_low") != 0) continue;
                int exceeded = 0;
                if (strcmp(metric, "water_level_low") == 0) {
                    double low_hz_cutoff = WATER_LEVEL_LOW_HZ_DEFAULT;
                    if (cached_thresholds[t].max_value < 1e8)
                        low_hz_cutoff = cached_thresholds[t].max_value;
                    else if (cached_thresholds[t].min_value > -1e8)
                        low_hz_cutoff = cached_thresholds[t].min_value;
                    exceeded = (photo_freq >= 0 && val < low_hz_cutoff);
                }
                else
                    exceeded = (cached_thresholds[t].min_value > -1e8 && val < cached_thresholds[t].min_value) ||
                               (cached_thresholds[t].max_value < 1e8 && val > cached_thresholds[t].max_value);
                if (exceeded && cooldown_ptr && (now - *cooldown_ptr) >= cooldown_seconds)
                {
                    char msg[128];
                    if (strcmp(metric, "water_level_low") == 0)
                    {
                        double low_hz_cutoff = WATER_LEVEL_LOW_HZ_DEFAULT;
                        if (cached_thresholds[t].max_value < 1e8)
                            low_hz_cutoff = cached_thresholds[t].max_value;
                        else if (cached_thresholds[t].min_value > -1e8)
                            low_hz_cutoff = cached_thresholds[t].min_value;
                        snprintf(msg, sizeof(msg), "Water level is low - refill reservoir (%.0fHz < %.0fHz)", val, low_hz_cutoff);
                    }
                    else
                        snprintf(msg, sizeof(msg), "%s %.1f outside range [%.1f, %.1f]",
                                 metric, val, cached_thresholds[t].min_value, cached_thresholds[t].max_value);
                    const char *alert_type = (strcmp(metric, "water_level_low") == 0) ? "water_level_low" : "threshold";
                    const char *severity   = (strcmp(metric, "water_level_low") == 0) ? "high" : "medium";
                    printf("  [Thresholds] EXCEEDED: %s\n", msg);
                    if (supabase_insert_alert(&supabase_cfg, supabase_cfg.device_id,
                                             alert_type, msg, severity, "threshold") == 0)
                    {
                        *cooldown_ptr = now;
                        printf("  [Thresholds] Alert inserted for %s\n", metric);
                        if (strcmp(metric, "temp_c") == 0 || strcmp(metric, "humidity") == 0 ||
                            strcmp(metric, "gas_resistance") == 0)
                        {
                            if (fans_init() == 0)
                                fans_set_both(FAN_MIN_DUTY_WHEN_ON);
                            ventilation_off_at = now + 300;
                        }
                    }
                    else
                    {
                        fprintf(stderr, "  [Thresholds] ERROR: Failed to insert alert for %s\n", metric);
                    }
                }
            }

            /* Schedule evaluation (every 60s) */
            if (now - last_schedule_fetch >= 60)
            {
                last_schedule_fetch = now;
                device_schedule_t *sched = NULL;
                int sched_count = 0;
                if (supabase_fetch_schedules(&supabase_cfg, &sched, &sched_count) >= 0 && sched)
                {
                    static struct { char id[SCHEDULE_ID_LEN]; time_t last_run; } run_cache[16];
                    static int run_cache_n = 0;
                    struct tm *tm_now = localtime(&now);
                    int min = tm_now ? tm_now->tm_min : 0;
                    int hour = tm_now ? tm_now->tm_hour : 0;
                    for (int s = 0; s < sched_count; s++)
                    {
                        time_t last_run = 0;
                        for (int r = 0; r < run_cache_n; r++)
                            if (strcmp(run_cache[r].id, sched[s].id) == 0) { last_run = run_cache[r].last_run; break; }
                        int should_run = 0;
                        if (sched[s].interval_seconds > 0)
                            should_run = (now - last_run) >= (time_t)sched[s].interval_seconds;
                        else if (sched[s].cron_expr[0])
                        {
                            int cron_min = -1, cron_hour = -1;
                            if (sscanf(sched[s].cron_expr, "%d %d", &cron_min, &cron_hour) == 2)
                                should_run = (min == cron_min && hour == cron_hour && (now - last_run) >= 60);
                            else if (strncmp(sched[s].cron_expr, "*/", 2) == 0)
                            {
                                int n = 0;
                                sscanf(sched[s].cron_expr + 2, "%d", &n);
                                if (n > 0) should_run = (min % n == 0) && (now - last_run) >= 60;
                            }
                        }
                        if (should_run)
                        {
                            json_object *pl = json_tokener_parse(sched[s].payload_json);
                            int state = 1, duration = 30, duty = 80;
                            if (pl)
                            {
                                json_object *st = NULL, *du = NULL, *dt = NULL;
                                if (json_object_object_get_ex(pl, "state", &st)) state = json_object_get_boolean(st) ? 1 : 0;
                                if (json_object_object_get_ex(pl, "duration_sec", &du)) duration = json_object_get_int(du);
                                if (json_object_object_get_ex(pl, "duty_percent", &dt)) duty = json_object_get_int(dt);
                                json_object_put(pl);
                            }
                            if (strcmp(sched[s].schedule_type, "lights") == 0 && lights_init() == 0)
                            {
                                lights_set(state);
                                lights_on = state;
                                lights_off_at = (state && duration > 0) ? (now + duration) : 0;
                                if (lights_off_at)
                                    printf("  -> Lights ON (auto-off in %ds)\n", duration);
                            }
                            else if (strcmp(sched[s].schedule_type, "pump") == 0 && pump_init() == 0)
                            {
                                pump_set(state);
                                pump_on = state;
                                pump_off_at = (state && duration > 0) ? (now + duration) : 0;
                            }
                            else if (strcmp(sched[s].schedule_type, "ventilation") == 0 && fans_init() == 0)
                            {
                                fans_set_both(state ? (duty > 0 ? duty : FAN_MIN_DUTY_WHEN_ON) : 0);
                                ventilation_off_at = (state && duration > 0) ? (now + duration) : 0;
                            }
                            {
                                int found = 0;
                                for (int r = 0; r < run_cache_n; r++)
                                    if (strcmp(run_cache[r].id, sched[s].id) == 0) { run_cache[r].last_run = now; found = 1; break; }
                                if (!found && run_cache_n < 16)
                                {
                                    snprintf(run_cache[run_cache_n].id, sizeof(run_cache[run_cache_n].id), "%s", sched[s].id);
                                    run_cache[run_cache_n].last_run = now;
                                    run_cache_n++;
                                }
                                supabase_update_schedule_last_run(&supabase_cfg, sched[s].id);
                            }
                        }
                    }
                    free(sched);
                }
            }
        }

        sleep(DATA_READ_INTERVAL);
        iteration++;
    }

    if (cached_thresholds) free(cached_thresholds);

    if (supabase_enabled)
    {
        supabase_cleanup();
    }
    bme680_cleanup();
    sqlite3_close(db);
    gpio_cleanup();
    close(fd);

    return 0;
}
