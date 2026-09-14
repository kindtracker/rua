CC = cc
CFLAGS = -O2 -Wall -Wextra
LIBS = -lm

SRC = src
BUILD = build
OUT = $(BUILD)/rua

CSRC = $(shell find $(SRC) -type f -name '*.c')
COBJ = $(patsubst %.c,$(BUILD)/%.o,$(CSRC))

all: clean compile

clean:
	mkdir -p $(BUILD)
	rm -rf $(BUILD)/*

compile: $(OUT)

run:
	./$(OUT)

$(OUT): $(COBJ)
	$(CC) $(CFLAGS) -o $(OUT) $(COBJ) $(LIBS)

$(BUILD)/%.o : %.c
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) -c -o $@ $<
