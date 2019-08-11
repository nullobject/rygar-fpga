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
-- Internally, it contains two memory pages which are accessed alternately for
-- reading and writing, so that while one page is being written to, the other
-- is being read from.
--
-- When the flip signal is asserted, the pages are swapped. The page that was
-- previously being written to will be read from, and the page that was being
-- read from will be written to.
--
-- The frame buffer automatically clears pixels during read operations, so that
-- the write page is clean when it is flipped.
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

    -- write-only port
    addr_wr : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    din     : in std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    wren    : in std_logic := '0';

    -- read-only port
    addr_rd : in std_logic_vector(ADDR_WIDTH-1 downto 0);
    dout    : out std_logic_vector(DATA_WIDTH-1 downto 0);
    rden    : in std_logic := '1'
  );
end frame_buffer;

architecture arch of frame_buffer is
  signal addr_a, addr_b : std_logic_vector(ADDR_WIDTH-1 downto 0);
  signal din_a, din_b   : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal dout_a, dout_b : std_logic_vector(DATA_WIDTH-1 downto 0);
  signal rden_a, rden_b : std_logic;
  signal wren_a, wren_b : std_logic;
begin
  page_a : entity work.dual_port_ram
  generic map (
    ADDR_WIDTH => ADDR_WIDTH,
    DATA_WIDTH => DATA_WIDTH
  )
  port map (
    clk     => clk,
    cs      => cs,
    addr_wr => addr_a,
    din     => din_a,
    wren    => wren_a,
    addr_rd => addr_a,
    dout    => dout_a,
    rden    => rden_a
  );

  page_b : entity work.dual_port_ram
  generic map (
    ADDR_WIDTH => ADDR_WIDTH,
    DATA_WIDTH => DATA_WIDTH
  )
  port map (
    clk     => clk,
    cs      => cs,
    addr_wr => addr_b,
    din     => din_b,
    wren    => wren_b,
    addr_rd => addr_b,
    dout    => dout_b,
    rden    => rden_b
  );

  addr_a <= addr_rd when flip = '0' else addr_wr;
  addr_b <= addr_rd when flip = '1' else addr_wr;

  rden_a <= rden;
  rden_b <= rden;

  wren_a <= wren when flip = '1' else rden;
  wren_b <= wren when flip = '0' else rden;

  din_a <= din when wren = '1' and flip = '1' else (others => '0');
  din_b <= din when wren = '1' and flip = '0' else (others => '0');

  -- output
  dout <= dout_a when rden = '1' and flip = '0' else
          dout_b when rden = '1' and flip = '1' else
          (others => '0');
end arch;
