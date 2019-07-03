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
  signal even_count : unsigned(0 downto 0);
  signal odd_count : unsigned(1 downto 0);
begin
  process(clk_12)
  begin
    if rising_edge(clk_12) then
      if even_count < 1 then
        even_count <= even_count + 1;
      else
        even_count <= (others => '0');
      end if;

      if odd_count < 2 then
        odd_count <= odd_count + 1;
      else
        odd_count <= (others => '0');
      end if;
    end if;
  end process;

  cen_6 <= '1' when even_count = 1 else '0';
  cen_4 <= '1' when odd_count = 2 else '0';
end architecture;
