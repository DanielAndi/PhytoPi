#include "../lib/gpio_io.h"

int main()
{
    peri_init(); // Initialize peripheral memory mapping

    uint32_t pin = 26;        // Example GPIO pin number
    uint32_t func_select = 5; // Example function select value (GPIO function)

    gpio_func_select(pin, func_select); // Set GPIO function for the pin
    pad_set(pin, 0x10);                 // Ensure pad is set for output
    rio_set_output(pin);                // Configure the pin as output

    while (1)
    {
        write_gpio(pin, 0); // Set pin low
        sleep(1);
        write_gpio(pin, 1); // Initialize pin to high
        sleep(1);
    }

    return 0;
}