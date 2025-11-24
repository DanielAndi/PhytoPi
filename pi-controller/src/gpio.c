#include "../lib/gpio.h"
#include <stdint.h>
#include <time.h>

static struct gpiod_chip *chip;
static struct gpiod_line *line;

/*
 * Initialize GPIO library
 */
int gpio_init(int pin)
{
    chip = gpiod_chip_open_by_name("gpiochip0");
    if (!chip)
        return -1;
    line = gpiod_chip_get_line(chip, pin);
    if (!line)
        return -1;
    return 0;
}

/*
 * Configure pin as input
 */
int gpio_config_input(int pin)
{
    return gpiod_line_request_input(line, "gpio_app");
}

/*
 * Configure pin as output
 */
int gpio_config_output(int pin)
{
    return gpiod_line_request_output(line, "gpio_app", 0);
}

/*
 * Write value to GPIO pin
 */
int gpio_write(int value)
{
    return gpiod_line_set_value(line, value);
}

/*
 * Read value from GPIO pin
 */
int gpio_read()
{
    return gpiod_line_get_value(line);
}

/*
 * Cleanup GPIO library
 */
int gpio_cleanup()
{
    gpiod_line_release(line);
    gpiod_chip_close(chip);
    return 0;
}

/*
 * -------------------------------
 * OTHER NON-GPIOD.H LIBRARY PIN READ/WRITES + ADC I2C READS
 *-------------------------------
 */

/*
 * Helper function to get current time in microseconds
 */
static uint64_t micros_now(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (uint64_t)ts.tv_sec * 1000000ULL + ts.tv_nsec / 1000;
}

/*
 * Helper function to wait for GPIO line to reach a specific level
 * Returns duration in microseconds, or -1 on timeout
 */
static int wait_for_level(struct gpiod_line *line, int level, uint32_t timeout_us)
{
    uint64_t start = micros_now();
    while (gpiod_line_get_value(line) != level)
    {
        if ((micros_now() - start) > timeout_us)
            return -1;
    }
    return (int)(micros_now() - start);
}

/*
 * Read temperature and humidity from DHT11/DHT22 sensor via GPIO.
 * Uses the DHT22_PIN defined in gpio.h (pin 21).
 * Returns 0 on success, negative value on failure.
 */
int read_dht_via_kernel(int *humidity, int *temperature)
{
    struct gpiod_chip *dht_chip = gpiod_chip_open_by_name("gpiochip0");
    if (!dht_chip)
        return -1;

    struct gpiod_line *dht_line = gpiod_chip_get_line(dht_chip, DHT22_PIN);
    if (!dht_line)
    {
        gpiod_chip_close(dht_chip);
        return -1;
    }

    uint8_t data[5] = {0};

    // Start signal: pull low for 20ms, then high for 40us
    // Release any previous state first
    gpiod_line_release(dht_line);
    usleep(10000);  // Small delay to ensure clean state
    
    gpiod_line_request_output(dht_line, "dht11", 1);
    usleep(1000);
    gpiod_line_set_value(dht_line, 0);
    usleep(20000);  // 20ms - DHT11 requires at least 18ms
    gpiod_line_set_value(dht_line, 1);
    usleep(40);     // 40us - DHT11 requires 20-40us
    gpiod_line_release(dht_line);
    
    // Small delay before switching to input mode
    usleep(10);

    // Switch to input mode with pull-up
    gpiod_line_request_input_flags(dht_line, "dht11", GPIOD_LINE_REQUEST_FLAG_BIAS_PULL_UP);

    // Wait for response signal (increased timeouts for reliability)
    if (wait_for_level(dht_line, 0, 300) < 0)  // Increased from 200 to 300us
    {
        gpiod_line_release(dht_line);
        gpiod_chip_close(dht_chip);
        return -2;
    }
    if (wait_for_level(dht_line, 1, 300) < 0)  // Increased from 200 to 300us
    {
        gpiod_line_release(dht_line);
        gpiod_chip_close(dht_chip);
        return -3;
    }
    if (wait_for_level(dht_line, 0, 300) < 0)  // Increased from 200 to 300us
    {
        gpiod_line_release(dht_line);
        gpiod_chip_close(dht_chip);
        return -4;
    }

    // Read 40 bits of data
    // Increased timeouts for more reliable reading
    for (int i = 0; i < 40; i++)
    {
        if (wait_for_level(dht_line, 1, 200) < 0)  // Increased from 150 to 200us
        {
            gpiod_line_release(dht_line);
            gpiod_chip_close(dht_chip);
            return -5;
        }
        int high_duration = wait_for_level(dht_line, 0, 200);  // Increased from 150 to 200us
        if (high_duration < 0)
        {
            gpiod_line_release(dht_line);
            gpiod_chip_close(dht_chip);
            return -6;
        }

        // If high duration > 50us, it's a '1', otherwise '0'
        // Adjusted threshold slightly for better reliability
        data[i / 8] = (data[i / 8] << 1) | (high_duration > 40 ? 1 : 0);
    }

    gpiod_line_release(dht_line);
    gpiod_chip_close(dht_chip);

    // Verify checksum
    if ((data[0] + data[1] + data[2] + data[3]) != data[4])
        return -7;

    // Extract humidity and temperature
    *humidity = data[0];
    *temperature = data[2];

    return 0;
}

int i2c_init(const char *i2c_bus)
{
    int fd = open(i2c_bus, O_RDWR);
    if (fd < 0)
    {
        perror("Failed to open the i2c bus");
        return -1;
    }

    if (ioctl(fd, I2C_SLAVE, ADS7830_ADDR) < 0)
    {
        perror("Failed to acquire bus access and/or talk to slave");
        close(fd);
        return -1;
    }

    return fd;
}

/*
 * Reads a given channel from the ADS7830 ADC over I2C.
 * Returns the 8-bit ADC value on success, -1 on failure.
 */
int read_ads7830_channel(int fd, int channel)
{
    if (channel < 0 || channel > 7)
        return -1;

    unsigned char cmd = 0x84 | (channel << 4); // 0x80 + channel selection bits
    unsigned char data;

    // Send the command byte
    if (write(fd, &cmd, 1) != 1)
        return -1;

    // Read one byte (8-bit ADC value)
    if (read(fd, &data, 1) != 1)
        return -1;

    return data;
}