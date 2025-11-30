#include "../lib/gpio.h"
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

int main() {
    const char *i2c_bus = "/dev/i2c-1";
    int channel = 1; // Using Channel 1 for photoresistor

    printf("Initializing I2C on %s...\n", i2c_bus);
    int fd = i2c_init(i2c_bus);
    if (fd < 0) {
        fprintf(stderr, "Failed to initialize I2C bus. Is I2C enabled? (sudo raspi-config -> Interface Options -> I2C)\n");
        return 1;
    }

    printf("Reading ADS7830 Channel %d. Press Ctrl+C to exit.\n", channel);
    
    while (1) {
        int val = read_ads7830_channel(fd, channel);
        if (val < 0) {
            fprintf(stderr, "Error reading ADS7830\n");
        } else {
            printf("Photoresistor Value (Light Intensity): %d/255\n", val);
        }
        sleep(3);
    }

    close(fd);
    return 0;
}
