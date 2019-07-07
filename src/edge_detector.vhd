library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- detects the rising and falling edges of a signal
entity edge_detector is
  port (
    -- input clock
    clk : in std_logic;

    -- data input
    data : in std_logic;

    -- edge strobe output signals
    rising, falling : out std_logic
  );
end edge_detector;

architecture arch of edge_detector is
  signal t0, t1 : std_logic;
begin
  process(clk)
  begin
    if rising_edge(clk) then
      t0 <= data;
      t1 <= t0;
    end if;
  end process;

  rising  <= (not t1) and t0;
  falling <= (not t0) and t1;
end architecture;
