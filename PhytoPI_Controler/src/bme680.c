/**
 * BME680 driver for PhytoPi
 * Supports Linux IIO (kernel driver) and Bosch BME68x API over I2C
 */
#include "../lib/bme680.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <fcntl.h>
#include <unistd.h>
#include <dirent.h>
#include <stdint.h>
#include <linux/i2c-dev.h>
#include <sys/ioctl.h>

/* Bosch BME68x API */
#include "../libs/bme68x/bme68x.h"

#define BME680_I2C_ADDR  0x76
#define IIO_PATH         "/sys/bus/iio/devices"
#define MAX_PATH         256

static int i2c_fd = -1;
static char iio_device_path[MAX_PATH] = {0};
static int use_iio = 0;
static struct bme68x_dev bme_dev;
static int bme_initialized = 0;

/* ----- IIO path (Linux kernel driver) ----- */
static int read_iio_value(const char *base, const char *attr, float *out)
{
    char path[MAX_PATH];
    snprintf(path, sizeof(path), "%s/%s", base, attr);
    int fd = open(path, O_RDONLY);
    if (fd < 0)
        return -1;

    char buf[32];
    ssize_t n = read(fd, buf, sizeof(buf) - 1);
    close(fd);
    if (n <= 0)
        return -1;

    buf[n] = '\0';
    *out = (float)atof(buf);
    return 0;
}

static int find_bme680_iio(void)
{
    DIR *dir = opendir(IIO_PATH);
    if (!dir)
        return -1;

    struct dirent *ent;
    while ((ent = readdir(dir)) != NULL)
    {
        if (ent->d_name[0] == '.')
            continue;

        char path[MAX_PATH];
        snprintf(path, sizeof(path), "%s/%s/name", IIO_PATH, ent->d_name);
        int fd = open(path, O_RDONLY);
        if (fd < 0)
            continue;

        char name[64];
        ssize_t n = read(fd, name, sizeof(name) - 1);
        close(fd);
        if (n <= 0)
            continue;

        name[n] = '\0';
        for (char *p = name; *p; p++)
            if (*p == '\n') { *p = '\0'; break; }

        if (strstr(name, "bme680") != NULL)
        {
            snprintf(iio_device_path, sizeof(iio_device_path), "%s/%s", IIO_PATH, ent->d_name);
            closedir(dir);
            return 0;
        }
    }
    closedir(dir);
    return -1;
}

/* ----- Bosch API I2C interface ----- */
static BME68X_INTF_RET_TYPE bme68x_linux_i2c_read(uint8_t reg_addr, uint8_t *reg_data, uint32_t len, void *intf_ptr)
{
    int fd = *(int *)intf_ptr;
    if (fd < 0)
        return BME68X_E_COM_FAIL;

    if (write(fd, &reg_addr, 1) != 1)
        return BME68X_E_COM_FAIL;
    if ((int)read(fd, reg_data, len) != (int)len)
        return BME68X_E_COM_FAIL;

    return BME68X_OK;
}

static BME68X_INTF_RET_TYPE bme68x_linux_i2c_write(uint8_t reg_addr, const uint8_t *reg_data, uint32_t len, void *intf_ptr)
{
    int fd = *(int *)intf_ptr;
    if (fd < 0)
        return BME68X_E_COM_FAIL;

    uint8_t buf[256];
    if (len + 1 > sizeof(buf))
        return BME68X_E_INVALID_LENGTH;

    buf[0] = reg_addr;
    memcpy(&buf[1], reg_data, len);

    if ((int)write(fd, buf, len + 1) != (int)(len + 1))
        return BME68X_E_COM_FAIL;

    return BME68X_OK;
}

static void bme68x_delay_us(uint32_t period, void *intf_ptr)
{
    (void)intf_ptr;
    usleep(period);
}

int bme680_init(void)
{
    /* Try IIO first (Linux kernel driver) */
    if (find_bme680_iio() == 0)
    {
        use_iio = 1;
        fprintf(stderr, "BME680: Using IIO at %s\n", iio_device_path);
        return 0;
    }
    fprintf(stderr, "BME680: No IIO device found in %s\n", IIO_PATH);

    /* Fallback: I2C with Bosch API */
    i2c_fd = open("/dev/i2c-1", O_RDWR);
    if (i2c_fd < 0)
    {
        fprintf(stderr, "BME680: Cannot open /dev/i2c-1 (errno=%d). Check: i2c enabled, user in i2c group.\n", errno);
        return -1;
    }

    if (ioctl(i2c_fd, I2C_SLAVE, BME680_I2C_ADDR) < 0)
    {
        fprintf(stderr, "BME680: I2C slave 0x%02x not responding. Try 0x77 if SDO is high. Run: i2cdetect -y 1\n", BME680_I2C_ADDR);
        close(i2c_fd);
        i2c_fd = -1;
        return -1;
    }

    memset(&bme_dev, 0, sizeof(bme_dev));
    bme_dev.intf = BME68X_I2C_INTF;
    bme_dev.read = bme68x_linux_i2c_read;
    bme_dev.write = bme68x_linux_i2c_write;
    bme_dev.delay_us = bme68x_delay_us;
    bme_dev.intf_ptr = &i2c_fd;
    bme_dev.amb_temp = 25;

    if (bme68x_init(&bme_dev) != BME68X_OK)
    {
        fprintf(stderr, "BME680: Bosch API init failed. Check wiring (SDA=GPIO2, SCL=GPIO3, VCC, GND).\n");
        close(i2c_fd);
        i2c_fd = -1;
        return -1;
    }

    bme_initialized = 1;
    use_iio = 0;
    fprintf(stderr, "BME680: I2C init OK (addr 0x%02x)\n", BME680_I2C_ADDR);
    return 0;
}

int bme680_read(bme680_data_t *data)
{
    if (!data)
        return -1;

    memset(data, 0, sizeof(*data));
    data->valid = 0;

    if (use_iio)
    {
        float temp_c = 0, hum = 0, press_kpa = 0, gas_ohm = 0;
        int ok = 1;

        if (read_iio_value(iio_device_path, "in_temp_input", &temp_c) == 0)
            data->temperature = temp_c / 1000.0f;
        else
            ok = 0;

        if (read_iio_value(iio_device_path, "in_humidityrelative_input", &hum) == 0)
            data->humidity = hum / 1000.0f;
        else
            ok = 0;

        if (read_iio_value(iio_device_path, "in_pressure_input", &press_kpa) == 0)
            data->pressure = press_kpa;
        else
            ok = 0;

        if (read_iio_value(iio_device_path, "in_resistance_input", &gas_ohm) == 0)
            data->gas_resistance = gas_ohm / 1000.0f;
        else
            data->gas_resistance = 0;

        data->valid = ok ? 1 : 0;
        return ok ? 0 : -1;
    }

    /* Bosch API path */
    if (!bme_initialized || i2c_fd < 0)
        return -1;

    struct bme68x_conf conf;
    struct bme68x_heatr_conf heatr_conf;
    struct bme68x_data bme_data;
    uint8_t n_fields;
    uint32_t del_period;

    conf.filter = BME68X_FILTER_OFF;
    conf.odr = BME68X_ODR_NONE;
    conf.os_hum = BME68X_OS_1X;
    conf.os_pres = BME68X_OS_1X;
    conf.os_temp = BME68X_OS_1X;

    if (bme68x_set_conf(&conf, &bme_dev) != BME68X_OK)
        return -1;

    heatr_conf.enable = BME68X_DISABLE;
    heatr_conf.heatr_temp = 300;
    heatr_conf.heatr_dur = 100;
    if (bme68x_set_heatr_conf(BME68X_FORCED_MODE, &heatr_conf, &bme_dev) != BME68X_OK)
        return -1;

    if (bme68x_set_op_mode(BME68X_FORCED_MODE, &bme_dev) != BME68X_OK)
        return -1;

    del_period = bme68x_get_meas_dur(BME68X_FORCED_MODE, &conf, &bme_dev);
    bme_dev.delay_us(del_period, bme_dev.intf_ptr);

    if (bme68x_get_data(BME68X_FORCED_MODE, &bme_data, &n_fields, &bme_dev) != BME68X_OK)
        return -1;

    if (n_fields == 0)
        return -1;

#ifdef BME68X_USE_FPU
    data->temperature = bme_data.temperature;
    data->humidity = bme_data.humidity;
    data->pressure = bme_data.pressure / 100.0f;  /* Pa to hPa */
    data->gas_resistance = bme_data.gas_resistance / 1000.0f;  /* Ohm to kOhm */
#else
    data->temperature = (float)bme_data.temperature / 100.0f;
    data->humidity = (float)bme_data.humidity / 1000.0f;
    data->pressure = (float)bme_data.pressure / 100000.0f;  /* Pa to hPa */
    data->gas_resistance = (float)bme_data.gas_resistance / 1000.0f;
#endif

    data->valid = 1;
    return 0;
}

void bme680_cleanup(void)
{
    if (i2c_fd >= 0)
    {
        close(i2c_fd);
        i2c_fd = -1;
    }
    bme_initialized = 0;
}
