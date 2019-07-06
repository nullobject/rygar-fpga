library ieee;
use ieee.std_logic_1164.all;

-- Generates a reset pulse after powering on, or at any time the reset signal
-- is asserted.
--
-- The Z80 needs to be reset after powering on, otherwise it may load garbage
-- data from the address and data buses.
entity reset_gen is
  port(
    clk : in std_logic;
    reset : in std_logic;
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
