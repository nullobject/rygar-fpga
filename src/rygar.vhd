library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rygar is
  port(
    clk : in std_logic;
    key : in std_logic_vector(1 downto 0);
    led : out std_logic_vector(7 downto 0)
  );
end rygar;

architecture arch of rygar is
  -- clock
  signal cpu_clk : std_logic;

  -- address bus
  signal cpu_addr	: std_logic_vector(15 downto 0);

  -- data bus
  signal cpu_di	: std_logic_vector(7 downto 0);
  signal cpu_do	: std_logic_vector(7 downto 0);

  -- i/o request: the address bus holds a valid address for an i/o read or
  -- write operation
  signal cpu_ioreq_n : std_logic;

  -- memory request: the address bus holds a valid address for a memory read or
  -- write operation
  signal cpu_mreq_n : std_logic;

  -- read: ready to read data from the data bus
  signal cpu_rd_n : std_logic;

  -- write: the data bus contains a byte to write somewhere
  signal cpu_wr_n : std_logic;
begin
  clock_divider : process(clk)
    variable n : unsigned(31 downto 0);
  begin
    if (rising_edge(clk)) then
      n := n + 1;
    end if;
    cpu_clk <= not n(18);
  end process;

  rom : entity work.single_port_rom
  generic map(ADDR_WIDTH => 16, DATA_WIDTH => 8)
  port map(
    clk => clk,
    addr => cpu_addr,
    data => cpu_di
  );

  cpu : entity work.T80s
  port map(
    RESET_n => '1',
    CLK_n   => cpu_clk,
    WAIT_n  => '1',
    INT_n   => '1',
    NMI_n   => '1',
    BUSRQ_n => '1',
    M1_n    => open,
    MREQ_n  => cpu_mreq_n,
    IORQ_n  => cpu_ioreq_n,
    RD_n    => cpu_rd_n,
    WR_n    => cpu_wr_n,
    RFSH_n  => open,
    HALT_n  => open,
    BUSAK_n => open,
    A       => cpu_addr,
    DI      => cpu_di,
    DO      => cpu_do
  );

  led <= cpu_addr(7 downto 0) when cpu_mreq_n = '0' and cpu_rd_n = '0';
end arch;
