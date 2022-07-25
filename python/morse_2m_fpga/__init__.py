import display
import mch22
import buttons
from fpga_wishbone import FPGAWB
import sndmixer
import time

#sndmixer.begin(1, False)
#synthId = sndmixer.synth()
#sndmixer.volume(synthId, 255)
#sndmixer.freq(synthId, 880)


BLACK = display.BLACK
WHITE = display.WHITE
MARKER = "permanentmarker22"

wishbone = FPGAWB() # create a wishbone command buffer
radio_enabled = False
is_ham = False
refresh_screen = True
hist = [False]*320

def setup_fpga(filename):
    # load bitstream from SD card onto the FPGA
    with open(filename, "rb") as f:
        mch22.fpga_load(f.read())

def print_disclaimer():
    display.drawFill(WHITE)
    display.drawText(10,  10, "Call out your callsign\nout loud now!", BLACK, MARKER)
    display.drawText(10,  60, "If you did hesitate\npress [B] to exit.", BLACK, MARKER)
    display.drawText(10, 110, "In case you _DO_ have\nyour HAM license\npress [START].", BLACK, MARKER)
    display.flush()

def draw_screen():
    carrier = ["Carrier OFF", "Carrier ON at 144MHz"][radio_enabled]
    
    display.drawLine(0, 217, 319, 217, BLACK)
    display.drawLine(0, 231, 319, 231, BLACK)
    display.drawText(10, 10, "FPGA running.", BLACK, MARKER)
    display.drawText(10, 30, carrier, BLACK, MARKER)
    display.drawText(10, 60, "[B] to exit()", BLACK, MARKER)
    display.drawText(10, 80, "[DOWN] to send", BLACK, MARKER)
    display.drawText(10, 100, "[SEL] to toggle carrier", BLACK, MARKER)

def trigger_exit(pressed):
    if pressed: mch22.exit_python()

def trigger_beep(pressed):
    hist[-1] = pressed
    if pressed:
        #sndmixer.freq(synthId, 880)
        #sndmixer.play(True)
        if not radio_enabled: return
        wishbone.queue_write(0xFF, 0xFFFFFF, 0xFFFFFFFF)
    else:
        #sndmixer.freq(synthId, 0)
        wishbone.queue_write(0x00, 0x000000, 0x00000000)
    wishbone.exec() # execute the command queue

def trigger_fpga(pressed):
    global is_ham
    if not pressed: return
    setup_fpga("/apps/python/morse_2m_fpga/bitstream.bin")
    buttons.attach(buttons.BTN_DOWN, trigger_beep)
    is_ham = True

def trigger_toggle_radio(pressed):
    global radio_enabled
    global refresh_screen
    if not pressed: return
    radio_enabled ^= True
    refresh_screen = True

def main():
    global refresh_screen
    print_disclaimer()
    buttons.attach(buttons.BTN_START, trigger_fpga)
    buttons.attach(buttons.BTN_B, trigger_exit)
    buttons.attach(buttons.BTN_SELECT, trigger_toggle_radio)
    while not is_ham: pass
    refresh_screen = True
    start = time.time_ns()
    #display.drawLine(0, 217, 319, 217, BLACK)
    #display.drawLine(0, 231, 319, 231, BLACK)
    while True:
        if refresh_screen:
            display.drawFill(WHITE)
            draw_screen()
            refresh_screen = False
        display.drawRect(0, 219, 320, 11, True, WHITE)
        for i, h in enumerate(hist):
            if h: display.drawLine(i, 229, i, 219, BLACK)
        display.flush()
        now = time.time_ns()
        if now - start > 20000000:
            start = now
            hist.pop(0)
            hist.append(hist[-1])

main()
