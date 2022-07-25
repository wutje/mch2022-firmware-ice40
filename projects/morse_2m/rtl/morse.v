
`default_nettype none // Simplifies finding typos

module top(
  input clk_in,

  input  spi_mosi,
  output spi_miso,
  input  spi_clk,
  input  spi_cs_n,

  output [2:0] rgb, // LED outputs. [0]: Blue, [1]: Red, [2]: Green.
  output [7:0] pmod, //PMOD
);

  wire clk; // 144Mhz / 4 MHz = 36Mhz
  wire clk_out; // 144Mhz
  wire pll_locked; // TODO use this! For reset?

  reg [25:0] counter;
  //reg [7:0] delay;
  reg [0:0] delay;

  wire red, green, blue;

  assign {red} = radio_enabled;
  assign {blue} = led_blue;
  assign {green} = led_green;
  wire [23:0] freq = 36000000;

  always @(posedge clk) begin
	  counter <= counter + 1;
	  if (counter > freq) begin
		  counter <= 25'b0;
		  delay[0] <= !delay[0];
		  //if (!delay) begin
		  //        delay <= 8'b11111111;
		  //end else begin
		  //        delay <= 8'b00000000;
		  //end
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
  reg [31:0] cmdword;

  always @(posedge clk)
  begin
    if (pw_wstb & pw_wcmd)           command       <= pw_wdata;
    if (pw_wstb)                     incoming_data <= incoming_data << 8 | pw_wdata;
    //if (pw_end & (command == 8'hF4)) cmdword   <= incoming_data;
    if (pw_end ) cmdword   <= incoming_data;
  end

  assign {freq}           = cmdword[23:0];

  // Enable output only if button is pressed
  wire led_green      = cmdword[29];
  wire led_blue       = cmdword[30];
  wire radio_enabled  = cmdword[31];

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

  assign pmod[7:1] = 6'b0;
 
  // Clock the I/O at 144Mhz.
  // This ensure we use the flipflop at the I/O edge
  SB_IO #(
	  .PIN_TYPE(6'b1100_01),
	  .PULLUP(1'b0),
	  .IO_STANDARD("SB_LVCMOS")
  ) iob_clk (
	  .PACKAGE_PIN   (pmod[0]),
	  .OUTPUT_CLK    (clk_out),
	  .OUTPUT_ENABLE (1),
	  .D_OUT_0       (radio_enabled & delay[0]),
	  .D_OUT_1       (radio_enabled & !delay[0])
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
