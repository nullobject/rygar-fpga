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

-- A segment provides a 32-bit read-only interface to a contiguous block of ROM
-- data, located at some offset in the SDRAM.
entity segment is
  generic (
    -- the width of the ROM address bus
    ROM_ADDR_WIDTH : natural;

    -- the offset of the ROM data in the SDRAM
    ROM_OFFSET : natural := 0
  );
  port (
    -- clock
    clk : in std_logic;

    -- chip select
    cs : in std_logic;

    -- ROM interface
    rom_addr : in unsigned(ROM_ADDR_WIDTH-1 downto 0);
    rom_data : out std_logic_vector(SDRAM_CTRL_DATA_WIDTH-1 downto 0);

    -- SDRAM interface
    sdram_addr  : out unsigned(SDRAM_CTRL_ADDR_WIDTH-1 downto 0);
    sdram_data  : in std_logic_vector(SDRAM_CTRL_DATA_WIDTH-1 downto 0);
    sdram_valid : in std_logic
  );
end segment;

architecture arch of segment is
begin
  -- latch ROM data from the SDRAM
  latch_rom_data : process (clk)
  begin
    if rising_edge(clk) then
      if sdram_valid = '1' and cs = '1' then
        rom_data <= sdram_data;
      end if;
    end if;
  end process;

  -- set SDRAM address
  sdram_addr <= resize(rom_addr, sdram_addr'length)+ROM_OFFSET when cs = '1' else (others => '0');
end architecture arch;
