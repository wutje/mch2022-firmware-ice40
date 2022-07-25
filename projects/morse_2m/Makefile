# Project config
PROJ := morse

PROJ_DEPS := spi_slave
PROJ_RTL_SRCS := $(addprefix rtl/, \
)
PROJ_TOP_SRC := rtl/morse.v
PROJ_TOP_MOD := top

# Include default rules
include ../_common/build.mk

FILE_UPLOAD_SCRIPT ?= ../../tools/webusb_fat_push.py
RESET_SCRIPT ?= ../../tools/webusb_reset.py
upload: python/__init__.py $(PROJ_BIN_FINAL) 
	$(FILE_UPLOAD_SCRIPT) python/__init__.py /flash/apps/python/morse_2m_fpga/__init__.py
	$(FILE_UPLOAD_SCRIPT) $(PROJ_BIN_FINAL) /flash/apps/python/morse_2m_fpga/bitstream.bin

reset:
	$(RESET_SCRIPT)

.PHONY: reset
