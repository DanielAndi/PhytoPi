#include "../lib/gpio_io.h"

uint32_t *PERIbase;
uint32_t *GPIObase;
uint32_t *RIObase;
uint32_t *PADbase;
uint32_t *pad_reg;

void peri_init(void)
{
    int fd = open("/dev/mem", O_RDWR | O_SYNC); // Opens /dev/mem for memory access
    if (fd < 0)
    {
        perror("Failed to open /dev/mem");
        exit(1); // Exit if can't open dev/mem
    }

    // Kernel picks a virtual address that maps to physical GPIO location
    uint32_t *map = mmap(
        NULL,                   // Any address in our space will do
        BLOCK_SIZE,             // # of bytes to map
        PROT_READ | PROT_WRITE, // Enable reading & writing to mapped memory
        MAP_SHARED,             // Shared with other processes
        fd,                     // File descriptor to map
        0x1f00000000            // Peripheral base address
    );

    if (map == MAP_FAILED)
    {
        perror("Failed to map GPIO memory");
        close(fd);
        exit(1); // Exit if mmap fails
    }

    close(fd);                         // No longer need /dev/mem after mmap
    PERIbase = map;                    // Assign mapped memory to peripheral base
    GPIObase = PERIbase + 0xD0000 / 4; // GPIO base offset
    RIObase = PERIbase + 0xE0000 / 4;  // RIO base offset
    PADbase = PERIbase + 0xF0000 / 4;  // PAD base offset
    pad_reg = PADbase + 1;             // Specific PAD register
}

#define GPIO ((GPIOregs *)GPIObase)
#define rio ((rioregs *)RIObase)
#define rioXOR ((rioregs *)(RIObase + 0x1000 / 4))
#define rioSET ((rioregs *)(RIObase + 0x2000 / 4))
#define rioCLR ((rioregs *)(RIObase + 0x3000 / 4))

void gpio_func_select(uint32_t pin, uint32_t func)
{
    GPIO[pin].ctrl = func;
}

void pad_set(uint32_t pin, uint32_t value)
{
    pad_reg[pin] = value;
}

void rio_set_output(uint32_t pin)
{
    rioSET->OE = (1 << pin);  // Set pin as output
    rioSET->Out = (1 << pin); // Initialize output to high
}

void write_gpio(uint32_t pin, uint32_t value)
{
    if (value)
    {
        rioSET->Out = (1 << pin); // Set pin high
    }
    else
    {
        rioCLR->Out = (1 << pin); // Set pin low
    }
}