#ifndef GPIO_IO_H
#define GPIO_IO_H

#include <stdint.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

#define BLOCK_SIZE (64 * 1024 * 1024) // 64MB block size for memory mapping

// GPIO registers are split into status (read-only) and control (read/write)
typedef struct
{
    uint32_t status;
    uint32_t ctrl;
} GPIOregs;

// RIO registers for output/input operations on GPIO pins
typedef struct
{
    uint32_t Out;    // Output register
    uint32_t OE;     // Output Enable
    uint32_t In;     // Input register
    uint32_t InSync; // Input Synchronization (not used for us)
} rioregs;

/*------------------------
FUNCTION PROTOTYPES
--------------------------*/
void peri_init(void);
void gpio_func_select(uint32_t pin, uint32_t func);
void pad_set(uint32_t pin, uint32_t value);
void rio_set_output(uint32_t pin);
void write_gpio(uint32_t pin, uint32_t value);

#endif // GPIO_IO_H
