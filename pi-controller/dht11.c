// dht11.c - Read DHT11 on Raspberry Pi using pigpio (Bookworm compatible)
// Compile: gcc dht11.c -lpigpio -lpthread -o dht11
// Run:     sudo ./dht11            (sudo recommended for reliable timing)
//
// Wiring (3.3V only):
//   DHT11 VCC -> 3V3 (e.g., pin 17), GND -> any GND (e.g., pin 14),
//   DHT11 DATA -> GPIO4 (physical pin 7) by default, with ~10k pull-up to 3V3.
//
// If GPIO4 is taken, change DHT_PIN below to another free BCM GPIO (e.g., 17).

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <time.h>
#include <pigpio.h>

#define DHT_PIN 7          // BCM numbering: GPIO4 (physical pin 7). Change if needed.
#define MAX_TIMINGS 85     // We expect ~80 edges; add some headroom.

static inline uint32_t micros_now() { return gpioTick(); }

// Busy-wait until pin reaches 'level' or timeout (in microseconds). Returns elapsed us or -1 on timeout.
int wait_for_level(int pin, int level, uint32_t timeout_us) {
    uint32_t start = micros_now();
    while (gpioRead(pin) != level) {
        if ((micros_now() - start) > timeout_us) return -1;
    }
    return (int)(micros_now() - start);
}

int read_dht11(int pin, int *humidity, int *temperature_c) {
    uint8_t data[5] = {0,0,0,0,0};
    // 1) Send start signal: pin as output, pull low for >=18ms, then high 20-40us.
    gpioSetMode(pin, PI_OUTPUT);
    gpioWrite(pin, PI_HIGH);         // idle high (due to pull-up)
    gpioDelay(1000);                 // settle 1ms
    gpioWrite(pin, PI_LOW);
    gpioDelay(20 * 1000);            // 20 ms
    gpioWrite(pin, PI_HIGH);
    gpioDelay(30);                   // ~30 us
    gpioSetMode(pin, PI_INPUT);      // release to input

    // 2) Sensor response: ~80us low, ~80us high
    if (wait_for_level(pin, PI_LOW, 100) < 0)  return -1; // wait for low
    if (wait_for_level(pin, PI_HIGH, 100) < 0) return -2; // then high
    if (wait_for_level(pin, PI_LOW, 100) < 0)  return -3; // then low starts bit stream

    // 3) Read 40 bits. Each bit: ~50us low, then high 26-28us (0) or ~70us (1).
    for (int i = 0; i < 40; i++) {
        // Each bit starts with low ~50us
        if (wait_for_level(pin, PI_HIGH, 100) < 0) return -4; // wait for rising edge
        // Measure length of the high pulse to distinguish 0 vs 1
        int high_len = wait_for_level(pin, PI_LOW, 120);      // until it falls again
        if (high_len < 0) return -5;

        // Shift and set bit
        int bit = (high_len > 50) ? 1 : 0; // threshold ~50us between 0 (~26us) and 1 (~70us)
        data[i/8] <<= 1;
        data[i/8] |= bit;
    }

    // 4) Checksum
    uint8_t sum = (uint8_t)(data[0] + data[1] + data[2] + data[3]);
    if (sum != data[4]) return -6;

    // DHT11 format: data[0]=humidity int, data[1]=humidity dec (usually 0),
    //               data[2]=temp int,    data[3]=temp dec (usually 0).
    *humidity = (int)data[0];
    *temperature_c = (int)data[2];
    return 0;
}

int main(void) {
    if (gpioInitialise() < 0) {
        fprintf(stderr, "pigpio init failed\n");
        return 1;
    }

    // Optional: enable pull-up to help keep line high when idle (module likely has one already).
    gpioSetPullUpDown(DHT_PIN, PI_PUD_UP);

    for (;;) {
        int h = 0, tc = 0;
        int rc = read_dht11(DHT_PIN, &h, &tc);
        if (rc == 0) {
            double tf = tc * 9.0/5.0 + 32.0;
            printf("Humidity: %d %%  |  Temp: %d °C (%.1f °F)\n", h, tc, tf);
        } else {
            // Transient failures are normal with DHTs. Try again in a moment.
            printf("Read failed (rc=%d). Retrying...\n", rc);
        }
        gpioDelay(2000 * 1000); // 2 seconds between reads
    }

    gpioTerminate();
    return 0;
}
