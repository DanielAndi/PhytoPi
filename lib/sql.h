#ifndef SQL_H
#define SQL_H
#include <sqlite3.h>

int sql_execute(sqlite3 *db, const char *sql);

#endif
