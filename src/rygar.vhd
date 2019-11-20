-- Copyright (c) 2019 Josh Bassett
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common.all;

entity rygar is
  port (
    -- reset
    reset : in std_logic;

    -- clock
    clk : in std_logic;

    -- clock enable signals
    cen_384 : buffer std_logic;
    cen_12  : buffer std_logic;
    cen_6   : buffer std_logic;
    cen_4   : buffer std_logic;

    -- player controls
    joystick_1 : in byte_t;
    joystick_2 : in byte_t;
    start_1    : in std_logic;
    start_2    : in std_logic;
    coin_1     : in std_logic;
    coin_2     : in std_logic;

    -- DIP switches
    dip_allow_continue : in std_logic;
    dip_bonus_life     : in std_logic_vector(1 downto 0);
    dip_cabinet        : in std_logic;
    dip_difficulty     : in std_logic_vector(1 downto 0);
    dip_lives          : in std_logic_vector(1 downto 0);

    -- SDRAM interface
    sdram_addr  : out unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
    sdram_data  : out std_logic_vector(SDRAM_CTRL_DATA_WIDTH-1 downto 0);
    sdram_we    : out std_logic;
    sdram_req   : out std_logic;
    sdram_ack   : in std_logic;
    sdram_valid : in std_logic;
    sdram_q     : in std_logic_vector(SDRAM_CTRL_DATA_WIDTH-1 downto 0);

    -- IOCTL interface
    ioctl_addr     : in unsigned(IOCTL_ADDR_WIDTH-1 downto 0);
    ioctl_data     : in byte_t;
    ioctl_wr       : in std_logic;
    ioctl_download : in std_logic;

    -- video signals
    hsync  : out std_logic;
    vsync  : out std_logic;
    hblank : out std_logic;
    vblank : out std_logic;

    -- RGB
    r : out std_logic_vector(COLOR_DEPTH_R-1 downto 0);
    g : out std_logic_vector(COLOR_DEPTH_G-1 downto 0);
    b : out std_logic_vector(COLOR_DEPTH_B-1 downto 0);

    audio : out audio_t
  );
end rygar;

architecture arch of rygar is
  -- the number of banks in program ROM #3
  constant BANKS : natural := 16;

  -- the number of bits in the bank register
  constant BANK_REG_WIDTH : natural := ilog2(BANKS);

  -- CPU signals
  signal cpu_cen     : std_logic;
  signal cpu_addr    : unsigned(CPU_ADDR_WIDTH-1 downto 0);
  signal cpu_din     : byte_t;
  signal cpu_dout    : byte_t;
  signal cpu_ioreq_n : std_logic;
  signal cpu_mreq_n  : std_logic;
  signal cpu_rd_n    : std_logic;
  signal cpu_wr_n    : std_logic;
  signal cpu_rfsh_n  : std_logic;
  signal cpu_int_n   : std_logic := '1';
  signal cpu_m1_n    : std_logic;

  -- chip select signals
  signal prog_rom_1_cs  : std_logic;
  signal prog_rom_2_cs  : std_logic;
  signal prog_rom_3_cs  : std_logic;
  signal work_ram_cs    : std_logic;
  signal sprite_ram_cs  : std_logic;
  signal char_ram_cs    : std_logic;
  signal fg_ram_cs      : std_logic;
  signal bg_ram_cs      : std_logic;
  signal palette_ram_cs : std_logic;
  signal scroll_cs      : std_logic;
  signal player_1_cs    : std_logic;
  signal player_2_cs    : std_logic;
  signal coin_cs        : std_logic;
  signal dip_sw_1_cs    : std_logic;
  signal dip_sw_2_cs    : std_logic;
  signal bank_cs        : std_logic;
  signal sound_cs       : std_logic;

  -- ROM signals
  signal sprite_rom_addr : unsigned(SPRITE_ROM_ADDR_WIDTH-1 downto 0);
  signal sprite_rom_data : std_logic_vector(SPRITE_ROM_DATA_WIDTH-1 downto 0);
  signal char_rom_addr   : unsigned(CHAR_ROM_ADDR_WIDTH-1 downto 0);
  signal char_rom_data   : std_logic_vector(CHAR_ROM_DATA_WIDTH-1 downto 0);
  signal fg_rom_addr     : unsigned(FG_ROM_ADDR_WIDTH-1 downto 0);
  signal fg_rom_data     : std_logic_vector(FG_ROM_DATA_WIDTH-1 downto 0);
  signal bg_rom_addr     : unsigned(BG_ROM_ADDR_WIDTH-1 downto 0);
  signal bg_rom_data     : std_logic_vector(BG_ROM_DATA_WIDTH-1 downto 0);

  -- data output signals
  signal prog_rom_1_dout : byte_t;
  signal prog_rom_2_dout : byte_t;
  signal prog_rom_3_dout : byte_t;
  signal work_ram_dout   : byte_t;
  signal gpu_dout        : byte_t;
  signal io_dout         : nibble_t;

  -- download signals
  signal download_addr : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
  signal download_data : std_logic_vector(SDRAM_CTRL_DATA_WIDTH-1 downto 0);
  signal download_req  : std_logic;

  -- registers
  signal fg_scroll_pos_reg : pos_t := (x => (others => '0'), y => (others => '0'));
  signal bg_scroll_pos_reg : pos_t := (x => (others => '0'), y => (others => '0'));
  signal bank_reg          : unsigned(BANK_REG_WIDTH-1 downto 0);

  -- video signals
  signal video : video_t;

  -- control signals
  signal vblank_falling : std_logic;

  -- RGB data
  signal rgb : rgb_t;
begin
  -- generate a 12MHz clock enable signal
  clock_divider_12 : entity work.clock_divider
  generic map (DIVISOR => 4)
  port map (clk => clk, cen => cen_12);

  -- generate a 6MHz clock enable signal
  clock_divider_6 : entity work.clock_divider
  generic map (DIVISOR => 8)
  port map (clk => clk, cen => cen_6);

  -- generate a 4MHz clock enable signal
  clock_divider_4 : entity work.clock_divider
  generic map (DIVISOR => 12)
  port map (clk => clk, cen => cen_4);

  -- generate a 384KHz clock enable signal
  clock_divider_384 : entity work.clock_divider
  generic map (DIVISOR => 125)
  port map (clk => clk, cen => cen_384);

  -- detect falling edges of the VBLANK signal
  vblank_edge_detector : entity work.edge_detector
  generic map (FALLING => true)
  port map (
    clk  => clk,
    data => video.vblank,
    q    => vblank_falling
  );

  -- work RAM
  work_ram : entity work.single_port_ram
  generic map (ADDR_WIDTH => WORK_RAM_ADDR_WIDTH)
  port map (
    clk  => clk,
    cs   => work_ram_cs,
    addr => cpu_addr(WORK_RAM_ADDR_WIDTH-1 downto 0),
    din  => cpu_dout,
    dout => work_ram_dout,
    we   => not cpu_wr_n
  );

  -- The SDRAM controller has a 32-bit interface, so we need to buffer the
  -- bytes received from the IOCTL interface in order to write 32-bit words to
  -- the SDRAM.
  download_buffer : entity work.download_buffer
  generic map (SIZE => 4)
  port map (
    clk   => clk,
    din   => ioctl_data,
    dout  => download_data,
    we    => ioctl_download and ioctl_wr,
    valid => download_req
  );

  -- ROM controller
  rom_controller : entity work.rom_controller
  port map (
    reset => reset,
    clk   => clk,

    -- program ROM #1 interface
    prog_rom_1_cs   => prog_rom_1_cs and cpu_rfsh_n and not ioctl_download,
    prog_rom_1_oe   => not cpu_rd_n,
    prog_rom_1_addr => cpu_addr(PROG_ROM_1_ADDR_WIDTH-1 downto 0),
    prog_rom_1_data => prog_rom_1_dout,

    -- program ROM #2 interface
    prog_rom_2_cs   => prog_rom_2_cs and cpu_rfsh_n and not ioctl_download,
    prog_rom_2_oe   => not cpu_rd_n,
    prog_rom_2_addr => cpu_addr(PROG_ROM_2_ADDR_WIDTH-1 downto 0),
    prog_rom_2_data => prog_rom_2_dout,

    -- program ROM #3 interface
    prog_rom_3_cs   => prog_rom_3_cs and cpu_rfsh_n and not ioctl_download,
    prog_rom_3_oe   => not cpu_rd_n,
    prog_rom_3_addr => bank_reg & cpu_addr(PROG_ROM_3_ADDR_WIDTH-BANK_REG_WIDTH-1 downto 0),
    prog_rom_3_data => prog_rom_3_dout,

    -- sprite ROM interface
    sprite_rom_cs   => not ioctl_download,
    sprite_rom_oe   => '1',
    sprite_rom_addr => sprite_rom_addr,
    sprite_rom_data => sprite_rom_data,

    -- character ROM interface
    char_rom_cs   => not ioctl_download,
    char_rom_oe   => '1',
    char_rom_addr => char_rom_addr,
    char_rom_data => char_rom_data,

    -- foreground ROM interface
    fg_rom_cs   => not ioctl_download,
    fg_rom_oe   => '1',
    fg_rom_addr => fg_rom_addr,
    fg_rom_data => fg_rom_data,

    -- background ROM interface
    bg_rom_cs   => not ioctl_download,
    bg_rom_oe   => '1',
    bg_rom_addr => bg_rom_addr,
    bg_rom_data => bg_rom_data,

    -- download interface
    download_addr => download_addr,
    download_data => download_data,
    download_we   => ioctl_download,
    download_req  => download_req,

    -- SDRAM interface
    sdram_addr  => sdram_addr,
    sdram_data  => sdram_data,
    sdram_we    => sdram_we,
    sdram_req   => sdram_req,
    sdram_ack   => sdram_ack,
    sdram_valid => sdram_valid,
    sdram_q     => sdram_q
  );

  -- main CPU
  cpu : entity work.T80s
  port map (
    RESET_n             => not reset,
    CLK                 => clk,
    CEN                 => cen_4,
    INT_n               => cpu_int_n,
    M1_n                => cpu_m1_n,
    MREQ_n              => cpu_mreq_n,
    IORQ_n              => cpu_ioreq_n,
    RD_n                => cpu_rd_n,
    WR_n                => cpu_wr_n,
    RFSH_n              => cpu_rfsh_n,
    HALT_n              => open,
    BUSAK_n             => open,
    std_logic_vector(A) => cpu_addr,
    DI                  => cpu_din,
    DO                  => cpu_dout
  );

  -- GPU
  gpu : entity work.gpu
  generic map (
    SPRITE_LAYER_ENABLE => true,
    CHAR_LAYER_ENABLE   => true,
    FG_LAYER_ENABLE     => true,
    BG_LAYER_ENABLE     => true
  )
  port map (
    -- clock signals
    clk   => clk,
    cen_6 => cen_6,

    -- RAM interface
    ram_addr => cpu_addr,
    ram_din  => cpu_dout,
    ram_dout => gpu_dout,
    ram_we   => not cpu_wr_n,

    -- tile ROM interface
    sprite_rom_addr => sprite_rom_addr,
    sprite_rom_data => sprite_rom_data,
    char_rom_addr   => char_rom_addr,
    char_rom_data   => char_rom_data,
    fg_rom_addr     => fg_rom_addr,
    fg_rom_data     => fg_rom_data,
    bg_rom_addr     => bg_rom_addr,
    bg_rom_data     => bg_rom_data,

    -- chip select signals
    sprite_ram_cs  => sprite_ram_cs,
    char_ram_cs    => char_ram_cs,
    fg_ram_cs      => fg_ram_cs,
    bg_ram_cs      => bg_ram_cs,
    palette_ram_cs => palette_ram_cs,

    -- scroll layer positions
    fg_scroll_pos => fg_scroll_pos_reg,
    bg_scroll_pos => bg_scroll_pos_reg,

    -- video signals
    video => video,
    rgb   => rgb
  );

  -- A request is sent to the sound subsystem when the CPU writes a byte to
  -- address 0xf806.
  sound : entity work.sound
  port map (
    reset   => reset,
    clk     => clk,
    cen_4   => cen_4,
    cen_384 => cen_384,
    req     => sound_cs and not cpu_wr_n,
    data    => cpu_dout,
    audio   => audio
  );

  -- Trigger an interrupt on the falling edge of the VBLANK signal.
  --
  -- Once the interrupt request has been accepted by the CPU, it is
  -- acknowledged by activating the IORQ signal during the M1 cycle. This
  -- disables the interrupt signal, and the cycle starts over.
  irq : process (clk)
  begin
    if rising_edge(clk) then
      if cpu_m1_n = '0' and cpu_ioreq_n = '0' then
        cpu_int_n <= '1';
      elsif vblank_falling = '1' then
        cpu_int_n <= '0';
      end if;
    end if;
  end process;

  -- The bank register selects the current bank for program ROM 3.
  set_bank_register : process (clk)
  begin
    if rising_edge(clk) then
      if bank_cs = '1' and cpu_wr_n = '0' then
        -- from the schematic, flip-flop 6J uses data bus lines 3 to 6
        bank_reg <= unsigned(cpu_dout(6 downto 3));
      end if;
    end if;
  end process;

  -- set foreground and background scroll position registers
  set_scroll_pos_registers : process (clk)
  begin
    if rising_edge(clk) then
      if scroll_cs = '1' and cpu_wr_n = '0' then
        case cpu_addr(2 downto 0) is
          when "000" => fg_scroll_pos_reg.x(7 downto 0) <= unsigned(cpu_dout(7 downto 0));
          when "001" => fg_scroll_pos_reg.x(8 downto 8) <= unsigned(cpu_dout(0 downto 0));
          when "010" => fg_scroll_pos_reg.y(7 downto 0) <= unsigned(cpu_dout(7 downto 0));
          when "011" => bg_scroll_pos_reg.x(7 downto 0) <= unsigned(cpu_dout(7 downto 0));
          when "100" => bg_scroll_pos_reg.x(8 downto 8) <= unsigned(cpu_dout(0 downto 0));
          when "101" => bg_scroll_pos_reg.y(7 downto 0) <= unsigned(cpu_dout(7 downto 0));
          when others => null;
        end case;
      end if;
    end if;
  end process;

  -- we need to divide the address by four, because we're converting from
  -- a 8-bit IOCTL address to a 32-bit SDRAM address
  download_addr <= resize(shift_right(ioctl_addr, 2), download_addr'length);

  -- mux joystick, coin, and DIP switch data
  io_dout <= joystick_1(3 downto 0)              when player_1_cs = '1' and cpu_rd_n = '0' and cpu_addr(0) = '0' else
             joystick_1(7 downto 4)              when player_1_cs = '1' and cpu_rd_n = '0' and cpu_addr(0) = '1' else
             joystick_2(3 downto 0)              when player_2_cs = '1' and cpu_rd_n = '0' and cpu_addr(0) = '0' else
             joystick_2(7 downto 4)              when player_2_cs = '1' and cpu_rd_n = '0' and cpu_addr(0) = '1' else
             coin_1 & coin_2 & start_1 & start_2 when coin_cs     = '1' and cpu_rd_n = '0' and cpu_addr(0) = '0' else
             "0" & dip_cabinet & dip_lives       when dip_sw_1_cs = '1' and cpu_rd_n = '0' and cpu_addr(0) = '1' else
             dip_difficulty & dip_bonus_life     when dip_sw_2_cs = '1' and cpu_rd_n = '0' and cpu_addr(0) = '0' else
             dip_allow_continue & "000"          when dip_sw_2_cs = '1' and cpu_rd_n = '0' and cpu_addr(0) = '1' else
             (others => '0');

  --  address    description
  -- ----------+-----------------
  -- 0000-7fff | program ROM 1
  -- 8000-bfff | program ROM 2
  -- c000-cfff | work RAM
  -- d000-d7ff | character RAM
  -- d800-dbff | foreground RAM
  -- dc00-dfff | background RAM
  -- e000-e7ff | sprite RAM
  -- e800-efff | palette RAM
  -- f000-f7ff | program ROM 3
  -- f800-f805 | scroll registers
  --      f807 | sound
  --      f808 | bank register
  -- f800-f801 | player 1
  -- f802-f803 | player 2
  --      f804 | coin
  -- f806-f807 | DIP switch 1
  -- f808-f809 | DIP switch 2
  prog_rom_1_cs  <= '1' when cpu_addr >= x"0000" and cpu_addr <= x"7fff" else '0';
  prog_rom_2_cs  <= '1' when cpu_addr >= x"8000" and cpu_addr <= x"bfff" else '0';
  work_ram_cs    <= '1' when cpu_addr >= x"c000" and cpu_addr <= x"cfff" else '0';
  char_ram_cs    <= '1' when cpu_addr >= x"d000" and cpu_addr <= x"d7ff" else '0';
  fg_ram_cs      <= '1' when cpu_addr >= x"d800" and cpu_addr <= x"dbff" else '0';
  bg_ram_cs      <= '1' when cpu_addr >= x"dc00" and cpu_addr <= x"dfff" else '0';
  sprite_ram_cs  <= '1' when cpu_addr >= x"e000" and cpu_addr <= x"e7ff" else '0';
  palette_ram_cs <= '1' when cpu_addr >= x"e800" and cpu_addr <= x"efff" else '0';
  prog_rom_3_cs  <= '1' when cpu_addr >= x"f000" and cpu_addr <= x"f7ff" else '0';
  scroll_cs      <= '1' when cpu_addr >= x"f800" and cpu_addr <= x"f805" else '0';
  sound_cs       <= '1' when cpu_addr  = x"f806"                         else '0';
  bank_cs        <= '1' when cpu_addr  = x"f808"                         else '0';
  player_1_cs    <= '1' when cpu_addr >= x"f800" and cpu_addr <= x"f801" else '0';
  player_2_cs    <= '1' when cpu_addr >= x"f802" and cpu_addr <= x"f803" else '0';
  coin_cs        <= '1' when cpu_addr  = x"f804"                         else '0';
  dip_sw_1_cs    <= '1' when cpu_addr >= x"f806" and cpu_addr <= x"f807" else '0';
  dip_sw_2_cs    <= '1' when cpu_addr >= x"f808" and cpu_addr <= x"f809" else '0';

  -- mux CPU data input
  cpu_din <= prog_rom_1_dout or
             prog_rom_2_dout or
             prog_rom_3_dout or
             work_ram_dout or
             gpu_dout or
             io_dout;

  -- set video signals
  hsync  <= video.hsync;
  vsync  <= video.vsync;
  hblank <= video.hblank;
  vblank <= video.vblank;

  -- set RGB signals
  r <= rgb.r;
  g <= rgb.g;
  b <= rgb.b;
end architecture arch;
