#include "../lib/gpio.h"
#include <stdint.h>
#include <time.h>
#include <string.h>
#include <fcntl.h>
#include <stdio.h>
#include <unistd.h>
#include <sys/ioctl.h>

static struct gpiod_chip *chip = NULL;
static struct gpiod_line *line = NULL;
static struct gpiod_line *line_lights = NULL;
static struct gpiod_line *line_pump = NULL;
static struct gpiod_line *line_water_level = NULL;
static int gpio_initialized = 0;
static int lights_initialized = 0;
static int pump_initialized = 0;
static int water_level_initialized = 0;
static int pwm_initialized = 0;

#define PWM_CHIP "/sys/class/pwm/pwmchip0"
#define PWM_PERIOD_NS 40000  /* 25kHz = 40us period */

/*
 * Initialize GPIO library (opens chip, gets line for given pin)
 */
int gpio_init(int pin)
{
    if (!chip)
    {
        chip = gpiod_chip_open_by_name("gpiochip0");
        if (!chip)
            return -1;
    }
    if (line)
        gpiod_line_release(line);
    line = gpiod_chip_get_line(chip, pin);
    if (!line)
        return -1;
    gpio_initialized = 1;
    return 0;
}

/*
 * Configure pin as input
 */
int gpio_config_input(int pin)
{
    (void)pin;
    return gpiod_line_request_input(line, "gpio_app");
}

/*
 * Configure pin as output
 */
int gpio_config_output(int pin)
{
    (void)pin;
    return gpiod_line_request_output(line, "gpio_app", 0);
}

/*
 * Write value to GPIO pin (uses current line)
 */
int gpio_write(int value)
{
    return line ? gpiod_line_set_value(line, value) : -1;
}

/*
 * Read value from GPIO pin
 */
int gpio_read(void)
{
    return line ? gpiod_line_get_value(line) : -1;
}

/*
 * Cleanup GPIO library
 */
int gpio_cleanup(void)
{
    if (line_lights) { gpiod_line_release(line_lights); line_lights = NULL; }
    if (line_pump) { gpiod_line_release(line_pump); line_pump = NULL; }
    if (line_water_level) { gpiod_line_release(line_water_level); line_water_level = NULL; }
    if (line) { gpiod_line_release(line); line = NULL; }
    if (chip) { gpiod_chip_close(chip); chip = NULL; }
    gpio_initialized = 0;
    lights_initialized = 0;
    pump_initialized = 0;
    water_level_initialized = 0;
    pwm_initialized = 0;
    return 0;
}

/*
 * -------------------------------
 * LIGHT CONTROL (24V MOSFET ON GPIO17)
 *-------------------------------
 */
int lights_init(void)
{
    if (lights_initialized)
        return 0;
    if (!chip)
        chip = gpiod_chip_open_by_name("gpiochip0");
    if (!chip)
        return -1;
    line_lights = gpiod_chip_get_line(chip, LIGHTS_PIN);
    if (!line_lights)
        return -1;
    if (gpiod_line_request_output(line_lights, "phytopi_lights", 0) != 0)
    {
        gpiod_line_release(line_lights);
        line_lights = NULL;
        return -1;
    }
    lights_initialized = 1;
    return 0;
}

int lights_set(int on)
{
    if (!lights_initialized && lights_init() != 0)
        return -1;
    return gpiod_line_set_value(line_lights, on ? 1 : 0);
}

/*
 * -------------------------------
 * PUMP CONTROL (MOSFET ON GPIO22)
 *-------------------------------
 */
int pump_init(void)
{
    if (pump_initialized)
        return 0;
    if (!chip)
        chip = gpiod_chip_open_by_name("gpiochip0");
    if (!chip)
        return -1;
    line_pump = gpiod_chip_get_line(chip, PUMP_PIN);
    if (!line_pump)
        return -1;
    if (gpiod_line_request_output(line_pump, "phytopi_pump", 0) != 0)
    {
        gpiod_line_release(line_pump);
        line_pump = NULL;
        return -1;
    }
    pump_initialized = 1;
    return 0;
}

int pump_set(int on)
{
    if (!pump_initialized && pump_init() != 0)
        return -1;
    return gpiod_line_set_value(line_pump, on ? 1 : 0);
}

/*
 * -------------------------------
 * PWM FAN CONTROL (GPIO12, GPIO13 via sysfs)
 *-------------------------------
 */
static int pwm_export(int channel)
{
    char path[128];
    snprintf(path, sizeof(path), "%s/export", PWM_CHIP);
    int fd = open(path, O_WRONLY);
    if (fd < 0)
        return -1;
    char buf[8];
    snprintf(buf, sizeof(buf), "%d", channel);
    int ret = (write(fd, buf, strlen(buf)) > 0) ? 0 : -1;
    close(fd);
    return ret;
}

static int pwm_set(int channel, int period_ns, int duty_ns)
{
    char path[128];
    snprintf(path, sizeof(path), "%s/pwm%d/period", PWM_CHIP, channel);
    int fd = open(path, O_WRONLY);
    if (fd < 0)
        return -1;
    char buf[32];
    snprintf(buf, sizeof(buf), "%d", period_ns);
    write(fd, buf, strlen(buf));
    close(fd);

    snprintf(path, sizeof(path), "%s/pwm%d/duty_cycle", PWM_CHIP, channel);
    fd = open(path, O_WRONLY);
    if (fd < 0)
        return -1;
    snprintf(buf, sizeof(buf), "%d", duty_ns);
    write(fd, buf, strlen(buf));
    close(fd);

    snprintf(path, sizeof(path), "%s/pwm%d/enable", PWM_CHIP, channel);
    fd = open(path, O_WRONLY);
    if (fd < 0)
        return -1;
    write(fd, duty_ns > 0 ? "1" : "0", 1);
    close(fd);
    return 0;
}

int fans_init(void)
{
    if (pwm_initialized)
        return 0;
    if (pwm_export(0) != 0 && pwm_export(0) != 0)  /* May fail if already exported */
        ;
    if (pwm_export(1) != 0 && pwm_export(1) != 0)
        ;
    pwm_initialized = 1;
    return 0;
}

int fans_set_speed(int fan_id, int duty_percent)
{
    if (!pwm_initialized && fans_init() != 0)
        return -1;
    if (fan_id != 1 && fan_id != 2)
        return -1;
    if (duty_percent < 0) duty_percent = 0;
    if (duty_percent > 100) duty_percent = 100;
    int ch = (fan_id == 1) ? 0 : 1;
    int duty_ns = (PWM_PERIOD_NS * duty_percent) / 100;
    return pwm_set(ch, PWM_PERIOD_NS, duty_ns);
}

int fans_set_both(int duty_percent)
{
    int r1 = fans_set_speed(1, duty_percent);
    int r2 = fans_set_speed(2, duty_percent);
    return (r1 == 0 && r2 == 0) ? 0 : -1;
}

/*
 * -------------------------------
 * PHOTOELECTRIC WATER LEVEL (GPIO26 - frequency input)
 * CQRobot: 20Hz = no liquid, up to 400Hz at Level 4. Low freq = low water.
 *-------------------------------
 */
int read_photoelectric_water_level(int *frequency_hz)
{
    if (!frequency_hz)
        return -1;
    if (!chip)
        chip = gpiod_chip_open_by_name("gpiochip0");
    if (!chip)
        return -1;

    if (!line_water_level)
    {
        line_water_level = gpiod_chip_get_line(chip, WATER_LEVEL_PIN);
        if (!line_water_level)
            return -1;
        if (gpiod_line_request_input(line_water_level, "phytopi_water") != 0)
        {
            gpiod_line_release(line_water_level);
            line_water_level = NULL;
            return -1;
        }
        water_level_initialized = 1;
    }

    /* Count rising edges over 100ms to get frequency */
    struct timespec start, now;
    clock_gettime(CLOCK_MONOTONIC, &start);
    int last = gpiod_line_get_value(line_water_level);
    int count = 0;
    const long timeout_ns = 100000000;  /* 100ms */

    while (1)
    {
        clock_gettime(CLOCK_MONOTONIC, &now);
        long elapsed = (now.tv_sec - start.tv_sec) * 1000000000L + (now.tv_nsec - start.tv_nsec);
        if (elapsed >= timeout_ns)
            break;

        int val = gpiod_line_get_value(line_water_level);
        if (val == 1 && last == 0)
            count++;
        last = val;
        usleep(100);
    }

    *frequency_hz = count * 10;  /* 100ms -> 10 samples/sec for Hz */
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