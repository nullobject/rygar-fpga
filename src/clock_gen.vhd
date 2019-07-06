library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- generates clock enable (CEN) signals by dividing the 12MHz reference clock
entity clock_gen is
  port (
    -- reference clock
    clk_12 : in std_logic;

    -- clock enable signals
    cen_6 : out std_logic;
    cen_4 : out std_logic
  );
end clock_gen;

architecture arch of clock_gen is
begin
  process(clk_12)
    variable even_count : integer range 0 to 1;
    variable odd_count : integer range 0 to 2;
  begin
    if rising_edge(clk_12) then
      if even_count < 1 then
        even_count := even_count + 1;
        cen_6 <= '0';
      else
        even_count := 0;
        cen_6 <= '1';
      end if;

      if odd_count < 2 then
        odd_count := odd_count + 1;
        cen_4 <= '0';
      else
        odd_count := 0;
        cen_4 <= '1';
      end if;
    end if;
  end process;
end architecture;
