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

-- The ROM controller handles reading and writing ROM data to the SDRAM. It
-- provides a read-only interface to the GPU for reading tile data. It also
-- provides a write-only interface for downloading the ROM data.
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
    reset : in std_logic;

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

    -- sprite ROM interface
    sprite_rom_cs   : in std_logic;
    sprite_rom_oe   : in std_logic;
    sprite_rom_addr : in unsigned(SPRITE_ROM_ADDR_WIDTH-1 downto 0);
    sprite_rom_data : out std_logic_vector(SPRITE_ROM_DATA_WIDTH-1 downto 0);

    -- character ROM interface
    char_rom_cs   : in std_logic;
    char_rom_oe   : in std_logic;
    char_rom_addr : in unsigned(CHAR_ROM_ADDR_WIDTH-1 downto 0);
    char_rom_data : out std_logic_vector(CHAR_ROM_DATA_WIDTH-1 downto 0);

    -- foreground ROM interface
    fg_rom_cs   : in std_logic;
    fg_rom_oe   : in std_logic;
    fg_rom_addr : in unsigned(FG_ROM_ADDR_WIDTH-1 downto 0);
    fg_rom_data : out std_logic_vector(FG_ROM_DATA_WIDTH-1 downto 0);

    -- background ROM interface
    bg_rom_cs   : in std_logic;
    bg_rom_oe   : in std_logic;
    bg_rom_addr : in unsigned(BG_ROM_ADDR_WIDTH-1 downto 0);
    bg_rom_data : out std_logic_vector(BG_ROM_DATA_WIDTH-1 downto 0);

    -- download interface
    download_addr : in unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
    download_data : in std_logic_vector(SDRAM_CTRL_DATA_WIDTH-1 downto 0);
    download_we   : in std_logic;
    download_req  : in std_logic;

    -- SDRAM interface
    sdram_addr  : out unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
    sdram_data  : out std_logic_vector(SDRAM_CTRL_DATA_WIDTH-1 downto 0);
    sdram_we    : out std_logic;
    sdram_req   : out std_logic;
    sdram_ack   : in std_logic;
    sdram_valid : in std_logic;
    sdram_q     : in std_logic_vector(SDRAM_CTRL_DATA_WIDTH-1 downto 0)
  );
end rom_controller;

architecture arch of rom_controller is
  type rom_t is (NONE, PROG_ROM_1, PROG_ROM_2, PROG_ROM_3, SPRITE_ROM, CHAR_ROM, FG_ROM, BG_ROM);

  -- ROM signals
  signal rom, next_rom, pending_rom : rom_t;

  -- ROM request signals
  signal prog_rom_1_ctrl_req : std_logic;
  signal prog_rom_2_ctrl_req : std_logic;
  signal prog_rom_3_ctrl_req : std_logic;
  signal sprite_rom_ctrl_req : std_logic;
  signal char_rom_ctrl_req   : std_logic;
  signal fg_rom_ctrl_req     : std_logic;
  signal bg_rom_ctrl_req     : std_logic;

  -- ROM acknowledge signals
  signal prog_rom_1_ctrl_ack : std_logic;
  signal prog_rom_2_ctrl_ack : std_logic;
  signal prog_rom_3_ctrl_ack : std_logic;
  signal sprite_rom_ctrl_ack : std_logic;
  signal char_rom_ctrl_ack   : std_logic;
  signal fg_rom_ctrl_ack     : std_logic;
  signal bg_rom_ctrl_ack     : std_logic;

  -- ROM valid signals
  signal prog_rom_1_ctrl_valid : std_logic;
  signal prog_rom_2_ctrl_valid : std_logic;
  signal prog_rom_3_ctrl_valid : std_logic;
  signal sprite_rom_ctrl_valid : std_logic;
  signal char_rom_ctrl_valid   : std_logic;
  signal fg_rom_ctrl_valid     : std_logic;
  signal bg_rom_ctrl_valid     : std_logic;

  -- address mux signals
  signal prog_rom_1_ctrl_addr : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
  signal prog_rom_2_ctrl_addr : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
  signal prog_rom_3_ctrl_addr : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
  signal sprite_rom_ctrl_addr : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
  signal char_rom_ctrl_addr   : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
  signal fg_rom_ctrl_addr     : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
  signal bg_rom_ctrl_addr     : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);

  -- control signals
  signal ctrl_req : std_logic;
begin

  prog_rom_1_segment : entity work.segment
  generic map (
    ROM_ADDR_WIDTH => PROG_ROM_1_ADDR_WIDTH,
    ROM_DATA_WIDTH => PROG_ROM_1_DATA_WIDTH,
    ROM_OFFSET     => PROG_ROM_1_OFFSET
  )
  port map (
    reset      => reset,
    clk        => clk,
    cs         => prog_rom_1_cs,
    oe         => prog_rom_1_oe,
    ctrl_addr  => prog_rom_1_ctrl_addr,
    ctrl_req   => prog_rom_1_ctrl_req,
    ctrl_ack   => prog_rom_1_ctrl_ack,
    ctrl_valid => prog_rom_1_ctrl_valid,
    ctrl_data  => sdram_q,
    rom_addr   => prog_rom_1_addr,
    rom_data   => prog_rom_1_data
  );

  prog_rom_2_segment : entity work.segment
  generic map (
    ROM_ADDR_WIDTH => PROG_ROM_2_ADDR_WIDTH,
    ROM_DATA_WIDTH => PROG_ROM_2_DATA_WIDTH,
    ROM_OFFSET     => PROG_ROM_2_OFFSET
  )
  port map (
    reset      => reset,
    clk        => clk,
    cs         => prog_rom_2_cs,
    oe         => prog_rom_2_oe,
    ctrl_addr  => prog_rom_2_ctrl_addr,
    ctrl_req   => prog_rom_2_ctrl_req,
    ctrl_ack   => prog_rom_2_ctrl_ack,
    ctrl_valid => prog_rom_2_ctrl_valid,
    ctrl_data  => sdram_q,
    rom_addr   => prog_rom_2_addr,
    rom_data   => prog_rom_2_data
  );

  prog_rom_3_segment : entity work.segment
  generic map (
    ROM_ADDR_WIDTH => PROG_ROM_3_ADDR_WIDTH,
    ROM_DATA_WIDTH => PROG_ROM_3_DATA_WIDTH,
    ROM_OFFSET     => PROG_ROM_3_OFFSET
  )
  port map (
    reset      => reset,
    clk        => clk,
    cs         => prog_rom_3_cs,
    oe         => prog_rom_3_oe,
    ctrl_addr  => prog_rom_3_ctrl_addr,
    ctrl_req   => prog_rom_3_ctrl_req,
    ctrl_ack   => prog_rom_3_ctrl_ack,
    ctrl_valid => prog_rom_3_ctrl_valid,
    ctrl_data  => sdram_q,
    rom_addr   => prog_rom_3_addr,
    rom_data   => prog_rom_3_data
  );

  sprite_rom_segment : entity work.segment
  generic map (
    ROM_ADDR_WIDTH => SPRITE_ROM_ADDR_WIDTH,
    ROM_DATA_WIDTH => SPRITE_ROM_DATA_WIDTH,
    ROM_OFFSET     => SPRITE_ROM_OFFSET
  )
  port map (
    reset      => reset,
    clk        => clk,
    cs         => sprite_rom_cs,
    oe         => sprite_rom_oe,
    ctrl_addr  => sprite_rom_ctrl_addr,
    ctrl_req   => sprite_rom_ctrl_req,
    ctrl_ack   => sprite_rom_ctrl_ack,
    ctrl_valid => sprite_rom_ctrl_valid,
    ctrl_data  => sdram_q,
    rom_addr   => sprite_rom_addr,
    rom_data   => sprite_rom_data
  );

  char_rom_segment : entity work.segment
  generic map (
    ROM_ADDR_WIDTH => CHAR_ROM_ADDR_WIDTH,
    ROM_DATA_WIDTH => CHAR_ROM_DATA_WIDTH,
    ROM_OFFSET     => CHAR_ROM_OFFSET
  )
  port map (
    reset      => reset,
    clk        => clk,
    cs         => char_rom_cs,
    oe         => char_rom_oe,
    ctrl_addr  => char_rom_ctrl_addr,
    ctrl_req   => char_rom_ctrl_req,
    ctrl_ack   => char_rom_ctrl_ack,
    ctrl_valid => char_rom_ctrl_valid,
    ctrl_data  => sdram_q,
    rom_addr   => char_rom_addr,
    rom_data   => char_rom_data
  );

  fg_rom_segment : entity work.segment
  generic map (
    ROM_ADDR_WIDTH => FG_ROM_ADDR_WIDTH,
    ROM_DATA_WIDTH => FG_ROM_DATA_WIDTH,
    ROM_OFFSET     => FG_ROM_OFFSET
  )
  port map (
    reset      => reset,
    clk        => clk,
    cs         => fg_rom_cs,
    oe         => fg_rom_oe,
    ctrl_addr  => fg_rom_ctrl_addr,
    ctrl_req   => fg_rom_ctrl_req,
    ctrl_ack   => fg_rom_ctrl_ack,
    ctrl_valid => fg_rom_ctrl_valid,
    ctrl_data  => sdram_q,
    rom_addr   => fg_rom_addr,
    rom_data   => fg_rom_data
  );

  bg_rom_segment : entity work.segment
  generic map (
    ROM_ADDR_WIDTH => BG_ROM_ADDR_WIDTH,
    ROM_DATA_WIDTH => BG_ROM_DATA_WIDTH,
    ROM_OFFSET     => BG_ROM_OFFSET
  )
  port map (
    reset      => reset,
    clk        => clk,
    cs         => bg_rom_cs,
    oe         => bg_rom_oe,
    ctrl_addr  => bg_rom_ctrl_addr,
    ctrl_req   => bg_rom_ctrl_req,
    ctrl_ack   => bg_rom_ctrl_ack,
    ctrl_valid => bg_rom_ctrl_valid,
    ctrl_data  => sdram_q,
    rom_addr   => bg_rom_addr,
    rom_data   => bg_rom_data
  );

  -- latch the next ROM
  latch_next_rom : process (clk, reset)
  begin
    if reset = '1' then
      rom         <= NONE;
      pending_rom <= NONE;
    elsif rising_edge(clk) then
      -- default to not having any ROM selected
      rom <= NONE;

      -- set the current ROM register when ROM data is not being downloaded
      if download_we = '0' then
        rom <= next_rom;
      end if;

      -- set the pending ROM register when a request is acknowledged (i.e.
      -- a new request has been started)
      if sdram_ack = '1' then
        pending_rom <= rom;
      end if;
    end if;
  end process;

  -- mux the next ROM in priority order
  next_rom <= PROG_ROM_1 when prog_rom_1_ctrl_req = '1' else
              PROG_ROM_2 when prog_rom_2_ctrl_req = '1' else
              PROG_ROM_3 when prog_rom_3_ctrl_req = '1' else
              SPRITE_ROM when sprite_rom_ctrl_req = '1' else
              CHAR_ROM   when char_rom_ctrl_req   = '1' else
              FG_ROM     when fg_rom_ctrl_req     = '1' else
              BG_ROM     when bg_rom_ctrl_req     = '1' else
              NONE;

  -- route SDRAM acknowledge signal to the current ROM
  prog_rom_1_ctrl_ack <= sdram_ack when rom = PROG_ROM_1 else '0';
  prog_rom_2_ctrl_ack <= sdram_ack when rom = PROG_ROM_2 else '0';
  prog_rom_3_ctrl_ack <= sdram_ack when rom = PROG_ROM_3 else '0';
  sprite_rom_ctrl_ack <= sdram_ack when rom = SPRITE_ROM else '0';
  char_rom_ctrl_ack   <= sdram_ack when rom = CHAR_ROM   else '0';
  fg_rom_ctrl_ack     <= sdram_ack when rom = FG_ROM     else '0';
  bg_rom_ctrl_ack     <= sdram_ack when rom = BG_ROM     else '0';

  -- route SDRAM valid signal to the pending ROM
  prog_rom_1_ctrl_valid <= sdram_valid when pending_rom = PROG_ROM_1 else '0';
  prog_rom_2_ctrl_valid <= sdram_valid when pending_rom = PROG_ROM_2 else '0';
  prog_rom_3_ctrl_valid <= sdram_valid when pending_rom = PROG_ROM_3 else '0';
  sprite_rom_ctrl_valid <= sdram_valid when pending_rom = SPRITE_ROM else '0';
  char_rom_ctrl_valid   <= sdram_valid when pending_rom = CHAR_ROM   else '0';
  fg_rom_ctrl_valid     <= sdram_valid when pending_rom = FG_ROM     else '0';
  bg_rom_ctrl_valid     <= sdram_valid when pending_rom = BG_ROM     else '0';

  -- mux ROM request
  ctrl_req <= prog_rom_1_ctrl_req or
              prog_rom_2_ctrl_req or
              prog_rom_3_ctrl_req or
              sprite_rom_ctrl_req or
              char_rom_ctrl_req or
              fg_rom_ctrl_req or
              bg_rom_ctrl_req;

  -- mux SDRAM address
  sdram_addr <= download_addr        when download_we         = '1' else
                prog_rom_1_ctrl_addr when prog_rom_1_ctrl_req = '1' else
                prog_rom_2_ctrl_addr when prog_rom_2_ctrl_req = '1' else
                prog_rom_3_ctrl_addr when prog_rom_3_ctrl_req = '1' else
                sprite_rom_ctrl_addr when sprite_rom_ctrl_req = '1' else
                char_rom_ctrl_addr   when char_rom_ctrl_req   = '1' else
                fg_rom_ctrl_addr     when fg_rom_ctrl_req     = '1' else
                bg_rom_ctrl_addr     when bg_rom_ctrl_req     = '1' else
                (others => '0');

  -- set SDRAM data input
  sdram_data <= download_data;

  -- set SDRAM request
  sdram_req <= (download_we and download_req) or (not download_we and ctrl_req);

  -- enable writing to the SDRAM when downloading ROM data
  sdram_we <= download_we;
end architecture arch;
