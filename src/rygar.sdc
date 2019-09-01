create_clock -name clk -period 20 [get_ports clk]

derive_pll_clocks

create_generated_clock -name SDRAM_CLK -source [get_pins {my_pll|pll_inst|altera_pll_i|outclk_wire[1]~CLKENA0|outclk}] [get_ports SDRAM_CLK]

derive_clock_uncertainty

# constrain input ports
set_false_path -from * -to [get_ports {key*}]

# constrain output ports
set_false_path -from * -to [get_ports {vga*}]
