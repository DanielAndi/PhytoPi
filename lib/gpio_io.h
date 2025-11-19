// Peripheral base for Raspberry Pi 5
#define PERIPHERAL_BASE 0x1F000000
// Peripheral base for Raspberry Pi 5 + offset to GPIO registers
#define GPIO_BASE 0x400D0000

#define BLOCK_SIZE 0x1000 // 4 KB, this is the default page size for Linux

void gpio_init(void);
