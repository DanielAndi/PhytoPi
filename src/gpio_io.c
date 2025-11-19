#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include "gpio_io.h"
#include <stdint.h>

/*
   From the RP1 datasheet I got the byte offsets for each control and set register for each GPIO pin. However, we need to access them as 32-bit words because when we initialize the GPIO with gpio_init(), we map the peripheral into a 32-bit pointer. This means we divide the byte offset by 4, giving us the word offset which we use to index into the gpio pointer in the macros below.
*/

// Macros for accessing control and set registers for GPIO pins
#define GPIO_SET_OFFSET(pin_num) ((pin_num) * 2)         // Set register offset for pin
#define GPIO_CONTROL_OFFSET(pin_num) ((pin_num) * 2 + 1) // Control register offset for pin

#define GPIO_SET(pin_num) (*(gpio + GPIO_SET_OFFSET(pin_num)))         // Set register for pin
#define GPIO_CONTROL(pin_num) (*(gpio + GPIO_CONTROL_OFFSET(pin_num))) // Control register for pin

// I'm using a bit mask here to set the output bit to 0 and leave the other bits unchanged
// We negate 1 because 1 in binary is 00000001 and we want to clear just that bit.
#define GPIO_CLEAR(pin_num) (*(gpio + GPIO_CONTROL_OFFSET(pin_num)) &= ~(1)) // Clear register for pin

static volatile uint32_t *gpio; // Pointer to  a portion of GPIO memory

void gpio_init(void)
{
    int fd;         // File descriptor for /dev/mem
    char *gpio_map; // Pointer to mapped GPIO memory

    fd = open("/dev/mem", O_RDWR | O_SYNC); // Opens /dev/mem for memory access
    if (fd < 0)
    {
        perror("Failed to open /dev/mem");
        exit(1); // Exit if can't open dev/mem
    }

    // Kernel picks a virtual address that maps to physical GPIO location
    gpio_map = mmap(
        NULL,                   // Any address in our space will do
        BLOCK_SIZE,             // # of bytes to map
        PROT_READ | PROT_WRITE, // Enable reading & writing to mapped memory
        MAP_SHARED,             // Shared with other processes
        fd,                     // File descriptor to map
        GPIO_BASE               // Offset to GPIO peripheral
    );

    if (gpio_map == MAP_FAILED)
    {
        perror("Failed to map GPIO memory");
        close(fd);
        exit(1); // Exit if mmap fails
    }

    close(fd);                                // No longer need /dev/mem after mmap
    gpio = (volatile unsigned int *)gpio_map; // Assign mapped memory to gpio pointer
}

gpio_config(int pin_num, int func_select)
{
}

void inline gpio_write(int pin_num, int value)
{
    // If driving line high, use GPIO_SET, otherwise just use GPIO_CLEAR
    if (value)
    {
        GPIO_SET(pin_num) |= 1; // Set the output bit to 1
    }
    else
    {
        GPIO_CLEAR(pin_num); // Clear the output bit to 0
    }
}

inline int gpio_read(int pin_num)
{
    return GPIO_SET(pin_num) & 1; // Returns rightmost (output) bit (0 or 1)
}