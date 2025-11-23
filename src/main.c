#include "../lib/gpio.h"
#include "../lib/sql.h"

int main()
{
    int fd = i2c_init("/dev/i2c-1"); // You need a FD to read from ADS7830 channels

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

    // SQL insert statements
    char sql_dht11[256] = "INSERT INTO temp_hum_data (humidity, temperature, timestamp) VALUES (?, ?, ?);";
    char sql_soil_moisture[256] = "INSERT INTO soil_moisture_data (humidity, timestamp) VALUES (?, ?);";
    char sql_water_level[256] = "INSERT INTO water_level_data (has_water, timestamp) VALUES (?, ?);";

    while (1)
    {
        soil_moisture = read_ads7830_channel(fd, 0);  // Read soil moisture from A0
        water_level = gpio_read(WATER_LEVEL_PIN);     // Read water level from GPIO pin
        read_dht_via_kernel(&humidity, &temperature); // Read DHT11 sensor data

        /* Print statements if you want to see data collected
        printf("Soil Moisture Level: %d\n", soil_moisture);
        printf("Water Level: %d\n", water_level);
        printf("Humidity: %d%%, Temperature: %dC\n", humidity, temperature);
        */

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

        sleep(DATA_READ_INTERVAL);
    }

    sqlite3_close(db); // Close the database connection
    gpio_cleanup();    // Cleanup GPIO resources
    close(fd);         // Close I2C file descriptor

    return 0;
}