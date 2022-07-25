import display
import mch22
import buttons
from fpga_wishbone import FPGAWB

BLACK = display.BLACK
WHITE = display.WHITE
MARKER = "permanentmarker22"

wishbone = FPGAWB() # create a wishbone command buffer
## setup UART
#wishbone.queue_write(2, 4, 3123) # (30e6/9600)-2
#wishbone.queue_write(2, 0, 0xaa) # queue writing a byte
##wishbone.queue_read(2, 0) # queue reading a byte

def setup_fpga(filename):
    # load bitstream from SD card onto the FPGA
    with open(filename, "rb") as f:
        mch22.fpga_load(f.read())

def print_disclaimer():
    display.drawFill(WHITE)
    display.drawText(10,  10, "Call out your callsign\nout loud now!", BLACK, MARKER)
    display.drawText(10,  60, "If you did hesitate\npress B to exit.", BLACK, MARKER)
    display.drawText(10, 110, "In case you _DO_ have\nyour HAM license\npress START.", BLACK, MARKER)
    display.flush()

def print_fpga_started():
    display.drawFill(BLACK)
    display.drawText(10,  10, "FPGA running.", WHITE, MARKER)
    display.drawText(10,  60, "You are currently\ntransmitting as 144Mhz!", WHITE, MARKER)
    display.drawText(10, 110, "Press B to exit()", WHITE, MARKER)
    display.drawText(10, 140, "Press joystick to send!", WHITE, MARKER)
    display.flush()

def trigger_exit(pressed):
    if pressed: mch22.exit_python()

def trigger_beep(pressed):
    if pressed:
        wishbone.queue_write(0xFF, 0xFFFFFF, 0xFFFFFFFF)
    else:
        wishbone.queue_write(0x00, 0x000000, 0x00000000)
    wishbone.exec() # execute the command queue

def trigger_fpga(pressed):
    if not pressed: return
    print_fpga_started()
    setup_fpga("/apps/python/morse_2m_fpga/bitstream.bin")
    buttons.attach(buttons.BTN_PRESS, trigger_beep)

def main():
    print_disclaimer()
    buttons.attach(buttons.BTN_START, trigger_fpga)
    buttons.attach(buttons.BTN_B, trigger_exit)

main()
