# Specify root clocks
create_clock -period 20.0 [get_ports {FPGA_CLK1_50}]
create_clock -period 20.0 [get_ports {FPGA_CLK2_50}]
create_clock -period 20.0 [get_ports {FPGA_CLK3_50}]
create_clock -period 10.0 [get_pins -compatibility_mode {*|h2f_user0_clk}]
create_clock -period 10.0 -name spi_sck [get_pins -compatibility_mode {spi|sclk_out}]

derive_pll_clocks

create_generated_clock -name SDRAM_CLK \
                       -source [get_pins -compatibility_mode {emu|pll|pll_inst|altera_pll_i|general[1].gpll~PLL_OUTPUT_COUNTER|divclk}] \
                       [get_ports {SDRAM_CLK}]

create_generated_clock -name HDMI_CLK \
                       -source [get_pins -compatibility_mode {pll_hdmi|pll_hdmi_inst|altera_pll_i|*[0].*|divclk}] \
                       [get_ports {HDMI_TX_CLK}]

derive_clock_uncertainty

# data access delay (tAC) plus a small margin to allow for propagation delay
set_input_delay -clock SDRAM_CLK -max [expr 6.0 + 0.5] [get_ports {SDRAM_DQ[*]}]

# data output hold time (tOH)
set_input_delay -clock SDRAM_CLK -min 2.5 [get_ports {SDRAM_DQ[*]}]

# data input setup time (tIS)
set_output_delay -clock SDRAM_CLK -max 1.5 [get_ports {SDRAM_A* SDRAM_BA* SDRAM_D* SDRAM_CKE SDRAM_n*}]

# data input hold time (tIH)
set_output_delay -clock SDRAM_CLK -min -0.8 [get_ports {SDRAM_A* SDRAM_BA* SDRAM_D* SDRAM_CKE SDRAM_n*}]

# use proper edges for the timing calculations
set_multicycle_path -setup -end \
									  -rise_from [get_clocks {SDRAM_CLK}] \
										-rise_to [get_clocks {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] 2

# decouple different clock groups (to simplify routing)
set_clock_groups -exclusive \
                 -group [get_clocks {FPGA_CLK1_50 FPGA_CLK2_50 FPGA_CLK3_50}] \
                 -group [get_clocks {*|h2f_user0_clk}] \
                 -group [get_clocks {pll_hdmi|pll_hdmi_inst|altera_pll_i|*[0].*|divclk}] \
                 -group [get_clocks {*|pll|pll_inst|altera_pll_i|*[*].*|divclk}]

set_output_delay -clock HDMI_CLK -max 4.0 [get_ports {HDMI_TX_D[*] HDMI_TX_DE HDMI_TX_HS HDMI_TX_VS}]
set_output_delay -clock HDMI_CLK -min 3.0 [get_ports {HDMI_TX_D[*] HDMI_TX_DE HDMI_TX_HS HDMI_TX_VS}]

set_false_path -from {*} -to [get_registers {wcalc[*] hcalc[*]}]

# Put constraints on input ports
set_false_path -from [get_ports {KEY*}] -to *
set_false_path -from [get_ports {BTN_*}] -to *

# Put constraints on output ports
set_false_path -from * -to [get_ports {LED_*}]
set_false_path -from * -to [get_ports {VGA_*}]
set_false_path -from * -to [get_ports {AUDIO_SPDIF}]
set_false_path -from * -to [get_ports {AUDIO_L}]
set_false_path -from * -to [get_ports {AUDIO_R}]
set_false_path -from * -to [get_keepers {cfg[*]}]
