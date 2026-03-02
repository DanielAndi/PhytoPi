#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/i2c-dev.h>

#define PCF8591_ADDR   0x48    // default I2C address (A0/A1/A2 all tied to GND)
#define I2C_BUS        "/dev/i2c-1"   // use /dev/i2c-0 on older Pi revisions
#define ADC_CHANNEL    0       // AIN0 = soil moisture sensor
#define ADC_MAX_VALUE  255     // PCF8591 is 8-bit

static int i2c_fd = -1;

static void adc_init(void) {
    i2c_fd = open(I2C_BUS, O_RDWR);
    if (i2c_fd < 0) {
        perror("Failed to open I2C bus");
        exit(1);
    }
    if (ioctl(i2c_fd, I2C_SLAVE, PCF8591_ADDR) < 0) {
        perror("Failed to set I2C slave address");
        exit(1);
    }
}

// Returns raw 8-bit ADC value (0-255) from the given channel (0-3)
static uint8_t adc_read(uint8_t channel) {
    // Control byte: enable analog output (bit6=1) + select channel
    uint8_t control = 0x40 | (channel & 0x03);

    if (write(i2c_fd, &control, 1) != 1) {
        perror("I2C write failed");
        return 0;
    }

    // PCF8591 returns the *previous* conversion first, then the current one.
    // Read two bytes and discard the first (stale) byte.
    uint8_t buf[2];
    if (read(i2c_fd, buf, 2) != 2) {
        perror("I2C read failed");
        return 0;
    }

    return buf[1];  // current conversion result
}

int main(void) {
    adc_init();

    printf("PCF8591 soil moisture sensor test\n");
    printf("I2C bus: %s  |  address: 0x%02X  |  channel: AIN%d\n\n",
           I2C_BUS, PCF8591_ADDR, ADC_CHANNEL);

    while (1) {
        uint8_t raw = adc_read(ADC_CHANNEL);
        // Higher raw value = wetter (sensor output drops with moisture)
        float moisture_percent = (raw * 100.0f) / ADC_MAX_VALUE;

        printf("Raw: %3u / 255  |  Moisture: %5.1f%%  |  %s\n",
               raw,
               moisture_percent,
               raw < 85  ? "DRY"  :
               raw < 170 ? "MOIST" : "WET");

        fflush(stdout);
        sleep(1);
    }

    close(i2c_fd);
    return 0;
}
