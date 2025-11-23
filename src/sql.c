#include "../lib/gpio.h"
#include "../lib/sql.h"

/*
 * Execute an SQL statement on the given database.
 * Returns SQLITE_OK on success, or an SQLite error code on failure.
 */
int sql_execute(sqlite3 *db, const char *sql)
{
    char *err_msg = 0;
    int rc = sqlite3_exec(db, sql, 0, 0, &err_msg);

    if (rc != SQLITE_OK)
    {
        fprintf(stderr, "SQL error: %s\n", err_msg);
        sqlite3_free(err_msg);
        return rc;
    }

    return SQLITE_OK;
}

/*
 * Execute an SQL insert statement with parameters on the given database.
 * Returns SQLITE_OK on success, or an SQLite error code on failure.
 */
int sql_execute_insert(sqlite3 *db, const char *sql, int data, int data2, int timestamp)
{
    sqlite3_stmt *stmt;                                    // Declare a statement pointer
    int rc = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL); // Prepare the SQL statement
    if (rc != SQLITE_OK)
    {
        fprintf(stderr, "Failed to prepare statement: %s\n", sqlite3_errmsg(db));
        return rc;
    }

    // Bind the parameters to the prepared statement
    sqlite3_bind_int(stmt, 1, data);
    if (data2 != 0) // Only bind the second data if it's not zero (for dht11)
        sqlite3_bind_int(stmt, 2, data2);
    sqlite3_bind_int(stmt, 3, timestamp);

    rc = sqlite3_step(stmt); // Execute the prepared statement

    if (rc != SQLITE_DONE && rc != SQLITE_OK)
    {
        fprintf(stderr, "Execution failed: %s\n", sqlite3_errmsg(db));
        sqlite3_finalize(stmt); // Finalize the statement to release resources
        return rc;
    }

    sqlite3_finalize(stmt); // Finalize the statement to release resources
    return SQLITE_OK;
}

sqlite3 *db_init(const char *db_file)
{
    sqlite3 *db;
    int rc = sqlite3_open(db_file, &db);
    if (rc)
    {
        fprintf(stderr, "Can't open database: %s\n", sqlite3_errmsg(db));
        return NULL;
    }

    sql_execute(db, "CREATE TABLE IF NOT EXISTS temp_hum_data (id INTEGER PRIMARY KEY, humidity INTEGER, temperature INTEGER, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP);");
    sql_execute(db, "CREATE TABLE IF NOT EXISTS soil_moisture_data (id INTEGER PRIMARY KEY, humidity INTEGER, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP);");
    sql_execute(db, "CREATE TABLE IF NOT EXISTS water_level_data (id INTEGER PRIMARY KEY, has_water BOOLEAN, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP);");

    return db;
}