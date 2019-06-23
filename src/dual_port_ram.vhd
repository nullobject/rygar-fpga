library ieee;
use ieee.std_logic_1164.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity dual_port_ram is
  generic (
    ADDR_WIDTH : integer := 8;
    DATA_WIDTH : integer := 8
  );
  port (
    clk_a  : in std_logic := '1';
    clk_b  : in std_logic;
    addr_a : in std_logic_vector (ADDR_WIDTH-1 downto 0);
    addr_b : in std_logic_vector (ADDR_WIDTH-1 downto 0);
    di_a   : in std_logic_vector (DATA_WIDTH-1 downto 0);
    di_b   : in std_logic_vector (DATA_WIDTH-1 downto 0) := (others => '0');
    do_a   : out std_logic_vector (DATA_WIDTH-1 downto 0);
    do_b   : out std_logic_vector (DATA_WIDTH-1 downto 0)
    en_a   : in std_logic := '1';
    en_b   : in std_logic := '1';
    wren_a : in std_logic := '0';
    wren_b : in std_logic := '0';
  );
end dual_port_ram;

architecture arch of dual_port_ram is
begin
  altsyncram_component : altsyncram
  generic map (
    address_reg_b => "CLOCK1",
    clock_enable_input_a => "NORMAL",
    clock_enable_input_b => "NORMAL",
    clock_enable_output_a => "BYPASS",
    clock_enable_output_b => "BYPASS",
    indata_reg_b => "CLOCK1",
    intended_device_family => "Cyclone V",
    lpm_type => "altsyncram",
    numwords_a => 2**ADDR_WIDTH,
    numwords_b => 2**ADDR_WIDTH,
    operation_mode => "BIDIR_DUAL_PORT",
    outdata_aclr_a => "NONE",
    outdata_aclr_b => "NONE",
    outdata_reg_a => "UNREGISTERED",
    outdata_reg_b => "UNREGISTERED",
    power_up_uninitialized => "FALSE",
    read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
    read_during_write_mode_port_b => "NEW_DATA_NO_NBE_READ",
    widthad_a => ADDR_WIDTH,
    widthad_b => ADDR_WIDTH,
    width_a => DATA_WIDTH,
    width_b => DATA_WIDTH,
    width_byteena_a => 1,
    width_byteena_b => 1,
    wrcontrol_wraddress_reg_b => "CLOCK1"
  )
  port map (
    address_a => addr_a,
    address_b => addr_b,
    clock0 => clk_a,
    clock1 => clk_b,
    clocken0 => en_a,
    clocken1 => en_b,
    data_a => di_a,
    data_b => di_b,
    wren_a => wren_a,
    wren_b => wren_b,
    q_a => do_a,
    q_b => do_b
  );
end arch;
