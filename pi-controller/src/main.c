#include "../lib/gpio.h"
#include "../lib/sql.h"
#include "../lib/supabase.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>

#define SYNC_INTERVAL 60  // Sync to Supabase every 60 seconds
#define BATCH_SIZE 50     // Maximum readings per batch

// Sensor ID mapping - these should match your Supabase sensors table
// Set via environment variables: SUPABASE_HUMIDITY_SENSOR_ID, etc.
static char *humidity_sensor_id = NULL;
static char *temperature_sensor_id = NULL;
static char *soil_moisture_sensor_id = NULL;
static char *water_level_sensor_id = NULL;

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
                supabase_readings[supabase_count].unit = "boolean";
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

    // Initialize GPIO for water level sensor
    gpio_init(WATER_LEVEL_PIN);
    gpio_config_input(WATER_LEVEL_PIN);

    // Variables to hold sensor data
    int humidity = 0;
    int temperature = 0;
    int soil_moisture = 0;
    int water_level = 0;

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

    time_t last_sync = time(NULL);
    int iteration = 0;

    while (1)
    {
        soil_moisture = (fd >= 0) ? read_ads7830_channel(fd, 0) : -1;  // Read soil moisture from A0
        water_level = gpio_read(WATER_LEVEL_PIN);     // Read water level from GPIO pin
        int dht_result = read_dht_via_kernel(&humidity, &temperature); // Read DHT11 sensor data
        
        // If DHT11 read failed, set values to -1 to indicate error
        if (dht_result != 0)
        {
            humidity = -1;
            temperature = -1;
            if (iteration % 30 == 0) // Print error every 60 seconds
            {
                fprintf(stderr, "Warning: DHT11 sensor read failed (check /sys/bus/iio/devices/iio:device0/)\n");
            }
        }
        
        // Debug output (prints every 30 seconds)
        if (iteration % 15 == 0) // Print every 30 seconds (15 iterations * 2 seconds)
        {
            printf("Sensor readings - Soil: %d, Water: %d, Humidity: %d%%, Temp: %d°C\n", 
                   soil_moisture, water_level, humidity, temperature);
        }

        int timestamp = (int)time(NULL); // Make one current timestamp for all inserts so they all match

        // Insert data into the database
        if ((sql_execute_insert(db, sql_dht11, humidity, temperature, timestamp) != SQLITE_OK) ||
            (sql_execute_insert(db, sql_soil_moisture, soil_moisture, 0, timestamp) != SQLITE_OK) ||
            (sql_execute_insert(db, sql_water_level, water_level, 0, timestamp) != SQLITE_OK))
        {
            fprintf(stderr, "Failed to insert data into database.\n");
        }
        else
        {
            printf("Data inserted successfully into database.\n");
        }

        // Sync to Supabase periodically
        if (supabase_enabled)
        {
            time_t now = time(NULL);
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