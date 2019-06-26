library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rygar is
  port(
    clk : in std_logic;
    key : in std_logic_vector(1 downto 0);
    led : out std_logic_vector(7 downto 0);
    debug : out std_logic_vector(15 downto 0)
  );
end rygar;

architecture arch of rygar is
  -- cpu reset
  signal cpu_reset_n : std_logic;

  -- cpu clock
  signal cpu_clk : std_logic;

  -- cpu address bus
  signal cpu_addr : std_logic_vector(15 downto 0);

  -- cpu data bus
  signal cpu_din  : std_logic_vector(7 downto 0);
  signal cpu_dout : std_logic_vector(7 downto 0);

  -- cpu io request: the address bus holds a valid address for an i/o read or
  -- write operation
  signal cpu_ioreq_n : std_logic;

  -- cpu memory request: the address bus holds a valid address for a memory
  -- read or write operation
  signal cpu_mreq_n : std_logic;

  -- cpu read: ready to read data from the data bus
  signal cpu_rd_n : std_logic;

  -- cpu write: the data bus contains a byte to write somewhere
  signal cpu_wr_n : std_logic;

  -- cpu refresh: the lower seven bits of the address bus should be refreshed
  signal cpu_rfsh_n : std_logic;

  -- XXX: for debugging
  signal cpu_m1_n : std_logic;
  signal cpu_halt_n : std_logic;

  -- chip select signals
  signal prog_rom_1_cs  : std_logic;
  signal prog_rom_2_cs  : std_logic;
  signal work_ram_cs    : std_logic;
  signal char_ram_cs    : std_logic;
  signal fg_ram_cs      : std_logic;
  signal bg_ram_cs      : std_logic;
  signal sprite_ram_cs  : std_logic;
  signal palette_ram_cs : std_logic;
  signal bank_cs        : std_logic;

  -- chip data output signals
  signal prog_rom_1_dout  : std_logic_vector(7 downto 0);
  signal prog_rom_2_dout  : std_logic_vector(7 downto 0);
  signal work_ram_dout    : std_logic_vector(7 downto 0);
  signal char_ram_dout    : std_logic_vector(7 downto 0);
  signal fg_ram_dout      : std_logic_vector(7 downto 0);
  signal bg_ram_dout      : std_logic_vector(7 downto 0);
  signal sprite_ram_dout  : std_logic_vector(7 downto 0);
  signal palette_ram_dout : std_logic_vector(7 downto 0);
  signal bank_dout        : std_logic_vector(7 downto 0);

  signal current_bank : unsigned(3 downto 0);

  signal edge_det : std_logic;
  signal count : unsigned(31 downto 0);
begin
  clock_divider : process(clk)
  begin
    if rising_edge(clk) then
      count <= count + 1;
      edge_det <= count(22);
    end if;
  end process;

  cpu_clk <= (not edge_det) and count(22);

  -- Generate a one clock reset pulse after power on, or if KEY0 is pressed.
  --
  -- The Z80 needs to be reset after power on, otherwise it may receive garbage data from the
  reset_gen : process(clk)
    variable r : std_logic;
  begin
    if falling_edge(clk) then
      if not key(0) then
        cpu_reset_n <= '0';
        r := '0';
      else
        cpu_reset_n <= r;
        r := '1';
      end if;
    end if;
  end process;

  -- prog rom 1: $0000-$7fff
  prog_rom_1 : entity work.single_port_rom
  generic map(ADDR_WIDTH => 15, DATA_WIDTH => 8, INIT_FILE => "cpu_5p.mif")
  port map(
    clk  => clk,
    addr => cpu_addr(14 downto 0),
    dout => prog_rom_1_dout
  );

  -- prog rom 2: $8000-$bfff
  prog_rom_2 : entity work.single_port_rom
  generic map(ADDR_WIDTH => 14, DATA_WIDTH => 8, INIT_FILE => "cpu_5m.mif")
  port map(
    clk  => clk,
    addr => cpu_addr(13 downto 0),
    dout => prog_rom_2_dout
  );

  -- work ram: $c000-$cfff
  work_ram : entity work.single_port_ram
  generic map(ADDR_WIDTH => 12, DATA_WIDTH => 8)
  port map(
    clk  => clk,
    addr => cpu_addr(11 downto 0),
    din  => cpu_dout,
    dout => work_ram_dout,
    we   => work_ram_cs and (not cpu_wr_n)
  );

  -- char ram: $d000-$d7ff
  char_ram : entity work.single_port_ram
  generic map(ADDR_WIDTH => 11, DATA_WIDTH => 8)
  port map(
    clk  => clk,
    addr => cpu_addr(10 downto 0),
    din  => cpu_dout,
    dout => char_ram_dout,
    we   => char_ram_cs and (not cpu_wr_n)
  );

  -- fg ram: $d800-$dbff
  fg_ram : entity work.single_port_ram
  generic map(ADDR_WIDTH => 10, DATA_WIDTH => 8)
  port map(
    clk  => clk,
    addr => cpu_addr(9 downto 0),
    din  => cpu_dout,
    dout => fg_ram_dout,
    we   => fg_ram_cs and (not cpu_wr_n)
  );

  -- bg ram: $dc00-$dfff
  bg_ram : entity work.single_port_ram
  generic map(ADDR_WIDTH => 10, DATA_WIDTH => 8)
  port map(
    clk  => clk,
    addr => cpu_addr(9 downto 0),
    din  => cpu_dout,
    dout => bg_ram_dout,
    we   => bg_ram_cs and (not cpu_wr_n)
  );

  -- sprite ram: $e000-$e7ff
  sprite_ram : entity work.single_port_ram
  generic map(ADDR_WIDTH => 11, DATA_WIDTH => 8)
  port map(
    clk  => clk,
    addr => cpu_addr(10 downto 0),
    din  => cpu_dout,
    dout => sprite_ram_dout,
    we   => sprite_ram_cs and (not cpu_wr_n)
  );

  -- palette ram: $e800-$efff
  palette_ram : entity work.single_port_ram
  generic map(ADDR_WIDTH => 11, DATA_WIDTH => 8)
  port map(
    clk  => clk,
    addr => cpu_addr(10 downto 0),
    din  => cpu_dout,
    dout => palette_ram_dout,
    we   => palette_ram_cs and (not cpu_wr_n)
  );

  -- bank switched rom: $f000-$f7ff
  bank : entity work.single_port_rom
  generic map(ADDR_WIDTH => 15, DATA_WIDTH => 8, INIT_FILE => "cpu_5j.mif")
  port map(
    clk  => clk,
    addr => std_logic_vector(current_bank) & cpu_addr(10 downto 0),
    dout => bank_dout
  );

  -- main cpu
  cpu : entity work.T80s
  generic map(T2Write => 1)
  port map(
    RESET_n => cpu_reset_n,
    CLK     => clk,
    CEN     => cpu_clk,
    WAIT_n  => '1',
    INT_n   => '1',
    NMI_n   => '1',
    BUSRQ_n => '1',
    M1_n    => cpu_m1_n,
    MREQ_n  => cpu_mreq_n,
    IORQ_n  => cpu_ioreq_n,
    RD_n    => cpu_rd_n,
    WR_n    => cpu_wr_n,
    RFSH_n  => cpu_rfsh_n,
    HALT_n  => cpu_halt_n,
    BUSAK_n => open,
    A       => cpu_addr,
    DI      => cpu_din,
    DO      => cpu_dout
  );

  -- enable chip select signals for the current cpu address
  chip_select : process(cpu_addr, cpu_mreq_n, cpu_rfsh_n, cpu_halt_n)
  begin
    prog_rom_1_cs  <= '0';
    prog_rom_2_cs  <= '0';
    work_ram_cs    <= '0';
    char_ram_cs    <= '0';
    fg_ram_cs      <= '0';
    bg_ram_cs      <= '0';
    sprite_ram_cs  <= '0';
    palette_ram_cs <= '0';
    bank_cs        <= '0';

    if cpu_mreq_n = '0' and cpu_rfsh_n = '1' then
      case? cpu_addr(15 downto 10) is
        when "0-----" => prog_rom_1_cs  <= '1'; -- $0000-$7fff
        when "10----" => prog_rom_2_cs  <= '1'; -- $8000-$bfff
        when "1100--" => work_ram_cs    <= '1'; -- $c000-$cfff
        when "11010-" => char_ram_cs    <= '1'; -- $d000-$d7ff
        when "110110" => fg_ram_cs      <= '1'; -- $d800-$dbff
        when "110111" => bg_ram_cs      <= '1'; -- $dc00-$dfff
        when "11100-" => sprite_ram_cs  <= '1'; -- $e000-$e7ff
        when "11101-" => palette_ram_cs <= '1'; -- $e800-$efff
        when "11110-" => bank_cs        <= '1'; -- $f000-$f7ff
        when "11111-" => null;                  -- $f800-$ffff
      end case?;
    end if;
  end process;

  -- register $f808 sets the current bank
  current_bank <= unsigned(cpu_dout(6 downto 3)) when rising_edge(clk) and cpu_mreq_n = '0' and cpu_wr_n = '0' and cpu_addr = X"f808";

  -- multiplex cpu data input bus
  cpu_din <= (others => '0') when cpu_rd_n = '1' else
             prog_rom_1_dout when prog_rom_1_cs = '1' else
             prog_rom_2_dout when prog_rom_2_cs = '1' else
             work_ram_dout when work_ram_cs else
             char_ram_dout when char_ram_cs else
             fg_ram_dout when fg_ram_cs else
             bg_ram_dout when bg_ram_cs else
             sprite_ram_dout when sprite_ram_cs else
             palette_ram_dout when palette_ram_cs else
             bank_dout when bank_cs = '1' else
             (others => '0');

  led <= cpu_din;
  debug <= (not cpu_m1_n) & (not cpu_mreq_n) & (not cpu_rd_n) & (not cpu_wr_n) & (not cpu_rfsh_n) & (not cpu_halt_n) & cpu_addr(9 downto 0);

  -- led(0) <= prog_rom_1_cs;
  -- led(1) <= prog_rom_2_cs;
  -- led(2) <= work_ram_cs;
  -- led(3) <= char_ram_cs;
  -- led(4) <= fg_ram_cs;
  -- led(5) <= bg_ram_cs;
  -- led(6) <= sprite_ram_cs;
  -- led(7) <= palette_ram_cs;
end arch;
