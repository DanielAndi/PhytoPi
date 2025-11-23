#include "../lib/gpio.h"

static volatile int edge_level = -1;    // -1 = no edge, 0 = falling, 1 = rising
static volatile uint32_t edge_tick = 0; // Tick where edge occurred

/*
 * Initialize GPIO library
 */
int gpio_init()
{
    if (gpioInitialise() == -1)
    {
        return -1;
    }
    return 0;
}

/*
 * Simply captures the last edge level and tick it occured at asynchronously
 */
void gpio_edge_alert(int pin, int level, uint32_t tick)
{
    edge_level = level;
    edge_tick = tick;
}

/*
 * Wait for edge on pin to reach specified level or timeout
 */
int gpio_edge_wait(int pin, int level, __uint32_t timeout)
{
    uint32_t startTick = gpioTick();

    edge_level = -1; // Reset edge level
    edge_tick = 0;   // Reset edge tick

    while (1)
    {
        if (edge_level == level)
        {
            return edge_tick; // Return the tick when edge occurred
        }
        if (gpioTick() - startTick >= timeout)
        {
            return -1; // Timeout
        }
        gpioDelay(2); // Small delay to prevent busy waiting
    }
}

/*
 * Configure pin as input with pull-up and edge detection
 */
void gpio_config_input(int pin)
{
    gpioSetMode(pin, PI_INPUT);
    gpioSetPullUpDown(pin, PI_PUD_UP);      // Enable Pi's internal pull-up resistor
    gpioSetAlertFunc(pin, gpio_edge_alert); // Set alert function for edge detection
}

/*
 * Configure pin as output
 */
void gpio_config_output(int pin)
{
    gpioSetMode(pin, PI_OUTPUT);
}

/*
 * Cleanup GPIO library
 */
int gpio_cleanup()
{
    gpioTerminate();
    return 0;
}