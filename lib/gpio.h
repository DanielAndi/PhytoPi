#ifndef GPIO_IO
#define GPIO_IO

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <pigpio.h> // We have to use pigpio because it runs a Linux daemon which can handle precise timing because of the dht22 init sequence.

#define DHT22_PIN 26
#define DATA_READ_INTERVAL 60 // In seconds

/* GPIO function declarations */
int gpio_init();
void gpio_edge_alert(int pin, int level, uint32_t tick);    // Callback function for edge detection (runs asynchronously)
int gpio_edge_wait(int pin, int level, __uint32_t timeout); // Wait for edge on pin to reach specified level or timeout
void gpio_config_input(int pin);
void gpio_config_output(int pin);
int gpio_cleanup();

/* DHT22 function declarations */
int read_dht22(int pin, int *humidity, int *temperature);
int read_dht_via_kernel(int *humidity, int *temperature);

#endif