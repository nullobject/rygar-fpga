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

-- Generates a pulse when a rising or falling edge is detected for the input
-- signal.
entity edge_detector is
  generic (
    RISING  : boolean := true;
    FALLING : boolean := false
  );
  port (
    -- clock
    clk : in std_logic;

    -- data input
    data : in std_logic;

    -- edge output strobe
    edge : out std_logic
  );
end edge_detector;

architecture arch of edge_detector is
  signal t0, t1 : std_logic;
begin
  process (clk)
  begin
    if rising_edge(clk) then
      t0 <= data;
      t1 <= t0;
    end if;
  end process;

  edge <= (not t1 and t0) when RISING else
          (t1 and not t0) when FALLING else
          '0';
end architecture arch;
