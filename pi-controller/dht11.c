// dht11.c - Read DHT11 sensor on Raspberry Pi using libgpiod
// Compile: gcc dht11.c -lgpiod -o dht11
// Run: sudo ./dht11

#include <stdio.h>
#include <stdint.h>
#include <time.h>
#include <unistd.h>
#include <gpiod.h>

#define DHT_PIN 4

static uint64_t micros_now(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000ULL + ts.tv_nsec / 1000;
}

static int wait_for_level(struct gpiod_line *line, int level, uint32_t timeout_us) {
    uint64_t start = micros_now();
    while (gpiod_line_get_value(line) != level) {
        if ((micros_now() - start) > timeout_us) return -1;
    }
    return (int)(micros_now() - start);
}

int read_dht11(struct gpiod_line *line, int *humidity, int *temperature_c) {
    uint8_t data[5] = {0};

    gpiod_line_release(line);
    gpiod_line_request_output(line, "dht11", 1);
    usleep(1000);
    gpiod_line_set_value(line, 0);
    usleep(20000);
    gpiod_line_set_value(line, 1);
    usleep(40);
    gpiod_line_release(line);
    
    gpiod_line_request_input_flags(line, "dht11", GPIOD_LINE_REQUEST_FLAG_BIAS_PULL_UP);

    if (wait_for_level(line, 0, 200) < 0) return -1;
    if (wait_for_level(line, 1, 200) < 0) return -2;
    if (wait_for_level(line, 0, 200) < 0) return -3;

    for (int i = 0; i < 40; i++) {
        if (wait_for_level(line, 1, 150) < 0) return -4;
        int high_duration = wait_for_level(line, 0, 150);
        if (high_duration < 0) return -5;
        
        data[i / 8] = (data[i / 8] << 1) | (high_duration > 50 ? 1 : 0);
    }

    if ((data[0] + data[1] + data[2] + data[3]) != data[4]) return -6;

    *humidity = data[0];
    *temperature_c = data[2];
    return 0;
}

int main(void) {
    struct gpiod_chip *chip = gpiod_chip_open_by_name("gpiochip0");
    if (!chip) return 1;

    struct gpiod_line *line = gpiod_chip_get_line(chip, DHT_PIN);
    if (!line) {
        gpiod_chip_close(chip);
        return 1;
    }

    usleep(1000000);

    int humidity, temperature_c;
    while (1) {
        if (read_dht11(line, &humidity, &temperature_c) == 0) {
            printf("Humidity: %d%%  |  Temperature: %d°C (%.1f°F)\n",
                   humidity, temperature_c, temperature_c * 1.8f + 32.0f);
        }
        usleep(2000000);
    }

    gpiod_line_release(line);
    gpiod_chip_close(chip);
    return 0;
}