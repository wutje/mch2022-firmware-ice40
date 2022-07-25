# Project config
PROJ := morse

PROJ_DEPS := spi_slave
PROJ_RTL_SRCS := $(addprefix rtl/, \
)
PROJ_TOP_SRC := rtl/morse.v
PROJ_TOP_MOD := top

# Include default rules
include ../_common/build.mk

TOOLS_DIR ?= ../../../mch2022-tools
FILE_UPLOAD_SCRIPT = $(TOOLS_DIR)/webusb_fat_push.py
MKDIR_SCRIPT = $(TOOLS_DIR)/webusb_fat_mkdir.py
RESET_SCRIPT = $(TOOLS_DIR)/webusb_reset.py

makedir: 
	$(MKDIR_SCRIPT) /flash/apps/
	$(MKDIR_SCRIPT) /flash/apps/python
	$(MKDIR_SCRIPT) /flash/apps/morse_2m_fpga

upload: python/__init__.py $(PROJ_BIN_FINAL) 
	$(FILE_UPLOAD_SCRIPT) python/__init__.py /flash/apps/python/morse_2m_fpga/__init__.py
	$(FILE_UPLOAD_SCRIPT) $(PROJ_BIN_FINAL) /flash/apps/python/morse_2m_fpga/bitstream.bin

reset:
	$(RESET_SCRIPT)

.PHONY: reset
