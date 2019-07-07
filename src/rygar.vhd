library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library pll;

entity rygar is
  port (
    -- 50 MHz input clock
    clk : in std_logic;

    -- vga colours
    vga_r, vga_g, vga_b : out std_logic_vector(5 downto 0);

    -- vga horizontal and vertical sync
    vga_hs, vga_vs : out std_logic;

    -- buttons
    key : in std_logic_vector(1 downto 0);

    -- leds
    led : out std_logic_vector(7 downto 0);
    debug : out std_logic_vector(23 downto 0)
  );
end rygar;

architecture arch of rygar is
  -- clock signals
  signal clk_12 : std_logic;
  signal cen_6 : std_logic;
  signal cen_4 : std_logic;

  -- cpu reset
  signal cpu_reset_n : std_logic;

  -- cpu clock enable
  signal cpu_cen : std_logic;

  -- cpu address bus
  signal cpu_addr : std_logic_vector(15 downto 0);

  -- cpu data bus
  signal cpu_din, cpu_dout : std_logic_vector(7 downto 0);

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

  -- cpu halt signal
  signal cpu_halt_n : std_logic;

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

  signal video_hpos, video_vpos : unsigned(8 downto 0);
  signal video_hsync, video_vsync : std_logic;
  signal video_hblank, video_vblank : std_logic;
  signal video_on : std_logic;

  signal video_addr : std_logic_vector(11 downto 0);
  signal video_data : std_logic_vector(7 downto 0);
  signal vblank_t1 : std_logic;
begin
  my_pll : entity pll.pll
  port map (
    refclk   => clk,
    rst      => '0',
    outclk_0 => clk_12,
    locked   => open
  );

  -- generate the 6 MHz clock enable
  clock_divider_6 : entity work.clock_divider
  generic map (DIVISOR => 2)
  port map (clk => clk_12, cen => cen_6);

  -- generate the 4 MHz clock enable
  clock_divider_4 : entity work.clock_divider
  generic map (DIVISOR => 3)
  port map (clk => clk_12, cen => cen_4);

  -- generate cpu reset pulse after powering on, or when KEY0 is pressed
  reset_gen : entity work.reset_gen
  port map (
    clk     => clk_12,
    reset   => not key(0),
    reset_n => cpu_reset_n
  );

  -- video sync generator
  sync_gen : entity work.sync_gen
  port map (
    clk    => clk_12,
    cen    => cen_6,
    hpos   => video_hpos,
    vpos   => video_vpos,
    hsync  => video_hsync,
    vsync  => video_vsync,
    hblank => video_hblank,
    vblank => video_vblank
  );

  -- program rom 1 (32kB)
  prog_rom_1 : entity work.single_port_rom
  generic map (ADDR_WIDTH => 15, DATA_WIDTH => 8, INIT_FILE => "cpu_5p.mif")
  port map (
    clk  => clk_12,
    addr => cpu_addr(14 downto 0),
    dout => prog_rom_1_dout
  );

  -- program rom 2 (16kB)
  prog_rom_2 : entity work.single_port_rom
  generic map (ADDR_WIDTH => 14, DATA_WIDTH => 8, INIT_FILE => "cpu_5m.mif")
  port map (
    clk  => clk_12,
    addr => cpu_addr(13 downto 0),
    dout => prog_rom_2_dout
  );

  -- program rom 3 (32kB bank switched)
  prog_rom_3 : entity work.single_port_rom
  generic map (ADDR_WIDTH => 15, DATA_WIDTH => 8, INIT_FILE => "cpu_5j.mif")
  port map (
    clk  => clk_12,
    addr => std_logic_vector(prog_rom_3_bank) & cpu_addr(10 downto 0),
    dout => prog_rom_3_dout
  );

  -- work ram (4kB)
  work_ram : entity work.dual_port_ram
  generic map (ADDR_WIDTH => 12, DATA_WIDTH => 8)
  port map (
    clk_a  => clk_12,
    cen_a  => work_ram_cs,
    addr_a => cpu_addr(11 downto 0),
    din_a  => cpu_dout,
    dout_a => work_ram_dout,
    we_a   => not cpu_wr_n,

    clk_b  => clk_12,
    addr_b => video_addr,
    dout_b => video_data
  );

  -- character ram (2kB)
  char_ram : entity work.single_port_ram
  generic map (ADDR_WIDTH => 11, DATA_WIDTH => 8)
  port map (
    clk  => clk_12,
    cen  => char_ram_cs,
    addr => cpu_addr(10 downto 0),
    din  => cpu_dout,
    dout => char_ram_dout,
    we   => not cpu_wr_n
  );

  -- fg ram (1kB)
  fg_ram : entity work.single_port_ram
  generic map (ADDR_WIDTH => 10, DATA_WIDTH => 8)
  port map (
    clk  => clk_12,
    cen  => fg_ram_cs,
    addr => cpu_addr(9 downto 0),
    din  => cpu_dout,
    dout => fg_ram_dout,
    we   => not cpu_wr_n
  );

  -- bg ram (1kB)
  bg_ram : entity work.single_port_ram
  generic map (ADDR_WIDTH => 10, DATA_WIDTH => 8)
  port map (
    clk  => clk_12,
    cen  => bg_ram_cs,
    addr => cpu_addr(9 downto 0),
    din  => cpu_dout,
    dout => bg_ram_dout,
    we   => not cpu_wr_n
  );

  -- sprite ram (2kB)
  sprite_ram : entity work.single_port_ram
  generic map (ADDR_WIDTH => 11, DATA_WIDTH => 8)
  port map (
    clk  => clk_12,
    cen  => sprite_ram_cs,
    addr => cpu_addr(10 downto 0),
    din  => cpu_dout,
    dout => sprite_ram_dout,
    we   => not cpu_wr_n
  );

  -- palette ram (2kB)
  palette_ram : entity work.single_port_ram
  generic map (ADDR_WIDTH => 11, DATA_WIDTH => 8)
  port map (
    clk  => clk_12,
    cen  => palette_ram_cs,
    addr => cpu_addr(10 downto 0),
    din  => cpu_dout,
    dout => palette_ram_dout,
    we   => not cpu_wr_n
  );

  -- main cpu
  cpu : entity work.T80s
  port map (
    RESET_n => cpu_reset_n,
    CLK     => clk_12,
    CEN     => cen_4,
    WAIT_n  => '1',
    INT_n   => cpu_int_n,
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

  -- An interrupt is triggered on the falling edge of the VBLANK signal.
  --
  -- Once the interrupt request has been accepted by the CPU, it is
  -- acknowledged by activating the IORQ signal during the M1 cycle. This
  -- disables the interrupt signal, and the cycle starts over.
  irq : process(clk_12)
  begin
    if rising_edge(clk_12) then
      vblank_t1 <= video_vblank;

      if cpu_m1_n = '0' and cpu_ioreq_n = '0' then
        cpu_int_n <= '1';
      elsif vblank_t1 = '1' and video_vblank = '0' then
        cpu_int_n <= '0';
      end if;
    end if;
  end process;

  -- Setting the bank register changes the currently selected bank of program
  -- ROM 3.
  bank_register : process(clk_12)
  begin
    if rising_edge(clk_12) then
      if bank_cs = '1' and cpu_wr_n = '0' then
        -- flip-flop 6J uses data lines 3 to 6
        prog_rom_3_bank <= unsigned(cpu_dout(6 downto 3));
      end if;
    end if;
  end process;

  -- $0000-$7fff PROGRAM ROM 1
  -- $8000-$bfff PROGRAM ROM 2
  -- $c000-$cfff WORK RAM
  -- $d000-$d7ff CHARACTER RAM
  -- $d800-$dbff FOREGROUND RAM
  -- $dc00-$dfff BACKGROUND RAM
  -- $e000-$e7ff SPRITE RAM
  -- $e800-$efff PALETTE RAM
  -- $f000-$f7ff PROGRAM ROM 3 (BANK SWITCHED)
  -- $f800-$ffff
  prog_rom_1_cs  <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"0000" and unsigned(cpu_addr) <= x"7fff" else '0';
  prog_rom_2_cs  <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"8000" and unsigned(cpu_addr) <= x"bfff" else '0';
  work_ram_cs    <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"c000" and unsigned(cpu_addr) <= x"cfff" else '0';
  char_ram_cs    <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"d000" and unsigned(cpu_addr) <= x"d7ff" else '0';
  fg_ram_cs      <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"d800" and unsigned(cpu_addr) <= x"dbff" else '0';
  bg_ram_cs      <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"dc00" and unsigned(cpu_addr) <= x"dfff" else '0';
  sprite_ram_cs  <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"e000" and unsigned(cpu_addr) <= x"e7ff" else '0';
  palette_ram_cs <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"e800" and unsigned(cpu_addr) <= x"efff" else '0';
  prog_rom_3_cs  <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) >= x"f000" and unsigned(cpu_addr) <= x"f7ff" else '0';
  bank_cs        <= '1' when cpu_mreq_n = '0' and cpu_rfsh_n = '1' and unsigned(cpu_addr) = x"f808" else '0';

  -- Connect the selected devices to the CPU data input bus.
  cpu_din <= prog_rom_1_dout when prog_rom_1_cs = '1' else
             prog_rom_2_dout when prog_rom_2_cs = '1' else
             prog_rom_3_dout when prog_rom_3_cs = '1' else
             work_ram_dout when work_ram_cs = '1' else
             char_ram_dout when char_ram_cs = '1' else
             fg_ram_dout when fg_ram_cs = '1' else
             bg_ram_dout when bg_ram_cs = '1' else
             sprite_ram_dout when sprite_ram_cs = '1' else
             palette_ram_dout when palette_ram_cs = '1' else
             (others => '0');

  led <= cpu_dout when work_ram_cs = '1' and cpu_wr_n = '0' else (others => '0');

  -- output flags and 8 lsb address lines
  debug(15 downto 0) <= (not cpu_m1_n) &
                        (not cpu_mreq_n) &
                        (not cpu_rd_n) &
                        (not cpu_wr_n) &
                        (not cpu_rfsh_n) &
                        (not cpu_halt_n) &
                        cpu_addr(9 downto 0);
  debug(16) <= clk_12;
  debug(17) <= cen_4;
  debug(18) <= cen_6;
  debug(19) <= video_vsync;
  debug(20) <= video_vblank;
  debug(21) <= cpu_int_n;
  debug(22) <= cpu_m1_n;
  debug(23) <= cpu_ioreq_n;

  video_on <= not (video_hblank or video_vblank);
  vga_hs <= not (video_hsync xor video_vsync);
  vga_vs <= '1';

  video_addr <= std_logic_vector(video_vpos(3 downto 0)) & std_logic_vector(video_hpos(7 downto 0));

  process(clk_12)
  begin
    if rising_edge(clk_12) then
      if video_on = '1' then
        vga_r <= std_logic_vector(to_unsigned(to_integer(unsigned(video_data)) * 6 / 10, vga_r'length));
      else
        vga_r <= (others => '0');
      end if;
    end if;
  end process;
end arch;
