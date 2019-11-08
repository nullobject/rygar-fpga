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
use ieee.numeric_std.all;

entity opl is
  port (
    reset : in std_logic;
    clk   : in std_logic;

    irq_n : out std_logic;

    cs   : in std_logic;
    addr : in std_logic_vector(1 downto 0);
    dout : out std_logic_vector(7 downto 0);
    din  : in std_logic_vector(7 downto 0);
    we   : in std_logic;

    sample : out signed(15 downto 0)
  );
end entity opl;

architecture arch of opl is
  signal opl3_dout : std_logic_vector(7 downto 0);

  component opl3 is
    generic (
      OPLCLK : natural
    );
    port (
      clk     : in std_logic;
      clk_opl : in std_logic;
      rst_n   : in std_logic;
      irq_n   : out std_logic;

      period_80us : in std_logic_vector(12 downto 0);

      addr : in std_logic_vector(1 downto 0);
      dout : out std_logic_vector(7 downto 0);
      din  : in std_logic_vector(7 downto 0);
      we   : in std_logic;

      sample_l : out signed(15 downto 0);
      sample_r : out signed(15 downto 0)
    );
  end component opl3;
begin
  opl3_inst : component opl3
  generic map (
    OPLCLK => 48000000
  )
  port map (
    rst_n => not reset,

    clk     => clk,
    clk_opl => clk,

    irq_n => irq_n,

    period_80us => std_logic_vector(to_unsigned(3840, 13)),

    addr => addr,
    din  => din,
    dout => opl3_dout,
    we   => cs and we,

    sample_l => sample,
    sample_r => open
  );

  dout <= opl3_dout when cs = '1' else (others => '0');
end architecture arch;
