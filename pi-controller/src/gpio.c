#include "../lib/gpio.h"
#include <stdint.h>
#include <time.h>
#include <sched.h>

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
        // Busy-wait for precise timing
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

    // Request line as OUTPUT with PULL UP (initial state High)
    struct gpiod_line_request_config config;
    config.consumer = "dht11";
    config.request_type = GPIOD_LINE_REQUEST_DIRECTION_OUTPUT;
    config.flags = GPIOD_LINE_REQUEST_FLAG_BIAS_PULL_UP;
    
    if (gpiod_line_request(dht_line, &config, 1) < 0)
    {
        gpiod_chip_close(dht_chip);
        return -1;
    }

    // Boost process priority to real-time to minimize preemption during critical timing
    struct sched_param param;
    param.sched_priority = sched_get_priority_max(SCHED_FIFO);
    int old_policy = sched_getscheduler(0);
    struct sched_param old_param;
    sched_getparam(0, &old_param);
    
    // Try to set real-time priority (might fail if not root, but worth trying)
    sched_setscheduler(0, SCHED_FIFO, &param);

    // Start signal: pull low for 20ms
    gpiod_line_set_value(dht_line, 0);
    usleep(20000);  // 20ms - DHT11 requires at least 18ms

    // Switch to input mode - pull-up will pull line high
    // This avoids the overhead of "set high + wait + set input"
    // Using set_direction avoids releasing the line
    gpiod_line_set_direction_input(dht_line);

    // Wait for response signal (Low)
    // After we release (switch to input), line goes High (pull-up).
    // Sensor waits 20-40us then pulls Low.
    if (wait_for_level(dht_line, 0, 200) < 0)
    {
        // Restore priority before returning
        sched_setscheduler(0, old_policy, &old_param);
        gpiod_line_release(dht_line);
        gpiod_chip_close(dht_chip);
        return -2; // No response (low)
    }
    
    // Wait for response signal (High) - 80us
    if (wait_for_level(dht_line, 1, 200) < 0)
    {
        sched_setscheduler(0, old_policy, &old_param);
        gpiod_line_release(dht_line);
        gpiod_chip_close(dht_chip);
        return -3; // No response (high)
    }
    
    // Wait for start of first bit (Low) - 80us
    if (wait_for_level(dht_line, 0, 200) < 0)
    {
        sched_setscheduler(0, old_policy, &old_param);
        gpiod_line_release(dht_line);
        gpiod_chip_close(dht_chip);
        return -4; // Data read timeout
    }

    // Read 40 bits of data
    for (int i = 0; i < 40; i++)
    {
        // Wait for high pulse (start of bit's high part)
        // We are currently Low (50us start of bit). Wait for it to go High.
        if (wait_for_level(dht_line, 1, 100) < 0)
        {
            sched_setscheduler(0, old_policy, &old_param);
            gpiod_line_release(dht_line);
            gpiod_chip_close(dht_chip);
            return -5;  // Timeout waiting for high
        }
        
        // Measure duration of High pulse
        // If > 40us, it's a '1', else '0'
        // This waits for it to go Low (start of next bit)
        int high_duration = wait_for_level(dht_line, 0, 100);
        if (high_duration < 0)
        {
            sched_setscheduler(0, old_policy, &old_param);
            gpiod_line_release(dht_line);
            gpiod_chip_close(dht_chip);
            return -6; // Timeout waiting for low
        }

        data[i / 8] = (data[i / 8] << 1) | (high_duration > 40 ? 1 : 0);
    }

    // Restore priority
    sched_setscheduler(0, old_policy, &old_param);

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