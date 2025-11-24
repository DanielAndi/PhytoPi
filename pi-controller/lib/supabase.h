#ifndef SUPABASE_H
#define SUPABASE_H

#include <stdint.h>

/* Supabase configuration structure */
typedef struct {
    char *api_url;      // e.g., "http://127.0.0.1:54321" or "https://your-project.supabase.co"
    char *api_key;      // Supabase anon/service role key
    char *device_id;    // UUID of the device in Supabase
} supabase_config_t;

/* Reading structure for batch operations */
typedef struct {
    char *sensor_id;    // UUID of the sensor in Supabase
    double value;       // Sensor reading value
    char *unit;         // Unit of measurement (e.g., "celsius", "percent", "boolean")
    int64_t timestamp;  // Unix timestamp
    char *metadata;     // Optional JSON metadata (can be NULL)
} supabase_reading_t;

/* Function declarations */
int supabase_init(supabase_config_t *config);
int supabase_send_batch(supabase_config_t *config, supabase_reading_t *readings, int count);
int supabase_cleanup(void);

#endif

