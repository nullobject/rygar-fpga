// Copyright (c) 2019 Josh Bassett
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

module emu
(
  //Master input clock
  input         CLK_50M,

  //Async reset from top-level module.
  //Can be used as initial reset.
  input         RESET,

  //Must be passed to hps_io module
  inout  [45:0] HPS_BUS,

  //Base video clock. Usually equals to CLK_SYS.
  output        CLK_VIDEO,

  //Multiple resolutions are supported using different CE_PIXEL rates.
  //Must be based on CLK_VIDEO
  output        CE_PIXEL,

  //Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
  output  [7:0] VIDEO_ARX,
  output  [7:0] VIDEO_ARY,

  output  [7:0] VGA_R,
  output  [7:0] VGA_G,
  output  [7:0] VGA_B,
  output        VGA_HS,
  output        VGA_VS,
  output        VGA_DE,    // = ~(VBlank | HBlank)
  output        VGA_F1,
  output  [1:0] VGA_SL,

  output        LED_USER,  // 1 - ON, 0 - OFF.

  // b[1]: 0 - LED status is system status OR'd with b[0]
  //       1 - LED status is controled solely by b[0]
  // hint: supply 2'b00 to let the system control the LED.
  output  [1:0] LED_POWER,
  output  [1:0] LED_DISK,

  output [15:0] AUDIO_L,
  output [15:0] AUDIO_R,
  output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
  output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

  //ADC
  inout   [3:0] ADC_BUS,

  // SD-SPI
  output        SD_SCK,
  output        SD_MOSI,
  input         SD_MISO,
  output        SD_CS,
  input         SD_CD,

  //High latency DDR3 RAM interface
  //Use for non-critical time purposes
  output        DDRAM_CLK,
  input         DDRAM_BUSY,
  output  [7:0] DDRAM_BURSTCNT,
  output [28:0] DDRAM_ADDR,
  input  [63:0] DDRAM_DOUT,
  input         DDRAM_DOUT_READY,
  output        DDRAM_RD,
  output [63:0] DDRAM_DIN,
  output  [7:0] DDRAM_BE,
  output        DDRAM_WE,

  //SDRAM interface with lower latency
  output        SDRAM_CLK,
  output        SDRAM_CKE,
  output [12:0] SDRAM_A,
  output  [1:0] SDRAM_BA,
  inout  [15:0] SDRAM_DQ,
  output        SDRAM_DQML,
  output        SDRAM_DQMH,
  output        SDRAM_nCS,
  output        SDRAM_nCAS,
  output        SDRAM_nRAS,
  output        SDRAM_nWE,

  input         UART_CTS,
  output        UART_RTS,
  input         UART_RXD,
  output        UART_TXD,
  output        UART_DTR,
  input         UART_DSR,

  // Open-drain User port.
  // 0 - D+/RX
  // 1 - D-/TX
  // 2..5 - USR1..USR4
  // Set USER_OUT to 1 to read from USER_IN.
  input   [5:0] USER_IN,
  output  [5:0] USER_OUT,

  input         OSD_STATUS
);

assign USER_OUT = '1;
assign VGA_F1 = 0;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;

assign AUDIO_R   = AUDIO_L;
assign AUDIO_S   = 1;

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign CLK_VIDEO = clk_sys;
assign VIDEO_ARX = 8'd4;
assign VIDEO_ARY = 8'd3;

`include "build_id.v"
localparam CONF_STR = {
  "A.Rygar;;",
  "F,rom;",
  "-;",
  "O1,Aspect Ratio,Original,Wide;",
  "O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
  "-;",
  "O89,Lives,3,4,5,2;",
  "OA,Cabinet,Upright,Cocktail;",
  "OBC,Bonus Life,50K 200K 500K,100K 300K 600K,200K 500K,100K;",
  "ODE,Difficulty,Easy,Normal,Hard,Hardest;",
  "OF,Allow Continue,Yes,No;",
  "-;",
  "R0,Reset;",
  "J1,Fire,Jump,Start 1P,Start 2P,Coin;",
  "V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire locked;
wire clk_sys;
wire cen_12;

pll pll
(
  .refclk(CLK_50M),
  .outclk_0(clk_sys),
  .outclk_1(SDRAM_CLK),
  .locked(locked)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;

wire [24:0] ioctl_addr;
wire  [7:0] ioctl_data;
wire        ioctl_wr;
wire        ioctl_download;

wire [10:0] ps2_key;

wire  [8:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1;

wire forced_scandoubler;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
  .clk_sys(clk_sys),
  .HPS_BUS(HPS_BUS),

  .conf_str(CONF_STR),

  .buttons(buttons),
  .status(status),
  .forced_scandoubler(forced_scandoubler),

  .ioctl_addr(ioctl_addr),
  .ioctl_dout(ioctl_data),
  .ioctl_wr(ioctl_wr),
  .ioctl_download(ioctl_download),

  .joystick_0(joystick_0),
  .joystick_1(joystick_1),
  .ps2_key(ps2_key)
);

///////////////////////////////////////////////////////////////////

wire [3:0] R, G, B;
wire HSync, VSync, HBlank, VBlank;
wire [2:0] scale = status[5:3];
wire scandoubler = (scale || forced_scandoubler);

video_mixer #(.LINE_LENGTH(256), .HALF_DEPTH(1)) video_mixer
(
  .*,

  .clk_sys(clk_sys),
  .ce_pix(cen_12),
  .ce_pix_out(CE_PIXEL),

  .scanlines(0),
  .scandoubler(scandoubler),
  .hq2x(scale==1),
  .mono(0)
);

wire [22:0] sdram_addr;
wire [31:0] sdram_data;
wire sdram_we;
wire sdram_req;
wire sdram_ack;
wire sdram_valid;
wire [31:0] sdram_q;

sdram #(.CLK_FREQ(48.0)) sdram
(
  .reset(~locked),
  .clk(clk_sys),

  // controller interface
  .addr(sdram_addr),
  .data(sdram_data),
  .we(sdram_we),
  .req(sdram_req),
  .ack(sdram_ack),
  .valid(sdram_valid),
  .q(sdram_q),

  // SDRAM interface
  .sdram_a(SDRAM_A),
  .sdram_ba(SDRAM_BA),
  .sdram_dq(SDRAM_DQ),
  .sdram_cke(SDRAM_CKE),
  .sdram_cs_n(SDRAM_nCS),
  .sdram_ras_n(SDRAM_nRAS),
  .sdram_cas_n(SDRAM_nCAS),
  .sdram_we_n(SDRAM_nWE),
  .sdram_dqml(SDRAM_DQML),
  .sdram_dqmh(SDRAM_DQMH)
);

wire       pressed = ps2_key[9];
wire [7:0] code    = ps2_key[7:0];

reg key_left    = 0;
reg key_right   = 0;
reg key_down    = 0;
reg key_up      = 0;
reg key_jump    = 0;
reg key_fire    = 0;
reg key_start_1 = 0;
reg key_start_2 = 0;
reg key_coin    = 0;

always @(posedge clk_sys) begin
  reg old_state;
  old_state <= ps2_key[10];

  if (old_state != ps2_key[10]) begin
    case (code)
      'h75: key_up      <= pressed; // up
      'h72: key_down    <= pressed; // down
      'h6B: key_left    <= pressed; // left
      'h74: key_right   <= pressed; // right
      'h16: key_start_1 <= pressed; // 1
      'h1E: key_start_2 <= pressed; // 2
      'h2E: key_coin    <= pressed; // 5
      'h14: key_fire    <= pressed; // ctrl
      'h11: key_jump    <= pressed; // alt
    endcase
  end
end

wire right   = key_right   | joy[0];
wire left    = key_left    | joy[1];
wire down    = key_down    | joy[2];
wire up      = key_up      | joy[3];
wire fire    = key_fire    | joy[4];
wire jump    = key_jump    | joy[5];
wire start_1 = key_start_1 | joy[6];
wire start_2 = key_start_2 | joy[7];
wire coin    = key_coin    | joy[8];

rygar rygar
(
  .reset(RESET | ioctl_download | status[0] | buttons[1]),
  .clk(clk_sys),
  .cen_12(cen_12),

  .joystick_1({2'b0, jump, fire, up, down, right, left}),
  .joystick_2({2'b0, jump, fire, up, down, right, left}),
  .start_1(start_1),
  .start_2(start_2),
  .coin_1(coin),
  .coin_2(1'b0),

  .dip_allow_continue(~status[15]),
  .dip_bonus_life(status[12:11]),
  .dip_cabinet(~status[10]),
  .dip_difficulty(status[14:13]),
  .dip_lives(status[9:8]),

  .sdram_addr(sdram_addr),
  .sdram_data(sdram_data),
  .sdram_we(sdram_we),
  .sdram_req(sdram_req),
  .sdram_ack(sdram_ack),
  .sdram_valid(sdram_valid),
  .sdram_q(sdram_q),

  .ioctl_addr(ioctl_addr),
  .ioctl_data(ioctl_data),
  .ioctl_wr(ioctl_wr),
  .ioctl_download(ioctl_download),

  .hsync(HSync),
  .vsync(VSync),
  .hblank(HBlank),
  .vblank(VBlank),

  .r(R),
  .g(G),
  .b(B),

  .audio(AUDIO_L)
);

endmodule
