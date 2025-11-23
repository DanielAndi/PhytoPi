#include "../lib/gpio.h"

/*
 * This method reads 40 bits of data from the DHT22 sensor and parses it into humidity and temperature values.
 * Returns 0 on success, -1 on timeout, -2 on checksum error.
 */
int read_dht22(int pin, int *humidity, int *temperature)
{

    // The datasheet for the DHT22 specifies the following initialization sequence:
    // Pull the data line low for at least 18ms, then pull it high for 20-40us, then switch to input mode.
    // After this, the sensor will respond with a low signal for 80us, a high signal for 80us, and then begin sending 40 bits of data.
    gpioSetMode(pin, PI_OUTPUT); // Sets pin to output mode
    gpioWrite(pin, PI_LOW);      // Pull line low
    gpioDelay(18000);            // 18 ms
    gpioWrite(pin, PI_HIGH);     // Pull line high
    gpioDelay(20);               // 20 us
    gpioSetMode(pin, PI_INPUT);  // Sets pin to input mode

    gpio_edge_wait(pin, PI_LOW, 100);  // Wait for sensor response: 80us low
    gpio_edge_wait(pin, PI_HIGH, 100); // 80us high
    gpio_edge_wait(pin, PI_LOW, 100);  // Start of data transmission

    uint8_t data[5] = {0, 0, 0, 0, 0};
    int bit = 0;
    for (int i = 0; i < 40; i++)
    {
        gpio_edge_wait(pin, PI_HIGH, 100); // Wait for rising edge

        // Measure length of the high pulse to distinguish between 0 and 1
        int high_duration = gpio_edge_wait(pin, PI_LOW, 120); // Wait for falling edge

        if (high_duration < 0)
        {
            return -1; // Timeout
        }

        // Data has threshold between low (about 26us) and high (about 70us)
        if (high_duration > 50) // Greater than 50us means 1
        {
            bit = 1;
        }
        else
        {
            bit = 0;
        }

        data[i / 8] <<= 1;  // Shift left by 1 to make room for new bit
        data[i / 8] |= bit; // Set leftmost bit in byte (data[i / 8])
    }
    // The DHT22 gives a checksum as the last byte, here we verify it
    if (((data[0] + data[1] + data[2] + data[3]) & 0xFF) != data[4])
    {
        return -2; // Checksum does not match
    }

    // Parse humidity and temperature from data
    *humidity = ((data[0] << 8) | data[1]) * 0.1;             // Humidity in %
    *temperature = (((data[2] & 0x7F) << 8) | data[3]) * 0.1; // Temperature in Celsius
    return 0;
}

int read_dht_via_kernel(int *humidity, int *temperature)
{
    FILE *f;
    int t_raw, h_raw;

    f = fopen("/sys/bus/iio/devices/iio:device0/in_temp_input", "r");
    if (!f)
        return -1;
    fscanf(f, "%d", &t_raw);
    fclose(f);

    f = fopen("/sys/bus/iio/devices/iio:device0/in_humidityrelative_input", "r");
    if (!f)
        return -1;
    fscanf(f, "%d", &h_raw);
    fclose(f);

    *temperature = t_raw / 1000;
    *humidity = h_raw / 1000;

    return 0;
}
