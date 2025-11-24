#include "../lib/gpio.h"

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
 * Read temperature and humidity from DHT22 sensor via kernel interface.
 * Returns 0 on success, -1 on failure.
 */
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