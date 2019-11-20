library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common.all;

entity MSM5205 is
  generic (
    -- 00=clk/96, 01=clk/64, 10=clk/48, 11=prohibited
    SAMPLE_FREQ : std_logic_vector(1 downto 0) := "00"
  );
  port (
    reset : in std_logic;

    clk : in std_logic;
    cen : in std_logic;

    -- sampling output clock
    vck : out std_logic;

    -- ADPCM input data
    din : in std_logic_vector(3 downto 0);

    -- 12-bit PCM output data
    sample : out signed(11 downto 0)
  );
end MSM5205;

architecture rtl of MSM5205 is
  signal vck_reg : std_logic := '0';
  signal vck_ena : std_logic := '0';

  signal out_val  : signed(15 downto 0) := (others => '0');
  signal sum_val  : signed(12 downto 0) := (others => '0');
  signal sign_val : signed(12 downto 0) := (others => '0');

  signal ctr    : unsigned(6 downto 0) := (others => '0');
  signal step   : unsigned(5 downto 0) := (others => '0');
  signal divctr : unsigned(3 downto 0) := (others => '0');

  signal stepval : signed(11 downto 0) := (others => '0');

  signal stepval1, stepval2, stepval4, stepval8 : signed(12 downto 0) := (others => '0');

  --  Dialogic ADPCM Algorithm, table 2
  type STEPVAL_ARRAY is array(0 to 48) of signed(11 downto 0);
  constant STEP_VAL_TABLE : STEPVAL_ARRAY := (
    x"010", x"011", x"013", x"015", x"017", x"019", x"01C", x"01F",
    x"022", x"025", x"029", x"02D", x"032", x"037", x"03C", x"042",
    x"049", x"050", x"058", x"061", x"06B", x"076", x"082", x"08F",
    x"09D", x"0AD", x"0BE", x"0D1", x"0E6", x"0FD", x"117", x"133",
    x"151", x"173", x"198", x"1C1", x"1EE", x"220", x"256", x"292",
    x"2D4", x"31C", x"36C", x"3C3", x"424", x"48E", x"502", x"583",
    x"610"
  );
begin
  p_vck : process (clk)
  begin
    if rising_edge(clk) then
      if cen = '1' and vck_ena = '1' then
        vck_reg <= not vck_reg;
      end if;
    end if;
  end process;

  --  sample clock selector
  p_clk_sel : process (clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        case SAMPLE_FREQ is
          when "00"   => divctr <= x"6"; -- L  L   fosc/96
          when "01"   => divctr <= x"4"; -- L  H   fosc/64
          when "10"   => divctr <= x"3"; -- H  L   fosc/48
          when others => divctr <= x"0"; -- H  H   prohibited
        end case;
      end if;
    end if;
  end process;

  -- divide main clock by a selectable divisor
  p_div : process (clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        if ctr(6 downto 3) = divctr then
          ctr <= "0000001";
          vck_ena <= '1';
        else
          ctr <= ctr + 1;
          vck_ena <= '0';
        end if;
      end if;
    end if;
  end process;

  --  Dialogic ADPCM Algorithm, table 1
  --
  -- Adjust step value based on current ADPCM sample keep it within 0-48 limits.
  process (clk)
  begin
    if rising_edge(clk) then
      if cen = '1' and vck_ena = '1' and vck_reg = '1' then
        if reset = '1' then
          step <= to_unsigned(1, 6);
        else
          case din(2 downto 0) is
            when "111"  => if step < 41 then step <= step + 8; else step <= to_unsigned(48, 6); end if;
            when "110"  => if step < 43 then step <= step + 6; else step <= to_unsigned(48, 6); end if;
            when "101"  => if step < 45 then step <= step + 4; else step <= to_unsigned(48, 6); end if;
            when "100"  => if step < 47 then step <= step + 2; else step <= to_unsigned(48, 6); end if;
            when others => if step >  0 then step <= step - 1; else step <= to_unsigned( 0, 6); end if;
          end case;
        end if;
      end if;
    end if;
  end process;

  process (clk)
  begin
    if rising_edge(clk) then
      if cen = '1' and vck_ena = '1' and vck_reg = '1' then
        if reset = '1' then
          out_val <= to_signed(0, 16);
        else
          -- hard limit math results to 12 bit values
          if (out_val + sign_val < -2048) then
            out_val <= to_signed(-2048, 16); -- underflow, stay on max negative value
          elsif (out_val + sign_val > 2047) then
            out_val <= to_signed(2047, 16); -- overflow,  stay on max positive value
          else
            out_val <= out_val + sign_val;
          end if;
        end if;
      end if;
    end if;
  end process;

  sample <= out_val(11 downto 0);

  -- table lookup only has positive values
  stepval <= STEP_VAL_TABLE(to_integer(step));

  -- so we can afford to just shift in zeroes from the left without sign extension
  stepval1 <=    "0" & stepval(11 downto 0) when din(2) = '1' else (others => '0'); -- value/1
  stepval2 <=   "00" & stepval(11 downto 1) when din(1) = '1' else (others => '0'); -- value/2
  stepval4 <=  "000" & stepval(11 downto 2) when din(0) = '1' else (others => '0'); -- value/4
  stepval8 <= "0000" & stepval(11 downto 3);                                        -- value/8

  sum_val <= (stepval1 + stepval2) + (stepval4 + stepval8);

  sign_val <= sum_val when din(3) = '0' else -sum_val; -- din(3) determines if we return sum or -sum

  vck <= vck_reg;
end rtl;
