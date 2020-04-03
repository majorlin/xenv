# ******************************************************************************
# File: Makefile
# Created Date: Thursday, January 9th 2020, 1:59:55 pm
# Author: Major Lin
# -----
# Last Modified: Thu Jan 09 2020
# Modified By: Major Lin
# -----
# 
# -----
# HISTORY:
# Date      	By           	Comments
# ----------	-------------	----------------------------------------------------------
# ******************************************************************************
DEVICE_NAME ?= Qiyun
MODULE ?= platinum
TEST_CASE ?= platinum
CHIP_NAME ?= CPU_K32W133G256VAxA 
CORE ?= cortex-m0
LDFILE ?= flash

DEFS += -D$(CHIP_NAME)
DEFS += -DLDFILE=\"$(LDFILE)\"
DEVICE_PATH = ./Device/$(DEVICE_NAME)

TOOLCHAIN = arm-none-eabi
AS = $(TOOLCHAIN)-as
LD = $(TOOLCHAIN)-ld
CC = $(TOOLCHAIN)-gcc
OC = $(TOOLCHAIN)-objcopy
OD = $(TOOLCHAIN)-objdump
OS = $(TOOLCHAIN)-size
GDB = $(TOOLCHAIN)-gdb

MKDIR=mkdir -p

COMM_FLAGS += -mcpu=$(CORE) -g3 -Os -mthumb -Wall -fmessage-length=0
ASFLAGS += $(COMM_FLAGS)

CFLAGS += $(COMM_FLAGS)
CFLAGS += -ffunction-sections 
CFLAGS += -fdata-sections
CFLAGS += -specs=nano.specs
CFLAGS += -specs=nosys.specs

TARGET = output/$(DEVICE_NAME)/$(TEST_CASE)_$(LDFILE)
LINK_FILE_PATH ?= $(DEVICE_PATH)/gcc/$(LDFILE).ld

LFLAGS += -static
LFLAGS += -T$(LINK_FILE_PATH)

DEVICE_SRC += 	$(wildcard $(DEVICE_PATH)/*.c) \
				$(wildcard ./common/*.c) \
				$(wildcard ./drivers/*.c) \
				$(wildcard ./Device/drivers/*.c)

SRC += $(DEVICE_SRC)
SRC += $(wildcard Modules/$(MODULE)/$(TEST_CASE).c)
SRC += $(wildcard Modules/$(MODULE)/hal/*.c)


ASRC = $(wildcard $(DEVICE_PATH)/gcc/*.S)

INCLUDE += -IModules/$(MODULE)
INCLUDE += -IModules/$(MODULE)/hal
INCLUDE += -IUnity
INCLUDE += -Icommon
INCLUDE += -Idrivers
INCLUDE += -Icommon/cmsis
INCLUDE += -I$(DEVICE_PATH)
BUILD_PATH ?= build/$(TARGET)

OBJS = $(addprefix $(BUILD_PATH)/,$(addsuffix .o,$(basename $(ASRC))))
OBJS += $(addprefix $(BUILD_PATH)/,$(addsuffix .o,$(basename $(SRC))))

all: $(TARGET).elf

$(TARGET).elf: $(OBJS) 
	@echo	
	@echo Linking: $@
	@$(MKDIR) -p $(dir $@)
	$(CC) $(CFLAGS) $(LFLAGS) -o $@ $^
	$(OD) -h -S $(TARGET).elf > $(TARGET).lst
	$(OC) -O binary $(TARGET).elf $(TARGET).bin

flash: $(TARGET).elf size
	@echo
	@echo Creating .hex and .bin flash images:
	$(OC) -O ihex $< $(TARGET).hex
	$(OC) -O binary $< $(TARGET).bin
	
size: $(TARGET).elf
	@echo
	@echo == Object size ==
	@$(OS) --format=berkeley $<
	
$(BUILD_PATH)/%.o: %.c
	@echo
	@echo Compiling: $<
	@$(MKDIR) -p $(dir $@)
	$(CC) -c $(CFLAGS) $(DEFS) $(INCLUDE) -I. $< -o $@

$(BUILD_PATH)/%.o: %.S
	@echo
	@echo Assembling: $<
	@$(MKDIR) -p $(dir $@)
	$(CC) -x assembler-with-cpp -c $(ASFLAGS) $< -o $@	

qemu:
	@qemu-system-arm -M ? | grep musca-b1 >/dev/null || exit
	qemu-system-arm -machine musca-b1 -cpu cortex-m33 \
	    -m 4096 -nographic -serial mon:stdio -kernel $(TARGET).elf 

gdbserver:
	qemu-system-arm -machine musca-b1 -cpu cortex-m33 \
	    -m 4096 -nographic -serial mon:stdio -kernel $(TARGET).elf -S -s 

gdb: $(TARGET).elf
	$(GDB) $^ -ex "target remote:1234"

clean: 
	@echo Cleaning:
	$(RM) -rf build output

