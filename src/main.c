#include "../lib/gpio.h"
#include "../lib/sql.h"

int main()
{
    int humidity = 0;
    int temperature = 0;

    sqlite3 *db = db_init("sensor_data.db");

    char sql[256] = "INSERT INTO sensor_data (humidity, temperature, timestamp) VALUES (?, ?, ?);";

    while (1)
    {
        read_dht_via_kernel(&humidity, &temperature);

        printf("Humidity: %d%%, Temperature: %dC\n", humidity, temperature);

        if (sql_execute_insert(db, sql, humidity, temperature, (int)time(NULL)) != SQLITE_OK)
        {
            fprintf(stderr, "Failed to insert data into database.\n");
        }
        else
        {
            printf("Data inserted successfully into database.\n");
        }

        sleep(DATA_READ_INTERVAL);
    }

    sqlite3_close(db);

    return 0;
}