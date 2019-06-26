library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rygar is
  port(
    clk : in std_logic;
    led : out std_logic_vector(7 downto 0)
  );
end rygar;

architecture arch of rygar is
  -- clock
  signal cpu_clk : std_logic;

  -- address bus
  signal cpu_addr : std_logic_vector(15 downto 0);

  -- data bus
  signal cpu_din  : std_logic_vector(7 downto 0);
  signal cpu_dout : std_logic_vector(7 downto 0);

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

  -- chip selects
  type chip_type is (UNKNOWN_CS, ROM_CS, WORK_RAM_CS, TX_RAM_CS, FG_RAM_CS, BG_RAM_CS, SPRITE_RAM_CS, PALETTE_RAM_CS, BANK_CS);
  signal current_chip : chip_type;

  -- output signals
  signal main_rom_dout    : std_logic_vector(7 downto 0);
  signal bank_dout        : std_logic_vector(7 downto 0);
  signal work_ram_dout    : std_logic_vector(7 downto 0);
  signal tx_ram_dout      : std_logic_vector(7 downto 0);
  signal fg_ram_dout      : std_logic_vector(7 downto 0);
  signal bg_ram_dout      : std_logic_vector(7 downto 0);
  signal sprite_ram_dout  : std_logic_vector(7 downto 0);
  signal palette_ram_dout : std_logic_vector(7 downto 0);

  -- ram
  signal work_ram_we    : std_logic;
  signal tx_ram_we      : std_logic;
  signal fg_ram_we      : std_logic;
  signal bg_ram_we      : std_logic;
  signal sprite_ram_we  : std_logic;
  signal palette_ram_we : std_logic;

  -- determines whether a number is between two numbers (i.e a <= n <= b)
  function between(
    n : unsigned;
    a : unsigned;
    b : unsigned) return boolean is
  begin
    return (n >= a and n <= b);
  end between;
begin
  clock_divider : process(clk)
    variable n : unsigned(31 downto 0);
  begin
    if rising_edge(clk) then
      n := n + 1;
    end if;
    cpu_clk <= not n(18);
  end process;

  -- main rom: $0000-$bfff
  main_rom : entity work.single_port_rom
  generic map(ADDR_WIDTH => 16, DATA_WIDTH => 8, INIT_FILE => "rom.mif")
  port map(
    clk => clk,
    addr => cpu_addr(15 downto 0),
    data => main_rom_dout
  );

  -- work ram: $c000-$cfff
  --
  -- TODO
  -- tx ram: $d000-$d7ff
  -- fg ram: $d800-$dbff
  -- bg ram: $dc00-$dfff
  -- sprite ram: $e000-$e7ff
  -- palette ram: $e800-$efff
  work_ram : entity work.single_port_ram
  generic map(ADDR_WIDTH => 12, DATA_WIDTH => 8)
  port map(
    clk => clk,
    addr => cpu_addr(11 downto 0),
    din => cpu_dout,
    dout => work_ram_dout,
    we => work_ram_we
  );

  -- bank switched rom: $f000-$f7ff
  bank_rom : entity work.single_port_rom
  generic map(ADDR_WIDTH => 15, DATA_WIDTH => 8, INIT_FILE => "cpu_5j.mif")
  port map(
    clk => clk,
    addr => cpu_addr(14 downto 0),
    data => bank_dout
  );

  -- main cpu
  cpu : entity work.T80s
  port map(
    RESET_n => '1',
    CLK     => clk,
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
    DI      => cpu_din,
    DO      => cpu_dout
  );

  -- ram write enable
  work_ram_we <= current_chip = WORK_RAM_CS and cpu_wr_n = '0';

  -- enable chip selects for the current address
  current_chip <= ROM_CS         when between(unsigned(cpu_addr), X"0000", X"bfff") else
                  WORK_RAM_CS    when between(unsigned(cpu_addr), X"c000", X"cfff") else
                  FG_RAM_CS      when between(unsigned(cpu_addr), X"d800", X"dbff") else
                  BG_RAM_CS      when between(unsigned(cpu_addr), X"dc00", X"dfff") else
                  TX_RAM_CS      when between(unsigned(cpu_addr), X"d000", X"d7ff") else
                  SPRITE_RAM_CS  when between(unsigned(cpu_addr), X"e000", X"e7ff") else
                  PALETTE_RAM_CS when between(unsigned(cpu_addr), X"e800", X"efff") else
                  BANK_CS        when between(unsigned(cpu_addr), X"f000", X"f7ff") else
                  UNKNOWN_CS;

  -- cpu data input bus muxing
  cpu_din <= main_rom_dout    when cpu_mreq_n = '0' and current_chip = ROM_CS else
             work_ram_dout    when cpu_mreq_n = '0' and current_chip = WORK_RAM_CS else
             -- tx_ram_dout      when cpu_mreq_n = '0' and current_chip = TX_RAM_CS else
             -- fg_ram_dout      when cpu_mreq_n = '0' and current_chip = FG_RAM_CS else
             -- bg_ram_dout      when cpu_mreq_n = '0' and current_chip = BG_RAM_CS else
             -- sprite_ram_dout  when cpu_mreq_n = '0' and current_chip = SPRITE_RAM_CS else
             -- palette_ram_dout when cpu_mreq_n = '0' and current_chip = PALETTE_RAM_CS else
             bank_dout        when cpu_mreq_n = '0' and current_chip = BANK_CS else
             (others => '0');

  -- display lower half of the address bus for debugging
  -- led <= cpu_addr(7 downto 0) when cpu_mreq_n = '0' and cpu_rd_n = '0';

  -- display cpu data input bus
  led <= cpu_din;
end arch;
