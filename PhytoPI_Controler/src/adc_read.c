#include <stdio.h>
#include <stdint.h>
#include <unistd.h>   // for sleep()

#define ADC_MAX_VALUE 4095      // change to 1023/4095/etc. to match your ADC
#define ADC_CHANNEL   0         // change to your soil sensor ADC channel

// TODO: replace these with your real ADC functions
void adc_init(void) {
    // Initialize your ADC peripheral here (clock, GPIO, channel, etc.)
}

uint16_t adc_read(uint8_t channel) {
    (void)channel;
    // Read from your ADC and return the raw value (0..ADC_MAX_VALUE)
    // For now just return a dummy value:
    return 2000;
}

int main(void) {
    adc_init();

    printf("Soil moisture sensor test\n");
    printf("Reading ADC channel %d...\n\n", ADC_CHANNEL);

    while (1) {
        uint16_t raw = adc_read(ADC_CHANNEL);
        float moisture_percent = (raw * 100.0f) / ADC_MAX_VALUE;

        printf("Raw: %4u  |  Moisture: %5.1f%%\n", raw, moisture_percent);

        fflush(stdout);
        sleep(1);  // 1 second between readings
    }

    return 0;
}