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

-- A segment provides a read-only interface to a contiguous block of ROM data,
-- located at some offset in the SDRAM.
entity segment is
  generic (
    -- the width of the ROM address bus
    ROM_ADDR_WIDTH : natural;

    -- the width of the ROM data bus
    ROM_DATA_WIDTH : natural;

    -- the byte offset of the ROM data in the SDRAM
    ROM_OFFSET : natural := 0
  );
  port (
    -- reset
    reset : in std_logic;

    -- clock
    clk : in std_logic;

    -- When the chip select signal is asserted, the memory segment may request
    -- data from the ROM controller when it is required (i.e. not in the
    -- cache).
    cs : in std_logic := '1';

    -- When the output enable signal is asserted, the output buffer is enabled
    -- and the word from the requested address will be placed on the ROM data
    -- bus.
    oe : in std_logic := '1';

    -- ROM interface
    rom_addr : in unsigned(ROM_ADDR_WIDTH-1 downto 0);
    rom_data : out std_logic_vector(ROM_DATA_WIDTH-1 downto 0);

    -- SDRAM interface
    sdram_addr  : buffer unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
    sdram_data  : in std_logic_vector(SDRAM_CTRL_DATA_WIDTH-1 downto 0);
    sdram_req   : out std_logic;
    sdram_ack   : in std_logic;
    sdram_valid : in std_logic
  );
end segment;

architecture arch of segment is
  -- the number of ROM words in a SDRAM word (e.g. there are four 8-bit ROM
  -- words in a 32-bit SDRAM word)
  constant ROM_WORDS : natural := SDRAM_CTRL_DATA_WIDTH / ROM_DATA_WIDTH;

  -- the number of bits in the offset component of the ROM address
  constant OFFSET_WIDTH : natural := ilog2(ROM_WORDS);

  -- the offset of the word from the requested ROM address in the cache
  signal offset : natural range 0 to ROM_WORDS-1;

  -- control signals
  signal init : std_logic;
  signal hit  : std_logic;
  signal ack  : std_logic;

  -- cache signals
  signal cache_addr : unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
  signal cache_data : std_logic_vector(SDRAM_CTRL_DATA_WIDTH-1 downto 0);
begin
  -- cache data received from the SDRAM
  cache_sdram_data : process (clk, reset)
  begin
    if reset = '1' then
      init <= '0';
    elsif rising_edge(clk) then
      if sdram_valid = '1' then
        -- set the cache signals
        cache_addr <= sdram_addr;
        cache_data <= sdram_data;

        -- assert the init signal after the cache has been filled
        init <= '1';
      end if;
    end if;
  end process;

  -- toggle the request enable signal
  toggle_request_en : process (clk, reset)
  begin
    if reset = '1' then
      ack <= '0';
    elsif rising_edge(clk) then
      if sdram_ack = '1' then
        -- when the SDRAM acknowledges the request, we can deassert the request
        -- enable signal
        ack <= '1';
      elsif sdram_valid = '1' then
        -- when the SDRAM completes the request, we can assert the request
        -- enable signal again
        ack <= '0';
      end if;
    end if;
  end process;

  -- assert the hit signal when the cache has been filled, and the requested
  -- address is in the cache
  hit <= '1' when init = '1' and sdram_addr = cache_addr else '0';

  -- calculate the offset of the ROM address within a SDRAM word
  offset <= to_integer(rom_addr(OFFSET_WIDTH-1 downto 0)) when OFFSET_WIDTH > 0 else 0;

  -- extract the word at the requested offset in the cache
  rom_data <= cache_data((ROM_WORDS-offset)*ROM_DATA_WIDTH-1 downto (ROM_WORDS-offset-1)*ROM_DATA_WIDTH) when cs = '1' and oe = '1' else (others => '0');

  -- Convert from a ROM address to a SDRAM address.
  --
  -- We need to divide the ROM offset by four, because we are converting to
  -- a 32-bit SDRAM address.
  sdram_addr <= resize(shift_right(rom_addr, OFFSET_WIDTH), SDRAM_CTRL_ADDR_WIDTH) + ROM_OFFSET/4;

  -- request data from the SDRAM unless there is a cache hit, or we just loaded
  -- data from the SDRAM but we haven't cached it yet
  sdram_req <= cs and not (hit or ack);
end architecture arch;
