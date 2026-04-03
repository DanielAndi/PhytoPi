#ifndef BME680_H
#define BME680_H

/* BME680 sensor reading structure */
typedef struct {
    float temperature;   /* Celsius */
    float humidity;      /* Percent */
    float pressure;      /* hPa */
    float gas_resistance; /* kOhm */
    int valid;           /* 1 if all readings valid */
} bme680_data_t;

/* Initialize BME680. Tries IIO first, then I2C.
 * Returns 0 on success, -1 on failure. */
int bme680_init(void);

/* Read sensor data. Returns 0 on success, -1 on failure. */
int bme680_read(bme680_data_t *data);

/* Cleanup resources */
void bme680_cleanup(void);

#endif /* BME680_H */
