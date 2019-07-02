library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity single_port_rom is
  generic (
    ADDR_WIDTH : integer := 8;
    DATA_WIDTH : integer := 8;
    INIT_FILE : string := ""
  );
  port (
    -- clock
    clk : in std_logic;

    -- address
    addr : in std_logic_vector(ADDR_WIDTH-1 downto 0);

    -- data out
    do : out std_logic_vector(DATA_WIDTH-1 downto 0)
  );
end single_port_rom;

architecture arch of single_port_rom is
begin
  altsyncram_component : altsyncram
  generic map (
    address_aclr_a         => "NONE",
    clock_enable_input_a   => "BYPASS",
    clock_enable_output_a  => "BYPASS",
    init_file              => INIT_FILE,
    intended_device_family => "Cyclone V",
    lpm_hint               => "ENABLE_RUNTIME_MOD=NO",
    lpm_type               => "altsyncram",
    numwords_a             => 2**ADDR_WIDTH,
    operation_mode         => "ROM",
    outdata_aclr_a         => "NONE",
    outdata_reg_a          => "UNREGISTERED",
    width_a                => DATA_WIDTH,
    width_byteena_a        => 1,
    widthad_a              => ADDR_WIDTH
  )
  port map (
    address_a => addr,
    clock0    => clk,
    q_a       => do
  );
end arch;
