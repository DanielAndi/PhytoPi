CC = gcc
CFLAGS = -Wall -O2 -Ilib
LDFLAGS = -lpigpio -lpthread -lrt -lsqlite3

SRC = src/main.c src/gpio.c src/dht22.c src/sql.c
OBJ = $(SRC:.c=.o)

TARGET = main

all: $(TARGET)

$(TARGET): $(OBJ)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJ) $(TARGET)
