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

-- Generates an initial reset pulse, or at any time the input signal is
-- asserted.
--
-- This is based on the circuit described in Advanced FPGA Design (p144).
entity reset_gen is
  port(
    -- clock
    clk : in std_logic;

    -- reset input
    rin : in std_logic;

    -- reset output
    rout : out std_logic
  );
end reset_gen;

architecture arch of reset_gen is
  signal t1 : std_logic := '1';
begin
  process (clk, rin)
  begin
    if rin = '1' then
      t1 <= '1';
      rout <= '1';
    elsif rising_edge(clk) then
      t1 <= '0';
      rout <= t1;
    end if;
  end process;
end architecture arch;
