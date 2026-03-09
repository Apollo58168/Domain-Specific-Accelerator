# ======================================================================
#  This Makefile builds an application *.elf for Aquila.
#
#  Chun-Jen Tsai, Aug/28/2025
# ======================================================================

# ======================================================================
# Without FPU
RISCV_ABI = -march=rv32ima_zicsr_zifencei -mabi=ilp32
GCC_LIB = rv32im/ilp32
# With FPU
# RISCV_ABI = -march=rv32imad_zicsr_zifencei -mabi=ilp32d
# ======================================================================

CROSS = riscv32-unknown-elf
CCPATH = $(RISCV)/bin

CC = $(CCPATH)/$(CROSS)-gcc
LD = $(CCPATH)/$(CROSS)-ld
AR = $(CCPATH)/$(CROSS)-ar
OD = $(CCPATH)/$(CROSS)-objdump
SP = $(CCPATH)/$(CROSS)-strip

GCCVERSION = $(shell $(CC) --version | grep gcc | sed 's/^.* //g')

LIBC = ../elibc
LIBC_OBJS = $(LIBC)/crt0.o $(LIBC)/stdio.o $(LIBC)/stdlib.o $(LIBC)/string.o $(LIBC)/time.o $(LIBC)/uart.o

LIB_FILE = ../elibc/fileio
LIB_FILE_OBJS = $(LIB_FILE)/sd.o $(LIB_FILE)/spi.o $(LIB_FILE)/fat32.o

CCFLAGS = -Wall -O3 -I$(LIBC) -I$(LIB_FILE) -fno-builtin -mstrict-align $(RISCV_ABI)
LDFLAGS = -L. -Map=$*.map
LD_GCC_LIB = -L$(RISCV)/lib/gcc/riscv32-unknown-elf/$(GCCVERSION)/$(GCC_LIB) -lgcc
CNN = ./inc_cnn

OCFLAGS = -O binary
ODFLAGS = -d

PROJ = cnn_ocr
OBJS = $(PROJ).o file_read.o
HDRS = $(CNN)/activation_function.h $(CNN)/average_pooling_layer.h $(CNN)/config.h \
       $(CNN)/convolutional_layer.h $(CNN)/layer.h $(CNN)/network.h $(CNN)/dummy_head_layer.h \
       $(CNN)/list.h $(CNN)/util.h $(CNN)/fully_connected_layer.h file_read.h

all:
	make $(PROJ).elf

clean:
	rm -f *.elf *.objdump *.map *.o *.a

%.o: %.c $(HDRS)
	$(CC) -I$(CNN) $(CCFLAGS) -c $< -o $@

libelibc.a : $(LIBC_OBJS) $(LIB_FILE_OBJS)
	$(AR) r libelibc.a $(LIBC_OBJS) $(LIB_FILE_OBJS)
	rm $^

%.elf: $(OBJS) libelibc.a
	$(LD) $(LDFLAGS) -T$(PROJ).ld $(OBJS) -lelibc $(LD_GCC_LIB) -o $@
	$(OD) $(ODFLAGS) $@ > $*.objdump
	$(SP) -g $@
	rm $^

