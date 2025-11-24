CC = gcc
CFLAGS = -Wall -O2 -Ilib
LDFLAGS = -lgpiod -lpthread -lrt -lsqlite3 -lcurl -ljson-c
BINDIR = bin

SRC = src/main.c src/gpio.c src/sql.c src/supabase.c
OBJ = $(SRC:.c=.o)

TARGET = $(BINDIR)/phytopi

all: $(TARGET)

$(TARGET): $(OBJ)
	mkdir -p $(BINDIR)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)

%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJ) $(TARGET) ${BINDIR}/*
