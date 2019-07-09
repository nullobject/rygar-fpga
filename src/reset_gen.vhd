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

-- Generates a reset pulse after powering on, or at any time the reset signal
-- is asserted.
--
-- The Z80 needs to be reset after powering on, otherwise it may load garbage
-- data from the address and data buses.
entity reset_gen is
  port(
    -- clock
    clk : in std_logic;

    -- reset input
    reset : in std_logic;

    -- reset output
    reset_n : out std_logic
  );
end reset_gen;

architecture arch of reset_gen is
begin
  reset_pulse : process(clk)
    variable r : std_logic;
  begin
    if falling_edge(clk) then
      if reset = '1' then
        reset_n <= '0';
        r := '0';
      else
        reset_n <= r;
        r := '1';
      end if;
    end if;
  end process;
end architecture arch;
