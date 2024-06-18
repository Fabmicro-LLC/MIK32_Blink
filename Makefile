PROJECT_NAME = blink
PROJECT_DIR = .
PROJECT_BUILD_DIR = $(PROJECT_DIR)/build
PROJECT_SRC_DIR = $(PROJECT_DIR)/src

#
TOOLCHAIN_DIR = /opt/mik32
CROSS = /opt/riscv64/bin/riscv64-unknown-elf-
MIK32_UPLOADER_DIR = /opt/mik32/mik32-uploader
CC = $(CROSS)gcc
LD = $(CROSS)ld
STRIP = $(CROSS)strip
OBJCOPY = $(CROSS)objcopy
OBJDUMP = $(CROSS)objdump

MARCH = rv32imc
MABI = ilp32

#
SHARED_DIR = $(TOOLCHAIN_DIR)/mik32v2-shared
HAL_DIR = $(TOOLCHAIN_DIR)/hal
LDSCRIPT = $(SHARED_DIR)/ldscripts/eeprom.ld
RUNTIME = $(SHARED_DIR)/runtime/crt0.S

INC += -I $(SHARED_DIR)/include
INC += -I $(SHARED_DIR)/periphery
INC += -I $(SHARED_DIR)/runtime
INC += -I $(SHARED_DIR)/libs
INC += -I $(HAL_DIR)/core/Include
INC += -I $(HAL_DIR)/peripherals/Include
INC += -I $(HAL_DIR)/utilities/Include

LIBS += -lc

OBJDIR = $(PROJECT_BUILD_DIR)

CFLAGS +=  -Os -MD -fstrict-volatile-bitfields -fno-strict-aliasing -march=$(MARCH) -mabi=$(MABI) -fno-common -fno-builtin-printf -DBUILD_NUMBER=$(BUILD_NUMBER)+1

LDFLAGS +=  -nostdlib -lgcc -mcmodel=medlow -nostartfiles -ffreestanding -Wl,-Bstatic,-T,$(LDSCRIPT),-Map,$(OBJDIR)/$(PROJECT_NAME).map,--print-memory-usage -march=$(MARCH) -mabi=$(MABI) -specs=nano.specs -lnosys


SRCS =  $(RUNTIME) $(wildcard $(PROJECT_SRC_DIR)/*.c) $(wildcard $(PROJECT_SRC_DIR)/*.cpp)

OBJS := $(SRCS)
OBJS := $(OBJS:.c=.o)
OBJS := $(OBJS:.cpp=.o)
OBJS := $(OBJS:.S=.o)
OBJS := $(OBJS:..=miaou)
OBJS := $(addprefix $(OBJDIR)/,$(OBJS))


all: $(OBJDIR)/$(PROJECT_NAME).elf $(OBJDIR)/$(PROJECT_NAME).hex $(OBJDIR)/$(PROJECT_NAME).bin $(OBJDIR)/$(PROJECT_NAME).asm

inc_build_num:
	@expr $(BUILD_NUMBER) + 1 > build_number

$(OBJDIR):
	mkdir -p $@

$(OBJDIR)/%.elf: $(OBJS) | $(OBJDIR)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS) $(LIBSINC) $(LIBS)

%.hex: %.elf
	$(OBJCOPY) -O ihex $^ $@

%.bin: %.elf
	$(OBJCOPY) -O binary $^ $@

%.asm: %.elf
	$(OBJDUMP) -S -d $^ > $@

$(OBJDIR)/%.o: %.c
	mkdir -p $(dir $@)
	$(CC) -c $(CFLAGS)  $(INC) -o $@ $^
	$(CC) -S $(CFLAGS)  $(INC) -o $@.disasm $^

$(OBJDIR)/%.o: %.cpp
	mkdir -p $(dir $@)
	$(CC) -c $(CFLAGS)  $(INC) -o $@ $^

$(OBJDIR)/%.o: %.S
	mkdir -p $(dir $@)
	$(CC) -c $(CFLAGS) -o $@ $^ -D__ASSEMBLY__=1


clean:
	rm -rf $(OBJDIR)/src
	rm -f $(OBJDIR)/$(PROJECT_NAME).elf
	rm -f $(OBJDIR)/$(PROJECT_NAME).hex
	rm -f $(OBJDIR)/$(PROJECT_NAME).hexx
	rm -f $(OBJDIR)/$(PROJECT_NAME).map
	rm -f $(OBJDIR)/$(PROJECT_NAME).bin
	rm -f $(OBJDIR)/$(PROJECT_NAME).v
	rm -f $(OBJDIR)/$(PROJECT_NAME).asm
	find $(OBJDIR) -type f -name '*.o' -print0 | xargs -0 -r rm
	find $(OBJDIR) -type f -name '*.d' -print0 | xargs -0 -r rm



upload: $(OBJDIR)/$(PROJECT_NAME).hex
	python $(MIK32_UPLOADER_DIR)/mik32_upload.py --run-openocd --openocd-exec=`which openocd` --openocd-scripts $(MIK32_UPLOADER_DIR)/openocd-scripts --openocd-interface interface/ftdi/mikron-link.cfg $^

