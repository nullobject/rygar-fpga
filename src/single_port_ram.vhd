library ieee;
use ieee.std_logic_1164.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity single_port_ram is
  generic (
    ADDR_WIDTH : integer := 8;
    DATA_WIDTH : integer := 8
  );
  port (
    -- clock
    clk : in std_logic := '1';

    -- clock enable
    cen : in std_logic := '1';

    -- address
    addr : in std_logic_vector(ADDR_WIDTH-1 downto 0);

    -- data in
    din : in std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    -- data out
    dout : out std_logic_vector(DATA_WIDTH-1 downto 0);

    -- write enable
    we : in std_logic := '0'
  );
end single_port_ram;

architecture arch of single_port_ram is
begin
  altsyncram_component : altsyncram
  generic map (
    clock_enable_input_a          => "NORMAL",
    clock_enable_output_a         => "BYPASS",
    intended_device_family        => "Cyclone V",
    lpm_hint                      => "ENABLE_RUNTIME_MOD=NO",
    lpm_type                      => "altsyncram",
    numwords_a                    => 2**ADDR_WIDTH,
    operation_mode                => "SINGLE_PORT",
    outdata_aclr_a                => "NONE",
    outdata_reg_a                 => "UNREGISTERED",
    power_up_uninitialized        => "FALSE",
    read_during_write_mode_port_a => "NEW_DATA_NO_NBE_READ",
    width_a                       => DATA_WIDTH,
    width_byteena_a               => 1,
    widthad_a                     => ADDR_WIDTH
  )
  port map (
    address_a => addr,
    clock0    => clk,
    clocken0  => cen,
    data_a    => din,
    wren_a    => we,
    q_a       => dout
  );
end arch;
