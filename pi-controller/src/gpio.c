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
    uint64_t timeout_64 = (uint64_t)timeout_us;
    
    while (gpiod_line_get_value(line) != level)
    {
        uint64_t elapsed = micros_now() - start;
        if (elapsed > timeout_64)
            return -1;
        // Small delay to avoid busy-waiting
        usleep(1);
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
    usleep(50000);  // 50ms delay to ensure clean state and let sensor stabilize
    
    gpiod_line_request_output(dht_line, "dht11", 1);
    usleep(1000);
    gpiod_line_set_value(dht_line, 0);
    usleep(20000);  // 20ms - DHT11 requires at least 18ms
    gpiod_line_set_value(dht_line, 1);
    usleep(40);     // 40us - DHT11 requires 20-40us
    gpiod_line_release(dht_line);
    
    // Delay before switching to input mode to ensure signal is stable
    usleep(50);

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
    // Further increased timeouts for more reliable reading
    for (int i = 0; i < 40; i++)
    {
        // Wait for high pulse (start of bit)
        int wait_high = wait_for_level(dht_line, 1, 300);  // Increased to 300us for more tolerance
        if (wait_high < 0)
        {
            gpiod_line_release(dht_line);
            gpiod_chip_close(dht_chip);
            return -5;  // Timeout waiting for high
        }
        
        // Wait for low pulse (end of bit) - this is where error -6 occurs
        int high_duration = wait_for_level(dht_line, 0, 300);  // Increased to 300us
        if (high_duration < 0)
        {
            gpiod_line_release(dht_line);
            gpiod_chip_close(dht_chip);
            // Error -6: Timeout waiting for low after high
            // This usually means the sensor stopped responding mid-transmission
            return -6;
        }

        // If high duration > 40us, it's a '1', otherwise '0'
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

    // ADS7830 Command Byte: SD C2 C1 C0 PD1 PD0 X X
    // SD (Single-Ended/Differential) = 1 for Single-Ended
    // PD1, PD0 = 0, 1 (Internal Reference OFF, A/D ON) => 0x04
    // Channel Selection (C2, C1, C0) mapping:
    // CH0: 000 (0x0) -> 0x84
    // CH1: 100 (0x4) -> 0xC4
    // CH2: 001 (0x1) -> 0x94
    // CH3: 101 (0x5) -> 0xD4
    // CH4: 010 (0x2) -> 0xA4
    // CH5: 110 (0x6) -> 0xE4
    // CH6: 011 (0x3) -> 0xB4
    // CH7: 111 (0x7) -> 0xF4

    unsigned char channel_map[] = {
        0x84, // CH0
        0xC4, // CH1
        0x94, // CH2
        0xD4, // CH3
        0xA4, // CH4
        0xE4, // CH5
        0xB4, // CH6
        0xF4  // CH7
    };

    unsigned char cmd = channel_map[channel];
    unsigned char data;

    // Send the command byte
    if (write(fd, &cmd, 1) != 1)
        return -1;

    // Read one byte (8-bit ADC value)
    if (read(fd, &data, 1) != 1)
        return -1;

    return data;
}