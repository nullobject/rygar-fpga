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

-- The frame buffer is a memory device used for caching graphics data. It is
-- used by the sprite renderer to ensure glitch-free graphics.
--
-- Internally, it contains two *pages* which are accessed alternately for
-- reading and writing, so that while on page is being written to, the other is
-- being read from.
--
-- When the pages are *flipped*, the page that was previously being written to
-- will be read from, and the page that was being read from will be written to.
--
-- The frame buffer interface provides two ports: a read-only port, and
-- a write-only port.
entity frame_buffer is
  generic (
    ADDR_WIDTH : natural := 8;
    DATA_WIDTH : natural := 8
  );
  port (
    -- clock
    clk : in std_logic := '1';

    -- chip select
    cs : in std_logic := '1';

    -- flip the pages
    flip : in std_logic := '0';

    -- read-only port
    addr_rd : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    din     : in std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');

    -- write-only port
    addr_wr : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    dout    : out std_logic_vector(DATA_WIDTH-1 downto 0);
    we      : in std_logic := '0'
  );
end frame_buffer;

architecture arch of frame_buffer is
  signal addr_a, addr_b : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal dout_a, dout_b : std_logic_vector(DATA_WIDTH-1 downto 0);
begin
  ram : entity work.dual_port_ram
  generic map (
    ADDR_WIDTH_A => ADDR_WIDTH + 1,
    ADDR_WIDTH_B => ADDR_WIDTH + 1,
    DATA_WIDTH_A => DATA_WIDTH,
    DATA_WIDTH_B => DATA_WIDTH
  )
  port map (
    clk_a  => clk,
    clk_b  => clk,
    addr_a => '0' & addr_a,
    addr_b => '1' & addr_b,
    din_a  => din,
    din_b  => din,
    dout_a => dout_a,
    dout_b => dout_b,
    we_a   => cs and we and flip,
    we_b   => cs and we and (not flip)
  );

  addr_a <= addr_rd when flip = '0' else addr_wr;
  addr_b <= addr_wr when flip = '0' else addr_rd;

  -- output
  dout <= dout_a when cs = '1' and flip = '0' else
          dout_b when cs = '1' and flip = '1' else
          (others => '0');
end arch;
