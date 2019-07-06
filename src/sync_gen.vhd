library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sync_gen is
  port (
    -- clock
    clk : in std_logic;

    -- clock enable
    cen : in std_logic;

    -- horizontal and vertical position
    hpos, vpos : out unsigned(8 downto 0);

    -- horizontal and vertical sync
    hsync, vsync : out std_logic;

    -- horizontal and vertical blank
    hblank, vblank : out std_logic
  );
end sync_gen;

architecture struct of sync_gen is
  signal hcnt : unsigned(8 downto 0);
  signal vcnt : unsigned(8 downto 0);
begin
  hv_count : process(clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        -- horizontal counter counts $080 to $1ff = 384 (6Mhz/384 = 15.625 kHz)
        if hcnt = 9x"17f" then
          hcnt <= 9x"000";
        else
          hcnt <= hcnt + 1;
        end if;

        -- vertical counter counts $0f8 to $1ff = 264 (15625/264 = 59.185 Hz)
        if hcnt = 9x"12f" then
          if vcnt = 9x"107" then
            vcnt <= 9x"000";
          else
            vcnt <= vcnt + 1;
          end if;
        end if;
      end if;
    end if;
  end process;

  sync : process(clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        if    hcnt = 9x"000" then hblank <= '0';
        elsif hcnt = 9x"100" then hblank <= '1';
        end if;

        if    hcnt = 9x"12f" then hsync <= '1';
        elsif hcnt = 9x"14f" then hsync <= '0';
        end if;

        if    vcnt = 9x"000" then vblank <= '0';
        elsif vcnt = 9x"0e0" then vblank <= '1';
        end if;

        if    vcnt = 9x"0f0" then vsync <= '1';
        elsif vcnt = 9x"0f8" then vsync <= '0';
        end if;
      end if;
    end if;
  end process;

  hpos <= hcnt;
  vpos <= vcnt;
end architecture;
