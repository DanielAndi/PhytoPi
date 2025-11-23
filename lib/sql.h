#ifndef SQL_H
#define SQL_H
#include <sqlite3.h>

int sql_execute(sqlite3 *db, const char *sql);
int sql_execute_insert(sqlite3 *db, const char *sql, int data, int data2, int timestamp);
sqlite3 *db_init(const char *db_file);

#endif
