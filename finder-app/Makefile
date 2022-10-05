
ifeq ($(CROSS_COMPILE), )
CROSS_COMPILE=
endif

CC := $(CROSS_COMPILE)gcc
LD := $(CROSS_COMPILE)ld
AS := $(CROSS_COMPILE)as
CPP := $(CROSS_COMPILE)cpp

CFLAGS= -Wall -pedantic 
TARGET=writer

.PHONY: $(TARGET)

.PHONY: build
build: $(TARGET)

.PHONY: $(TARGET)
$(TARGET): $(TARGET).c 
	$(CC) $(CFLAGS) $(CPPFLAGS) -o $@ $<


.PHONY: clean
clean: 
	rm -f $(TARGET) *.o
