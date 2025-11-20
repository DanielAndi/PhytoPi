#include "gpio_io.h"

int main()
{
    gpio_init();        // Initialize GPIO memory mapping
    gpio_config(26, 0); // Configure GPIO pin 5 with function select 0

    while (1)
    {
        sleep(1);
        gpio_write(26, 1);         // Set GPIO pin 5 high
        int value = gpio_read(26); // Read the value of GPIO pin 5
        printf("GPIO pin 26 value: %d\n", value);
        sleep(2);          // Wait for 1 second
        gpio_write(26, 0); // Set GPIO pin 5 low
    }

    return 0;
}