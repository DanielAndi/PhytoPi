#include "gpio_io.h"

int main()
{
    gpio_init(); // Initialize GPIO memory mapping

    int pin = 17;               // Example GPIO pin number
    gpio_write(pin, 1);         // Set pin high
    int state = gpio_read(pin); // Read pin state

    gpio_write(pin, 0);     // Set pin low
    state = gpio_read(pin); // Read pin state

    return 0;
}