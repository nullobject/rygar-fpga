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
  signal hcnt : unsigned(8 downto 0) := 9x"080";
  signal vcnt : unsigned(8 downto 0) := 9x"0f8";

  signal do_hsync : boolean;
begin
  hv_count : process(clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        -- horizontal counter counts $080 to $1ff = 384 (6Mhz/384 = 15.625 kHz)
        if hcnt = 9x"1ff" then
          hcnt <= 9x"080";
        else
          hcnt <= hcnt + 1;
        end if;

        -- vertical counter counts $0f8 to $1ff = 264 (15625/264 = 59.185 Hz)
        if do_hsync then
          if vcnt = 9x"1ff" then
            vcnt <= 9x"0f8";
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
        if    hcnt = 9x"0af" then hsync <= '1';
        elsif hcnt = 9x"0cf" then hsync <= '0';
        end if;

        if    hcnt = 9x"087" then hblank <= '1';
        elsif hcnt = 9x"107" then hblank <= '0';
        end if;

        if do_hsync then
          if    vcnt = 9x"1ef" then vblank <= '1';
          elsif vcnt = 9x"10f" then vblank <= '0';
          end if;
        end if;
      end if;
    end if;
  end process;

  vsync <= not vcnt(8);
  do_hsync <= (hcnt = 9x"0af");
  hpos <= hcnt;
  vpos <= vcnt;
end architecture;
