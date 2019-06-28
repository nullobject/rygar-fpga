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

  -- cpu clock enable
  signal cpu_cen : std_logic;

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

  -- cpu interrupt: when this signal is asserted it triggers an interrupt
  signal cpu_int_n : std_logic := '1';

  -- cpu timing signal
  signal cpu_m1_n : std_logic;

  -- XXX: for debugging
  signal cpu_halt_n : std_logic;

  -- interrupt request acknowledge
  signal irq_ack : std_logic;

  -- chip select signals
  signal prog_rom_1_cs  : std_logic;
  signal prog_rom_2_cs  : std_logic;
  signal prog_rom_3_cs  : std_logic;
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
  signal prog_rom_3_dout  : std_logic_vector(7 downto 0);
  signal work_ram_dout    : std_logic_vector(7 downto 0);
  signal char_ram_dout    : std_logic_vector(7 downto 0);
  signal fg_ram_dout      : std_logic_vector(7 downto 0);
  signal bg_ram_dout      : std_logic_vector(7 downto 0);
  signal sprite_ram_dout  : std_logic_vector(7 downto 0);
  signal palette_ram_dout : std_logic_vector(7 downto 0);

  -- currently selected bank for program rom 3
  signal prog_rom_3_bank : unsigned(3 downto 0);

  signal video_vblank : std_logic;

  signal edge_det : std_logic;
  signal count : unsigned(31 downto 0);
begin
  clock_divider : process(clk)
  begin
    if rising_edge(clk) then
      count <= count + 1;
      edge_det <= count(16);
    end if;
  end process;

  cpu_cen <= (not edge_det) and count(16);

  -- generate cpu reset pulse after powering on, or when KEY0 is pressed
  reset_gen : entity work.reset_gen
  port map(
    clk => clk,
    reset => not key(0),
    reset_n => cpu_reset_n
  );

  video_gen : entity work.video_gen
  port map(
    cen    => '1',
    clk    => clk,
    csync  => open,
    hblank => open,
    hsync  => open,
    vblank => video_vblank,
    vsync  => open
  );

  -- program rom 1 (32kB)
  prog_rom_1 : entity work.single_port_rom
  generic map(ADDR_WIDTH => 15, DATA_WIDTH => 8, INIT_FILE => "cpu_5p.mif")
  port map(
    clk  => clk,
    addr => cpu_addr(14 downto 0),
    dout => prog_rom_1_dout
  );

  -- program rom 2 (16kB)
  prog_rom_2 : entity work.single_port_rom
  generic map(ADDR_WIDTH => 14, DATA_WIDTH => 8, INIT_FILE => "cpu_5m.mif")
  port map(
    clk  => clk,
    addr => cpu_addr(13 downto 0),
    dout => prog_rom_2_dout
  );

  -- program rom 3 (32kB bank switched)
  prog_rom_3 : entity work.single_port_rom
  generic map(ADDR_WIDTH => 15, DATA_WIDTH => 8, INIT_FILE => "cpu_5j.mif")
  port map(
    clk  => clk,
    addr => std_logic_vector(prog_rom_3_bank) & cpu_addr(10 downto 0),
    dout => prog_rom_3_dout
  );

  -- work ram (4kB)
  work_ram : entity work.single_port_ram
  generic map(ADDR_WIDTH => 12, DATA_WIDTH => 8)
  port map(
    clk  => clk,
    addr => cpu_addr(11 downto 0),
    din  => cpu_dout,
    dout => work_ram_dout,
    we   => work_ram_cs and (not cpu_wr_n)
  );

  -- character ram (2kB)
  char_ram : entity work.single_port_ram
  generic map(ADDR_WIDTH => 11, DATA_WIDTH => 8)
  port map(
    clk  => clk,
    addr => cpu_addr(10 downto 0),
    din  => cpu_dout,
    dout => char_ram_dout,
    we   => char_ram_cs and (not cpu_wr_n)
  );

  -- fg ram (1kB)
  fg_ram : entity work.single_port_ram
  generic map(ADDR_WIDTH => 10, DATA_WIDTH => 8)
  port map(
    clk  => clk,
    addr => cpu_addr(9 downto 0),
    din  => cpu_dout,
    dout => fg_ram_dout,
    we   => fg_ram_cs and (not cpu_wr_n)
  );

  -- bg ram (1kB)
  bg_ram : entity work.single_port_ram
  generic map(ADDR_WIDTH => 10, DATA_WIDTH => 8)
  port map(
    clk  => clk,
    addr => cpu_addr(9 downto 0),
    din  => cpu_dout,
    dout => bg_ram_dout,
    we   => bg_ram_cs and (not cpu_wr_n)
  );

  -- sprite ram (2kB)
  sprite_ram : entity work.single_port_ram
  generic map(ADDR_WIDTH => 11, DATA_WIDTH => 8)
  port map(
    clk  => clk,
    addr => cpu_addr(10 downto 0),
    din  => cpu_dout,
    dout => sprite_ram_dout,
    we   => sprite_ram_cs and (not cpu_wr_n)
  );

  -- palette ram (2kB)
  palette_ram : entity work.single_port_ram
  generic map(ADDR_WIDTH => 11, DATA_WIDTH => 8)
  port map(
    clk  => clk,
    addr => cpu_addr(10 downto 0),
    din  => cpu_dout,
    dout => palette_ram_dout,
    we   => palette_ram_cs and (not cpu_wr_n)
  );

  -- main cpu
  cpu : entity work.T80s
  port map(
    RESET_n => cpu_reset_n,
    CLK     => clk,
    CEN     => cpu_cen,
    WAIT_n  => '1',
    INT_n   => cpu_int_n,
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

  -- Enable chip select signals for devices connected to the CPU data bus.
  chip_select : process(cpu_addr, cpu_mreq_n, cpu_rfsh_n, cpu_rd_n, cpu_wr_n)
    variable rd, wr: std_logic;
  begin
    rd := not cpu_rd_n; -- cpu read
    wr := not cpu_wr_n; -- cpu write

    -- deassert all chip selects by default
    prog_rom_1_cs  <= '0';
    prog_rom_2_cs  <= '0';
    prog_rom_3_cs  <= '0';
    work_ram_cs    <= '0';
    char_ram_cs    <= '0';
    fg_ram_cs      <= '0';
    bg_ram_cs      <= '0';
    sprite_ram_cs  <= '0';
    palette_ram_cs <= '0';
    bank_cs        <= '0';

    if cpu_mreq_n = '0' and cpu_rfsh_n = '1' then
      case? cpu_addr(15 downto 10) is
        when "0-----" => prog_rom_1_cs  <= rd;       -- $0000-$7fff PROGRAM ROM 1
        when "10----" => prog_rom_2_cs  <= rd;       -- $8000-$bfff PROGRAM ROM 2
        when "1100--" => work_ram_cs    <= rd or wr; -- $c000-$cfff WORK RAM
        when "11010-" => char_ram_cs    <= rd or wr; -- $d000-$d7ff CHARACTER RAM
        when "110110" => fg_ram_cs      <= rd or wr; -- $d800-$dbff FOREGROUND RAM
        when "110111" => bg_ram_cs      <= rd or wr; -- $dc00-$dfff BACKGROUND RAM
        when "11100-" => sprite_ram_cs  <= rd or wr; -- $e000-$e7ff SPRITE RAM
        when "11101-" => palette_ram_cs <= rd or wr; -- $e800-$efff PALETTE RAM
        when "11110-" => prog_rom_3_cs  <= rd;       -- $f000-$f7ff PROGRAM ROM 3 (BANK SWITCHED)
        when "11111-" =>                             -- $f800-$ffff
          case cpu_addr(3 downto 0) is
            when "1000" => bank_cs      <= wr;       -- $f808 BANK REGISTER
            when others => null;
          end case;
      end case?;
    end if;
  end process;

  -- An interrupt request is triggered when the VBLANK signal is deasserted.
  --
  -- Once the interrupt request is handled by the CPU, it is cleared by
  -- deasserting the INT signal. When the M1 and IORQ signal are asserted, then
  -- the interrupt is cleared.
  irq_ack <= (not cpu_m1_n) and (not cpu_ioreq_n);
  cpu_int_n <= irq_ack when rising_edge(clk) and video_vblank = '0';

  -- The register that controls the currently selected bank of program ROM
  -- 3 (5J) is set from lines 3 to 6 of the data bus.
  prog_rom_3_bank <= unsigned(cpu_dout(6 downto 3)) when rising_edge(clk) and bank_cs = '1';

  -- Connect the selected devices to the CPU data input bus.
  cpu_din <= prog_rom_1_dout when prog_rom_1_cs else
             prog_rom_2_dout when prog_rom_2_cs else
             prog_rom_3_dout when prog_rom_3_cs else
             work_ram_dout when work_ram_cs else
             char_ram_dout when char_ram_cs else
             fg_ram_dout when fg_ram_cs else
             bg_ram_dout when bg_ram_cs else
             sprite_ram_dout when sprite_ram_cs else
             palette_ram_dout when palette_ram_cs else
             (others => '0');

  led <= cpu_din;
  debug <= (not cpu_m1_n) &
           (not cpu_mreq_n) &
           (not cpu_rd_n) &
           (not cpu_wr_n) &
           (not cpu_rfsh_n) &
           (not cpu_halt_n) &
           cpu_addr(9 downto 0);

  -- led(0) <= prog_rom_1_cs;
  -- led(1) <= prog_rom_2_cs;
  -- led(2) <= work_ram_cs;
  -- led(3) <= char_ram_cs;
  -- led(4) <= fg_ram_cs;
  -- led(5) <= bg_ram_cs;
  -- led(6) <= sprite_ram_cs;
  -- led(7) <= palette_ram_cs;
end arch;
