#ifndef GPIO_IO
#define GPIO_IO

/* Standard Libraries */
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>

/* GPIO Library */
#include <gpiod.h>

/* I2C Libraries */
#include <linux/i2c-dev.h>
#include <sys/ioctl.h>
#include <fcntl.h>

#define WATER_LEVEL_PIN 26
#define DHT22_PIN 21
#define DATA_READ_INTERVAL 2 // In seconds
#define ADS7830_ADDR 0x4b    // Default 7-bit I2C address for ADS7830

/* GPIO function declarations */
int gpio_init(int pin);
int gpio_config_input(int pin);
int gpio_config_output(int pin);
int gpio_write(int value);
int gpio_read();
int gpio_cleanup();

/* DHT22 function declarations */
int read_dht_via_kernel(int *humidity, int *temperature);

/* ADS7830 ADC function declaration */
int i2c_init(const char *i2c_bus);
int read_ads7830_channel(int fd, int channel);

#endif