
`default_nettype none // Simplifies finding typos

module top(
  input clk_in,

  input  spi_mosi,
  output spi_miso,
  input  spi_clk,
  input  spi_cs_n,

  output [2:0] rgb, // LED outputs. [0]: Blue, [1]: Red, [2]: Green.
  inout [7:0] pmod, //PMOD
);

  wire clk; // Directly use the 12 MHz oscillator, via the PLL config

  // ----------------------------------------------------------
  //   Simple gray counter blinky
  // ----------------------------------------------------------

  wire clk_out, pll_locked;

  reg [25:0] counter;
  reg [25:0] counter2;
  reg [7:0] delay;

  wire red, green, blue;

  assign {red } = morse;

  always @(posedge clk) begin
	  counter <= counter + 1;
	  if (counter > 360000) begin
		  counter <= 25'b0;
		  if (!delay) begin
			  //blue  <= 1;
			  delay <= 8'b11111111;
		  end else begin
			  //blue  <= 0;
			  delay <= 8'b00000000;
		  end
	  end
	  counter2 <= counter2 + 1;
	  if (counter2 > 36000000) begin
		  counter2 <= 25'b0;
		  green <= !green;
	  end
  end

  // ----------------------------------------------------------
  //   Reset logic
  // ----------------------------------------------------------

  wire reset_button = 1'b1; // No reset button on this board

  reg [15:0] reset_cnt = 0;
  wire resetq = &reset_cnt;

  always @(posedge clk) begin
    if (reset_button) reset_cnt <= reset_cnt + !resetq;
    else        reset_cnt <= 0;
  end

  // ----------------------------------------------------------
  //   SPI interface
  // ----------------------------------------------------------

  wire [7:0] usr_miso_data, usr_mosi_data;
  wire usr_mosi_stb, usr_miso_ack;
  wire csn_state, csn_rise, csn_fall;

  spi_dev_core _communication (

    .clk (clk),
    .rst (~resetq),

    .usr_mosi_data (usr_mosi_data),
    .usr_mosi_stb  (usr_mosi_stb),
    .usr_miso_data (usr_miso_data),
    .usr_miso_ack  (usr_miso_ack),

    .csn_state (csn_state),
    .csn_rise  (csn_rise),
    .csn_fall  (csn_fall),

    // Interface to SPI wires

    .spi_miso (spi_miso),
    .spi_mosi (spi_mosi),
    .spi_clk  (spi_clk),
    .spi_cs_n (spi_cs_n)
  );

  wire [7:0] pw_wdata;
  wire pw_wcmd, pw_wstb, pw_end;

  spi_dev_proto #( .NO_RESP(1)
  ) _protocol (
    .clk (clk),
    .rst (~resetq),

    // Connection to the actual SPI module:

    .usr_mosi_data (usr_mosi_data),
    .usr_mosi_stb  (usr_mosi_stb),
    .usr_miso_data (usr_miso_data),
    .usr_miso_ack  (usr_miso_ack),

    .csn_state (csn_state),
    .csn_rise  (csn_rise),
    .csn_fall  (csn_fall),

    // These wires deliver received data:

    .pw_wdata (pw_wdata),
    .pw_wcmd  (pw_wcmd),
    .pw_wstb  (pw_wstb),
    .pw_end   (pw_end)
  );

  reg  [7:0] command;
  reg [31:0] incoming_data;
  reg [31:0] buttonstate;

  always @(posedge clk)
  begin
    if (pw_wstb & pw_wcmd)           command       <= pw_wdata;
    if (pw_wstb)                     incoming_data <= incoming_data << 8 | pw_wdata;
    //if (pw_end & (command == 8'hF4)) buttonstate   <= incoming_data;
    if (pw_end ) buttonstate   <= incoming_data;
  end

  wire joystick_down  = buttonstate[16];
  wire joystick_up    = buttonstate[17];
  wire joystick_left  = buttonstate[18];
  wire joystick_right = buttonstate[19];
  wire joystick_press = buttonstate[20];
  wire home           = buttonstate[21];
  wire menu           = buttonstate[22];
  wire select         = buttonstate[23];

  wire start          = buttonstate[24];
  wire accept         = buttonstate[25];
  wire back           = buttonstate[26];

  /*
Bits are mapped to the following keys:
 0 - joystick down
 1 - joystick up
 2 - joystick left
 3 - joystick right
 4 - joystick press
 5 - home
 6 - menu
 7 - select
 8 - start
 9 - accept
10 - back
  */

 // Two clock output pll: 
 // the 12mhz input clock
 // The 144 Mhz output clock
  SB_PLL40_2F_PAD #(.FEEDBACK_PATH("SIMPLE"),
	  .DIVR(4'b0000),         // DIVR =  0
	  .DIVF(96 - 1),      // DIVF = 95 = 96
	  .DIVQ(3),          // DIVQ = 2^x = 2^2 = 8 => 96/8 = 12
	  .FILTER_RANGE(3'b001),   // FILTER_RANGE = 1
	  //.DELAY_ADJUSTMENT_MODE_FEEDBACK("DYNAMIC"),
	  .DELAY_ADJUSTMENT_MODE_RELATIVE("DYNAMIC"),
	  .FDA_RELATIVE(15),
	  .PLLOUT_SELECT_PORTA ("GENCLK"),
	  .PLLOUT_SELECT_PORTB ("SHIFTREG_0deg")
	  //.FEEDBACK_PATH("PHASE_AND_DELAY"),
  ) uut (
	  .RESETB(1'b1),
	  .BYPASS(1'b0),
	  .LOCK(pll_locked),
	  .PACKAGEPIN(clk_in),  // 12 MHz
	  .PLLOUTGLOBALA(clk_out),    // 144 Mhz
	  .PLLOUTGLOBALB(clk),    // 144 / 4 = 36 Mhz
	  //.DYNAMICDELAY(delay),
  );

  wire morse = (/*pmod[7] |*/ joystick_press);
  //assign pmod[0] = clk_out & morse;
  assign pmod[6:1] = 5'b0;
 
  // IOBs
  SB_IO #(
	  .PIN_TYPE(6'b1100_01),
	  .PULLUP(1'b0),
	  .IO_STANDARD("SB_LVCMOS")
  ) iob_O (
	  .PACKAGE_PIN   (pmod[0]),
	  .OUTPUT_CLK    (clk_out),
	  .OUTPUT_ENABLE (1),
	  .D_OUT_0       (morse & delay[0]),
	  .D_OUT_1       (morse & !delay[0])
  );

  // ----------------------------------------------------------
  // Instantiate iCE40 LED driver hard logic.
  // ----------------------------------------------------------
  //
  // Note that it's possible to drive the LEDs directly,
  // however that is not current-limited and results in
  // overvolting the red LED.
  //
  // See also:
  // https://www.latticesemi.com/-/media/LatticeSemi/Documents/ApplicationNotes/IK/ICE40LEDDriverUsageGuide.ashx?document_id=50668

  SB_RGBA_DRV #(
      .CURRENT_MODE("0b1"),       // half current
      .RGB0_CURRENT("0b000011"),  // 4 mA
      .RGB1_CURRENT("0b000011"),  // 4 mA
      .RGB2_CURRENT("0b000011")   // 4 mA
  ) RGBA_DRIVER (
      .CURREN(1'b1),
      .RGBLEDEN(1'b1),
      .RGB1PWM(red),
      .RGB2PWM(blue),
      .RGB0PWM(green),
      .RGB0(rgb[0]),
      .RGB1(rgb[1]),
      .RGB2(rgb[2])
  );

endmodule
