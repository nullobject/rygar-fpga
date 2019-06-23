library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity single_port_rom is
  generic(
    ADDR_WIDTH : integer := 8;
    DATA_WIDTH : integer := 8;
    INIT_FILE : string := ""
  );
  port(
    clk : in std_logic;
    addr : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    data : out std_logic_vector(DATA_WIDTH-1 downto 0)
  );
end single_port_rom;

architecture arch of single_port_rom is
  type rom_type is array (0 to 2**ADDR_WIDTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal rom : rom_type;

  attribute ram_init_file : string;
  attribute ram_init_file of rom : signal is INIT_FILE;
begin
  data <= rom(to_integer(unsigned(addr))) when rising_edge(clk);
end arch;
