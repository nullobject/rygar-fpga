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

use work.rygar.all;

-- The ROM controller handles reading and writing ROM data to the SDRAM. It
-- provides a read-only interface to the GPU for reading tile data. It also
-- provides a write-only interface for storing the ROM data received through
-- the MiSTer IOCTL interface.
--
-- The original arcade hardware has multiple ROM chips that store things like
-- the program data, tile data, sound data, etc. Unfortunately, the Cyclone
-- V FPGA doesn't have enough memory blocks for us to implement all these ROMs.
-- Instead, we need to store the them in the SDRAM.
--
-- The ROMs are all accessed concurrently, so the ROM controller is responsible
-- for reading the ROM data from the SDRAM in a fair and timely manner.
entity rom_controller is
  port (
    -- reset
    reset : in std_logic := '0';

    -- clock
    clk : in std_logic;

    -- program ROM #1 interface
    prog_rom_1_cs   : in std_logic;
    prog_rom_1_oe   : in std_logic;
    prog_rom_1_addr : in unsigned(PROG_ROM_1_ADDR_WIDTH-1 downto 0);
    prog_rom_1_data : out std_logic_vector(PROG_ROM_1_DATA_WIDTH-1 downto 0);

    -- program ROM #2 interface
    prog_rom_2_cs   : in std_logic;
    prog_rom_2_oe   : in std_logic;
    prog_rom_2_addr : in unsigned(PROG_ROM_2_ADDR_WIDTH-1 downto 0);
    prog_rom_2_data : out std_logic_vector(PROG_ROM_2_DATA_WIDTH-1 downto 0);

    -- program ROM #3 interface
    prog_rom_3_cs   : in std_logic;
    prog_rom_3_oe   : in std_logic;
    prog_rom_3_addr : in unsigned(PROG_ROM_3_ADDR_WIDTH-1 downto 0);
    prog_rom_3_data : out std_logic_vector(PROG_ROM_3_DATA_WIDTH-1 downto 0);

    -- tile ROM interface
    sprite_rom_addr : in unsigned(SPRITE_ROM_ADDR_WIDTH-1 downto 0);
    sprite_rom_data : out std_logic_vector(SPRITE_ROM_DATA_WIDTH-1 downto 0);
    char_rom_addr   : in unsigned(CHAR_ROM_ADDR_WIDTH-1 downto 0);
    char_rom_data   : out std_logic_vector(CHAR_ROM_DATA_WIDTH-1 downto 0);
    fg_rom_addr     : in unsigned(FG_ROM_ADDR_WIDTH-1 downto 0);
    fg_rom_data     : out std_logic_vector(FG_ROM_DATA_WIDTH-1 downto 0);
    bg_rom_addr     : in unsigned(BG_ROM_ADDR_WIDTH-1 downto 0);
    bg_rom_data     : out std_logic_vector(BG_ROM_DATA_WIDTH-1 downto 0);

    -- SDRAM interface
    sdram_addr  : out unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
    sdram_din   : out std_logic_vector(SDRAM_CTRL_DATA_WIDTH-1 downto 0);
    sdram_dout  : in std_logic_vector(SDRAM_CTRL_DATA_WIDTH-1 downto 0);
    sdram_we    : out std_logic;
    sdram_req   : out std_logic;
    sdram_ack   : in std_logic;
    sdram_valid : in std_logic;
    sdram_ready : in std_logic;

    -- IOCTL interface
    ioctl_addr     : in unsigned(IOCTL_ADDR_WIDTH-1 downto 0);
    ioctl_data     : in byte_t;
    ioctl_wr       : in std_logic;
    ioctl_download : in std_logic
  );
end rom_controller;

architecture arch of rom_controller is
  type rom_t is (NONE, PROG_ROM_1, PROG_ROM_2, PROG_ROM_3, SPRITE_ROM, CHAR_ROM, FG_ROM, BG_ROM);

  -- current ROM
  signal rom : rom_t;

  -- control signals
  signal valid : std_logic;
  signal req   : std_logic;

  -- request signals
  signal prog_rom_1_req : std_logic;
  signal prog_rom_2_req : std_logic;
  signal prog_rom_3_req : std_logic;
  signal sprite_rom_req : std_logic;
  signal char_rom_req   : std_logic;
  signal fg_rom_req     : std_logic;
  signal bg_rom_req     : std_logic;

  -- enable signals
  signal prog_rom_1_en : std_logic;
  signal prog_rom_2_en : std_logic;
  signal prog_rom_3_en : std_logic;
  signal sprite_rom_en : std_logic;
  signal char_rom_en   : std_logic;
  signal fg_rom_en     : std_logic;
  signal bg_rom_en     : std_logic;

  -- address mux signals
  signal ioctl_sdram_addr      : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
  signal prog_rom_1_sdram_addr : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
  signal prog_rom_2_sdram_addr : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
  signal prog_rom_3_sdram_addr : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
  signal sprite_rom_sdram_addr : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
  signal char_rom_sdram_addr   : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
  signal fg_rom_sdram_addr     : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
  signal bg_rom_sdram_addr     : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
begin
  prog_rom_1_segment : entity work.segment
  generic map (
    ROM_ADDR_WIDTH => PROG_ROM_1_ADDR_WIDTH,
    ROM_DATA_WIDTH => PROG_ROM_1_DATA_WIDTH,
    ROM_OFFSET     => PROG_ROM_1_OFFSET
  )
  port map (
    reset       => reset,
    clk         => clk,
    cs          => prog_rom_1_cs,
    oe          => prog_rom_1_oe,
    rom_addr    => prog_rom_1_addr,
    rom_data    => prog_rom_1_data,
    sdram_addr  => prog_rom_1_sdram_addr,
    sdram_data  => sdram_dout,
    sdram_req   => prog_rom_1_req,
    sdram_ack   => prog_rom_1_en and sdram_ack,
    sdram_valid => prog_rom_1_en and sdram_valid
  );

  prog_rom_2_segment : entity work.segment
  generic map (
    ROM_ADDR_WIDTH => PROG_ROM_2_ADDR_WIDTH,
    ROM_DATA_WIDTH => PROG_ROM_2_DATA_WIDTH,
    ROM_OFFSET     => PROG_ROM_2_OFFSET
  )
  port map (
    reset       => reset,
    clk         => clk,
    cs          => prog_rom_2_cs,
    oe          => prog_rom_2_oe,
    rom_addr    => prog_rom_2_addr,
    rom_data    => prog_rom_2_data,
    sdram_addr  => prog_rom_2_sdram_addr,
    sdram_data  => sdram_dout,
    sdram_req   => prog_rom_2_req,
    sdram_ack   => prog_rom_2_en and sdram_ack,
    sdram_valid => prog_rom_2_en and sdram_valid
  );

  prog_rom_3_segment : entity work.segment
  generic map (
    ROM_ADDR_WIDTH => PROG_ROM_3_ADDR_WIDTH,
    ROM_DATA_WIDTH => PROG_ROM_3_DATA_WIDTH,
    ROM_OFFSET     => PROG_ROM_3_OFFSET
  )
  port map (
    reset       => reset,
    clk         => clk,
    cs          => prog_rom_3_cs,
    oe          => prog_rom_3_oe,
    rom_addr    => prog_rom_3_addr,
    rom_data    => prog_rom_3_data,
    sdram_addr  => prog_rom_3_sdram_addr,
    sdram_data  => sdram_dout,
    sdram_req   => prog_rom_3_req,
    sdram_ack   => prog_rom_3_en and sdram_ack,
    sdram_valid => prog_rom_3_en and sdram_valid
  );

  sprite_rom_segment : entity work.segment
  generic map (
    ROM_ADDR_WIDTH => SPRITE_ROM_ADDR_WIDTH,
    ROM_DATA_WIDTH => SPRITE_ROM_DATA_WIDTH,
    ROM_OFFSET     => SPRITE_ROM_OFFSET
  )
  port map (
    reset       => reset,
    clk         => clk,
    rom_addr    => sprite_rom_addr,
    rom_data    => sprite_rom_data,
    sdram_addr  => sprite_rom_sdram_addr,
    sdram_data  => sdram_dout,
    sdram_req   => sprite_rom_req,
    sdram_ack   => sprite_rom_en and sdram_ack,
    sdram_valid => sprite_rom_en and sdram_valid
  );

  char_rom_segment : entity work.segment
  generic map (
    ROM_ADDR_WIDTH => CHAR_ROM_ADDR_WIDTH,
    ROM_DATA_WIDTH => CHAR_ROM_DATA_WIDTH,
    ROM_OFFSET     => CHAR_ROM_OFFSET
  )
  port map (
    reset       => reset,
    clk         => clk,
    rom_addr    => char_rom_addr,
    rom_data    => char_rom_data,
    sdram_addr  => char_rom_sdram_addr,
    sdram_data  => sdram_dout,
    sdram_req   => char_rom_req,
    sdram_ack   => char_rom_en and sdram_ack,
    sdram_valid => char_rom_en and sdram_valid
  );

  fg_rom_segment : entity work.segment
  generic map (
    ROM_ADDR_WIDTH => FG_ROM_ADDR_WIDTH,
    ROM_DATA_WIDTH => FG_ROM_DATA_WIDTH,
    ROM_OFFSET     => FG_ROM_OFFSET
  )
  port map (
    reset       => reset,
    clk         => clk,
    rom_addr    => fg_rom_addr,
    rom_data    => fg_rom_data,
    sdram_addr  => fg_rom_sdram_addr,
    sdram_data  => sdram_dout,
    sdram_req   => fg_rom_req,
    sdram_ack   => fg_rom_en and sdram_ack,
    sdram_valid => fg_rom_en and sdram_valid
  );

  bg_rom_segment : entity work.segment
  generic map (
    ROM_ADDR_WIDTH => BG_ROM_ADDR_WIDTH,
    ROM_DATA_WIDTH => BG_ROM_DATA_WIDTH,
    ROM_OFFSET     => BG_ROM_OFFSET
  )
  port map (
    reset       => reset,
    clk         => clk,
    rom_addr    => bg_rom_addr,
    rom_data    => bg_rom_data,
    sdram_addr  => bg_rom_sdram_addr,
    sdram_data  => sdram_dout,
    sdram_req   => bg_rom_req,
    sdram_ack   => bg_rom_en and sdram_ack,
    sdram_valid => bg_rom_en and sdram_valid
  );

  -- The SDRAM controller has a 32-bit interface, so we need to buffer the
  -- bytes received from the IOCTL interface in order to write 32-bit words to
  -- the SDRAM.
  download_buffer : entity work.download_buffer
  generic map (SIZE => 4)
  port map (
    clk   => clk,
    din   => ioctl_data,
    dout  => sdram_din,
    we    => ioctl_download and ioctl_wr,
    valid => valid
  );

  -- update the current ROM
  update_current_rom : process (clk, reset)
  begin
    if reset = '1' then
      rom <= NONE;
    elsif rising_edge(clk) then
      if rom = NONE or sdram_valid = '1' then
        if prog_rom_1_req = '1' then
          rom <= PROG_ROM_1;
        elsif prog_rom_2_req = '1' then
          rom <= PROG_ROM_2;
        elsif prog_rom_3_req = '1' then
          rom <= PROG_ROM_3;
        elsif sprite_rom_req = '1' then
          rom <= SPRITE_ROM;
        elsif char_rom_req = '1' then
          rom <= CHAR_ROM;
        elsif fg_rom_req = '1' then
          rom <= FG_ROM;
        elsif bg_rom_req = '1' then
          rom <= BG_ROM;
        else
          rom <= NONE;
        end if;
      end if;
    end if;
  end process;

  prog_rom_1_en <= '1' when rom = PROG_ROM_1 else '0';
  prog_rom_2_en <= '1' when rom = PROG_ROM_2 else '0';
  prog_rom_3_en <= '1' when rom = PROG_ROM_3 else '0';
  sprite_rom_en <= '1' when rom = SPRITE_ROM else '0';
  char_rom_en   <= '1' when rom = CHAR_ROM   else '0';
  fg_rom_en     <= '1' when rom = FG_ROM     else '0';
  bg_rom_en     <= '1' when rom = BG_ROM     else '0';

  -- we need to divide the address by four, because we're converting from
  -- a 8-bit IOCTL address to a 32-bit SDRAM address
  ioctl_sdram_addr <= resize(shift_right(ioctl_addr, 2), ioctl_sdram_addr'length);

  -- mux the SDRAM address
  sdram_addr <= ioctl_sdram_addr      when ioctl_download = '1' else
                prog_rom_1_sdram_addr when prog_rom_1_req = '1' else
                prog_rom_2_sdram_addr when prog_rom_2_req = '1' else
                prog_rom_3_sdram_addr when prog_rom_3_req = '1' else
                sprite_rom_sdram_addr when sprite_rom_req = '1' else
                char_rom_sdram_addr   when char_rom_req   = '1' else
                fg_rom_sdram_addr     when fg_rom_req     = '1' else
                bg_rom_sdram_addr     when bg_rom_req     = '1' else
                (others => '0');

  -- mux the request signals
  req <= prog_rom_1_req or
         prog_rom_2_req or
         prog_rom_3_req or
         sprite_rom_req or
         char_rom_req or
         fg_rom_req or
         bg_rom_req;

  -- request data from the SDRAM
  sdram_req <= (ioctl_download and valid) or (not ioctl_download and req);

  -- write to the SDRAM while downloading ROM data from the IOCTL interface
  sdram_we <= ioctl_download;
end architecture arch;
