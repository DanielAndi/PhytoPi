#include "../lib/gpio.h"
#include "../lib/sql.h"
#include "../lib/supabase.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <math.h>

#define SYNC_INTERVAL 5       // Sync to Supabase every 5 seconds
#define BATCH_SIZE 50         // Maximum readings per batch
#define DATA_READ_INTERVAL 2  // Read sensors every 2 seconds

// Deadband Thresholds
// Only record if value changes by more than this amount
#define THRESH_TEMP 1         // 1 degree C
#define THRESH_HUM 2          // 2 percent
#define THRESH_SOIL 5         // 5 raw units (approx 2%)
#define THRESH_WATER 5        // 5 raw units
#define THRESH_LIGHT 10       // 10 raw units

// Heartbeat
// Force a recording every X seconds even if values haven't changed
#define HEARTBEAT_INTERVAL 300 // 5 minutes

// Sensor ID mapping - these should match your Supabase sensors table
// Set via environment variables: SUPABASE_HUMIDITY_SENSOR_ID, etc.
static char *humidity_sensor_id = NULL;
static char *temperature_sensor_id = NULL;
static char *soil_moisture_sensor_id = NULL;
static char *water_level_sensor_id = NULL;
static char *light_level_sensor_id = NULL;

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
    // temp_hum_data can create 2 readings (humidity + temperature)
    // So we need at least count * 2 space in worst case
    int max_supabase_count = count * 2;
    
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
    int fd = i2c_init("/dev/i2c-1"); // You need a FD to read from ADS7830 channels
    if (fd < 0)
    {
        fprintf(stderr, "Warning: I2C bus initialization failed. Soil moisture readings may not work.\n");
        fprintf(stderr, "To enable I2C: sudo raspi-config -> Interface Options -> I2C -> Enable\n");
    }

    // Variables to hold sensor data
    int humidity = -1;      // Initialize to -1 (error state)
    int temperature = -1;   // Initialize to -1 (error state)
    int soil_moisture = 0;
    int water_level = 0;
    int light_level = 0;

    // State variables for Deadband/Heartbeat logic
    int last_humidity = -999;
    int last_temperature = -999;
    int last_soil_moisture = -999;
    int last_water_level = -999;
    int last_light_level = -999;

    time_t last_env_ts = 0;   // Last time temp/humidity was sent
    time_t last_soil_ts = 0;  // Last time soil moisture was sent
    time_t last_water_ts = 0; // Last time water level was sent
    time_t last_light_ts = 0; // Last time light level was sent

    // Initialize the database
    sqlite3 *db = db_init("sensor_data.db");
    if (!db)
    {
        fprintf(stderr, "Failed to initialize database\n");
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
    char sql_dht11[256] = "INSERT INTO temp_hum_data (humidity, temperature, timestamp) VALUES (?, ?, ?);";
    char sql_soil_moisture[256] = "INSERT INTO soil_moisture_data (humidity, timestamp) VALUES (?, ?);";
    char sql_water_level[256] = "INSERT INTO water_level_data (has_water, timestamp) VALUES (?, ?);";
    char sql_light_level[256] = "INSERT INTO light_level_data (light_level, timestamp) VALUES (?, ?);";

    time_t last_sync = time(NULL);
    time_t last_dht_read = 0;  // Track last DHT11 read time (needs 2+ second cooldown)
    int iteration = 0;

    printf("Starting sensor loop (Interval: %ds, Heartbeat: %ds)\n", DATA_READ_INTERVAL, HEARTBEAT_INTERVAL);

    while (1)
    {
        soil_moisture = (fd >= 0) ? read_ads7830_channel(fd, 0) : -1;  // Read soil moisture from A0
        water_level = (fd >= 0) ? read_ads7830_channel(fd, 2) : -1;    // Read water level from A2
        light_level = (fd >= 0) ? read_ads7830_channel(fd, 1) : -1;    // Read light level from A1
        
        // DHT11 needs at least 2-3 seconds between reads for reliability
        // Also add retry logic for more reliability
        time_t now = time(NULL);
        int dht_result = -1;
        int dht_skipped = 0;
        if (now - last_dht_read >= 3)  // Increased from 2 to 3 seconds
        {
            // Try reading up to 3 times
            for (int retry = 0; retry < 3 && dht_result != 0; retry++)
            {
                if (retry > 0)
                {
                    usleep(100000);  // 100ms delay between retries
                }
                dht_result = read_dht_via_kernel(&humidity, &temperature); // Read DHT11 sensor data
                if (dht_result == 0)
                {
                    last_dht_read = now;  // Only update on success
                    break;  // Success, exit retry loop
                }
            }
        }
        else
        {
            // Use previous values if we're in cooldown period
            dht_skipped = 1;
        }
        
        // If DHT11 read failed (and wasn't skipped), set values to -1 to indicate error
        if (!dht_skipped && dht_result != 0)
        {
            // Keep old values if read failed, but mark as error if it persists
            // For now, we'll just log it and not update 'humidity'/'temperature' variables
            // so they retain their last valid (or initial -1) state.
            
            const char *error_msg = "Unknown error";
            switch (dht_result)
            {
                case -1: error_msg = "Failed to open GPIO chip or get line"; break;
                case -2: error_msg = "No response signal (low)"; break;
                case -3: error_msg = "No response signal (high)"; break;
                case -4: error_msg = "No response signal (low after high)"; break;
                case -5: error_msg = "Data read timeout (high)"; break;
                case -6: error_msg = "Data read timeout (low)"; break;
                case -7: error_msg = "Checksum mismatch"; break;
            }
            // Only print error every 10 iterations to reduce log spam
            if (iteration % 10 == 0) {
                fprintf(stderr, "Warning: DHT11 sensor read failed (error: %d - %s)\n", dht_result, error_msg);
            }
        }
        
        // Debug output (always print current state)
        const char *water_status = (water_level >= 5) ? "HAS WATER" : "NO WATER";
        printf("[%ld] Readings: Soil=%d, Water=%d, Light=%d, Hum=%d%%, Temp=%dC\n", 
               now, soil_moisture, water_level, light_level, humidity, temperature);

        int timestamp = (int)now;

        // --- Deadband Logic ---

        // 1. Check Environment (Temp/Humidity)
        // Only update if valid reading AND (changed significantly OR heartbeat expired)
        if (dht_result == 0 && humidity != -1 && temperature != -1) {
            if (abs(humidity - last_humidity) >= THRESH_HUM || 
                abs(temperature - last_temperature) >= THRESH_TEMP ||
                (now - last_env_ts) >= HEARTBEAT_INTERVAL)
            {
                if (sql_execute_insert(db, sql_dht11, humidity, temperature, timestamp) == SQLITE_OK) {
                    printf("  -> Saved Temp/Hum (Hum: %d->%d, Temp: %d->%d)\n", 
                           last_humidity, humidity, last_temperature, temperature);
                    last_humidity = humidity;
                    last_temperature = temperature;
                    last_env_ts = now;
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

        // 4. Check Light Level
        if (light_level != -1) {
            if (abs(light_level - last_light_level) >= THRESH_LIGHT ||
                (now - last_light_ts) >= HEARTBEAT_INTERVAL)
            {
                if (sql_execute_insert(db, sql_light_level, light_level, 0, timestamp) == SQLITE_OK) {
                    printf("  -> Saved Light (Val: %d->%d)\n", last_light_level, light_level);
                    last_light_level = light_level;
                    last_light_ts = now;
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
            }
        }

        sleep(DATA_READ_INTERVAL);
        iteration++;
    }

    if (supabase_enabled)
    {
        supabase_cleanup();
    }
    sqlite3_close(db); // Close the database connection
    gpio_cleanup();    // Cleanup GPIO resources
    close(fd);         // Close I2C file descriptor

    return 0;
}
