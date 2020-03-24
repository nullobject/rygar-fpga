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
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	
	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,    // 1 - signed audio samples, 0 - unsigned
	 
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
	
	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT
);


assign VGA_F1    = 0;
assign USER_OUT  = '1;
assign LED_USER  = rom_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

assign HDMI_ARX = status[1] ? 8'd16 : 8'd4;
assign HDMI_ARY = status[1] ? 8'd9  : 8'd3;


assign AUDIO_R   = AUDIO_L;
assign AUDIO_S   = 1;

`include "build_id.v" 
localparam CONF_STR = {
	"A.RYGAR;;",
  "-;",
	"O1,Aspect Ratio,Original,Wide;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"DIP;",
	"-;",
	"R0,Reset;",
	"J1,Fire,Jump,Start 1P,Start 2P,Coin;",
	"jn,A,B,Start,Select,R;",
	"V,v",`BUILD_DATE
};

////////////////////   CLOCKS   ///////////////////

wire locked;
wire clk_sys;

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
wire        forced_scandoubler;
wire        direct_video;

wire [15:0] audio_l;

wire [10:0] ps2_key;

wire [15:0] joy1, joy2, joy3, joy4;
wire [15:0] joy = joy1 | joy2 | joy3 | joy4;
wire [15:0] joy1a, joy2a, joy3a, joy4a;

wire [21:0] gamma_bus;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_index(ioctl_index),

	.joystick_0(joy1),
	.joystick_1(joy2),
	.joystick_2(joy3),
	.joystick_3(joy4),

	.joystick_analog_0(joy1a),
	.joystick_analog_1(joy2a),
	.joystick_analog_2(joy3a),
	.joystick_analog_3(joy4a),

	.ps2_key(ps2_key)
);

// load the DIPS
reg [7:0] sw[8];
always @(posedge clk_sys) if (ioctl_wr && (ioctl_index==254) && !ioctl_addr[24:3]) sw[ioctl_addr[2:0]] <= ioctl_dout;


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
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
			'h75: btn_up            <= pressed; // up
			'h72: btn_down          <= pressed; // down
			'h6B: btn_left          <= pressed; // left
			'h74: btn_right         <= pressed; // right
			'h76: btn_coin1         <= pressed; // ESC
			'h05: btn_start1        <= pressed; // F1
			'h06: btn_start2        <= pressed; // F2
			'h14: btn_fireA         <= pressed; // lctrl
			'h11: btn_fireB         <= pressed; // lalt
			//'h29: btn_fireC         <= pressed; // Space
			// JPAC/IPAC/MAME Style Codes
			'h16: btn_start1        <= pressed; // 1
			'h1E: btn_start2        <= pressed; // 2
			//'h26: btn_start3        <= pressed; // 3
			//'h25: btn_start4        <= pressed; // 4
			'h2E: btn_coin1         <= pressed; // 5
			'h36: btn_coin2         <= pressed; // 6
			//'h3D: btn_coin3         <= pressed; // 7
			//'h3E: btn_coin4         <= pressed; // 8
			'h2D: btn_up2           <= pressed; // R
			'h2B: btn_down2         <= pressed; // F
			'h23: btn_left2         <= pressed; // D
			'h34: btn_right2        <= pressed; // G
			'h1C: btn_fire2A        <= pressed; // A
			'h1B: btn_fire2B        <= pressed; // S
			//'h21: btn_fire2C        <= pressed; // Q
			//'h1D: btn_fire2D        <= pressed; // W
			//'h1D: btn_fire2E        <= pressed; // W
			//'h1D: btn_fire2F        <= pressed; // W
			//'h1D: btn_tilt          <= pressed; // W
		endcase
	end
end

reg btn_left   = 0;
reg btn_right  = 0;
reg btn_down   = 0;
reg btn_up     = 0;
reg btn_fireA  = 0;
reg btn_fireB  = 0;
//reg btn_fireC  = 0;
//reg btn_fireD  = 0;
reg btn_coin1  = 0;
reg btn_coin2  = 0;
reg btn_start1 = 0;
reg btn_start2 = 0;
reg btn_up2    = 0;
reg btn_down2  = 0;
reg btn_left2  = 0;
reg btn_right2 = 0;
reg btn_fire2A = 0;
reg btn_fire2B = 0;
//reg btn_fire2C = 0;
//reg btn_fire2D = 0;

//wire service = sw[1][0];

wire m_start1  = btn_start1 | joy[6];
wire m_start2  = btn_start2 | joy[7];
wire m_coin1   = btn_coin1  | btn_coin2 | joy[8];

wire m_right1  = btn_right  | joy1[0];
wire m_left1   = btn_left   | joy1[1];
wire m_down1   = btn_down   | joy1[2];
wire m_up1     = btn_up     | joy1[3];
wire m_fire1a  = btn_fireA  | joy1[4];
wire m_fire1b  = btn_fireB  | joy1[5];
//wire m_fire1c  = btn_fireC  | joy1[6];
//wire m_fire1d  = btn_fireD  | joy1[7];

wire m_right2  = btn_right2 | joy2[0];
wire m_left2   = btn_left2  | joy2[1];
wire m_down2   = btn_down2  | joy2[2];
wire m_up2     = btn_up2    | joy2[3];
wire m_fire2a  = btn_fire2A | joy2[4];
wire m_fire2b  = btn_fire2B | joy2[5];
//wire m_fire2c  = btn_fire2C | joy2[6];
//wire m_fire2d  = btn_fire2D | joy2[7];

wire m_right   = m_right1 | m_right2;
wire m_left    = m_left1  | m_left2; 
wire m_down    = m_down1  | m_down2; 
wire m_up      = m_up1    | m_up2;   
wire m_fire_a  = m_fire1a | m_fire2a;
wire m_fire_b  = m_fire1b | m_fire2b;
//wire m_fire_c  = m_fire1c | m_fire2c;
//wire m_fire_d  = m_fire1d | m_fire2d;


wire rom_download = ioctl_download & (ioctl_index==0);

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

wire reset = RESET | status[0] | buttons[1] | rom_download;

rygar rygar
(
  .reset(reset),
  .clk(clk_sys),
  .cen_6(ce_pix),

  .joystick_1({2'b0, m_fire_b, m_fire_a, m_up, m_down, m_right, m_left}),
  .joystick_2({2'b0, m_fire_b, m_fire_a, m_up, m_down, m_right, m_left}),
  .start_1(m_start1),
  .start_2(m_start2),
  .coin_1(m_coin1),
  .coin_2(1'b0),

  .dip_allow_continue(~sw[0][7]),
  .dip_bonus_life(sw[0][4:3]),
  .dip_cabinet(~sw[0][2]),
  .dip_difficulty(sw[0][6:5]),
  .dip_lives(sw[0][1:0]),

  .sdram_addr(sdram_addr),
  .sdram_data(sdram_data),
  .sdram_we(sdram_we),
  .sdram_req(sdram_req),
  .sdram_ack(sdram_ack),
  .sdram_valid(sdram_valid),
  .sdram_q(sdram_q),

  .ioctl_addr(ioctl_addr),
  .ioctl_data(ioctl_dout),
  .ioctl_wr(ioctl_wr),
  .ioctl_download(rom_download),

  .hsync(hs),
  .vsync(vs),
  .hblank(hblank),
  .vblank(vblank),

  .r(r),
  .g(g),
  .b(b),
  .audio(audio_l)
);

wire ce_pix_old;
wire hs, vs, cs;
wire hblank, vblank;
wire [3:0] r,g,b;
wire ce_pix;

arcade_video #(256,224,12) arcade_video
(
	.*,

	.clk_video(clk_sys),
	.RGB_in({r,g,b}),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),

	.no_rotate(1),
	.rotate_ccw(0),
	.fx(status[5:3])
);

assign AUDIO_L = { audio_l };
assign AUDIO_R = { audio_l };
assign AUDIO_S = 1;

endmodule
