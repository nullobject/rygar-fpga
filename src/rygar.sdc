create_clock -name clk -period "50 MHz" [get_ports clk]

derive_pll_clocks
derive_clock_uncertainty

# constrain input ports
set_false_path -from * -to [get_ports {key*}]

# constrain output ports
set_false_path -from * -to [get_ports {led*}]
set_false_path -from * -to [get_ports {debug*}]
set_false_path -from * -to [get_ports {vga*}]
