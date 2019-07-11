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

use work.rygar.all;

entity palette is
  port (
    -- input clock
    clk : in std_logic;

    -- clock enable
    cen : in std_logic;

    -- palette RAM
    ram_cs   : in std_logic;
    ram_addr : in std_logic_vector(PALETTE_RAM_ADDR_WIDTH_A-1 downto 0);
    ram_din  : in std_logic_vector(PALETTE_RAM_DATA_WIDTH_A-1 downto 0);
    ram_dout : out std_logic_vector(PALETTE_RAM_DATA_WIDTH_A-1 downto 0);
    ram_we   : in std_logic;

    -- layer data
    char_data : in std_logic_vector(7 downto 0);

    video_on : in std_logic;

    -- color outputs
    video_r : out std_logic_vector(COLOR_DEPTH_R-1 downto 0);
    video_g : out std_logic_vector(COLOR_DEPTH_G-1 downto 0);
    video_b : out std_logic_vector(COLOR_DEPTH_B-1 downto 0)
  );
end palette;

architecture arch of palette is
  signal palette_ram_addr : std_logic_vector(PALETTE_RAM_ADDR_WIDTH_B-1 downto 0);
  signal palette_ram_dout : std_logic_vector(PALETTE_RAM_DATA_WIDTH_B-1 downto 0);
begin
  -- The palette RAM is implemented as a 2kB dual-port RAM. Port A is connected
  -- to the 8-bit CPU data bus, while port B is connected to the video output
  -- circuit.
  --
  -- The color palette contains 1024 16-bit color values, stored in
  -- RRRRGGGGXXXXBBBB format.
  palette_ram : entity work.dual_port_ram
  generic map (
    ADDR_WIDTH_A => PALETTE_RAM_ADDR_WIDTH_A,
    ADDR_WIDTH_B => PALETTE_RAM_ADDR_WIDTH_B,
    DATA_WIDTH_A => PALETTE_RAM_DATA_WIDTH_A,
    DATA_WIDTH_B => PALETTE_RAM_DATA_WIDTH_B
  )
  port map (
    clk_a  => clk,
    cen_a  => ram_cs,
    addr_a => ram_addr,
    din_a  => ram_din,
    dout_a => ram_dout,
    we_a   => ram_we,
    clk_b  => clk,
    addr_b => palette_ram_addr,
    dout_b => palette_ram_dout
  );

  process(clk)
  begin
    if rising_edge(clk) then
      if cen = '1' then
        if video_on = '1' then
          palette_ram_addr <= "01" & char_data;

          video_r <= palette_ram_dout(15 downto 12);
          video_g <= palette_ram_dout(11 downto 8);
          video_b <= palette_ram_dout(3 downto 0);
        else
          video_r <= (others => '0');
          video_g <= (others => '0');
          video_b <= (others => '0');
        end if;
      end if;
    end if;
  end process;
end architecture;
