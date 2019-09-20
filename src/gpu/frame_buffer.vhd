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
-- The frame buffer automatically clears pixels during read operations, so that
-- the page is clean when it is flipped.
entity frame_buffer is
  generic (
    ADDR_WIDTH : natural := 8;
    DATA_WIDTH : natural := 8
  );
  port (
    -- clock
    clk : in std_logic;

    -- chip select
    cs : in std_logic := '1';

    -- When the flip signal is asserted, the memory pages are swapped. The page
    -- that was previously being written to will be read from, and the page
    -- that was being read from will be written to.
    flip : in std_logic := '0';

    -- port A (write)
    addr_a : in unsigned(ADDR_WIDTH-1 downto 0);
    din_a  : in std_logic_vector(DATA_WIDTH-1 downto 0) := (others => '0');
    we_a   : in std_logic := '0';

    -- port B (read)
    addr_b : in unsigned(ADDR_WIDTH-1 downto 0);
    dout_b : out std_logic_vector(DATA_WIDTH-1 downto 0);
    re_b   : in std_logic := '1'
  );
end frame_buffer;

architecture arch of frame_buffer is
  type page_t is record
    addr : unsigned(ADDR_WIDTH-1 downto 0);
    din  : std_logic_vector(DATA_WIDTH-1 downto 0);
    dout : std_logic_vector(DATA_WIDTH-1 downto 0);
    re   : std_logic;
    we   : std_logic;
  end record page_t;

  signal page_1, page_2 : page_t;
begin
  page_1_ram : entity work.dual_port_ram
  generic map (
    ADDR_WIDTH => ADDR_WIDTH,
    DATA_WIDTH => DATA_WIDTH
  )
  port map (
    clk    => clk,
    cs     => cs,
    addr_a => page_1.addr,
    din_a  => page_1.din,
    we_a   => page_1.we,
    addr_b => page_1.addr,
    dout_b => page_1.dout,
    re_b   => page_1.re
  );

  page_2_ram : entity work.dual_port_ram
  generic map (
    ADDR_WIDTH => ADDR_WIDTH,
    DATA_WIDTH => DATA_WIDTH
  )
  port map (
    clk    => clk,
    cs     => cs,
    addr_a => page_2.addr,
    din_a  => page_2.din,
    we_a   => page_2.we,
    addr_b => page_2.addr,
    dout_b => page_2.dout,
    re_b   => page_2.re
  );

  page_1.addr <= addr_b when flip = '0' else addr_a;
  page_2.addr <= addr_b when flip = '1' else addr_a;

  page_1.re <= re_b;
  page_2.re <= re_b;

  page_1.we <= we_a when flip = '1' else re_b;
  page_2.we <= we_a when flip = '0' else re_b;

  page_1.din <= din_a when we_a = '1' and flip = '1' else (others => '0');
  page_2.din <= din_a when we_a = '1' and flip = '0' else (others => '0');

  -- set data
  dout_b <= page_1.dout when re_b = '1' and flip = '0' else
            page_2.dout when re_b = '1' and flip = '1' else
            (others => '0');
end architecture arch;
