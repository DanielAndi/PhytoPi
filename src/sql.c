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