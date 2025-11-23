#include "../lib/gpio.h"
#include "../lib/sql.h"

int main()
{
    int humidity = 0;
    int temperature = 0;

    sqlite3 *db;

    char sql[256];
    sqlite3_open("sensor_data.db", &db);

    sql_execute(db, "CREATE TABLE IF NOT EXISTS sensor_data (id INTEGER PRIMARY KEY, humidity INTEGER, temperature INTEGER, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP);");

    while (1)
    {
        read_dht_via_kernel(&humidity, &temperature);

        printf("Humidity: %d%%, Temperature: %dC\n", humidity, temperature);

        snprintf(sql, sizeof(sql), "INSERT INTO sensor_data (humidity, temperature, timestamp) VALUES (%d, %d, %li);", humidity, temperature, time(NULL));

        sql_execute(db, sql);

        sleep(120);
    }

    sqlite3_close(db);

    return 0;
}