library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- generates a clock enable signal by dividing the input clock
entity clock_divider is
  generic (
    DIVISOR : integer
  );
  port (
    -- input clock
    clk : in std_logic;

    -- clock enable output strobe
    cen : out std_logic
  );
end clock_divider;

architecture arch of clock_divider is
begin
  process(clk)
    variable count : integer range 0 to DIVISOR-1;
  begin
    if rising_edge(clk) then
      if count < DIVISOR-1 then
        count := count + 1;
        cen <= '0';
      else
        count := 0;
        cen <= '1';
      end if;
    end if;
  end process;
end architecture;
