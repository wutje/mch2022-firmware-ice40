ALL: __init__.py ../morse.bin
	../../../../mch2022-tools-master/webusb_fat_push.py __init__.py /flash/apps/python/morse_2m_fpga/__init__.py
	../../../../mch2022-tools-master/webusb_fat_push.py ../morse.bin /flash/apps/python/morse_2m_fpga/bitstream.bin

wouter:
	scp saruman:/home/wouter/mch2022/hello_world.bin ../morse.bin

reset:
	../../../../mch2022-tools-master/webusb_reset.py

.PHONY: reset
