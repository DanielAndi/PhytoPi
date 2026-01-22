#ifndef SQL_H
#define SQL_H
#include <sqlite3.h>

/* Reading structure for batch operations */
typedef struct {
    int id;
    double value1;
    double value2;  // For temperature (value1=humidity, value2=temperature)
    int64_t timestamp;
    char table_name[64];  // Which table this came from
} sqlite_reading_t;

int sql_execute(sqlite3 *db, const char *sql);
int sql_execute_insert(sqlite3 *db, const char *sql, int data, int data2, int timestamp);
sqlite3 *db_init(const char *db_file);
int sql_get_unsynced_readings(sqlite3 *db, sqlite_reading_t **readings, int *count);
int sql_mark_as_synced(sqlite3 *db, const char *table_name, int id);

#endif
