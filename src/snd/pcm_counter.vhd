library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.common.all;

-- The PCM counter increments an address range in nibbles.
--
-- The address is used to load data from the PCM ROM.
entity pcm_counter is
  generic (
    ADDR_WIDTH : natural
  );
  port (
    reset : in std_logic;

    clk : in std_logic;
    vck : in std_logic;

    data     : in byte_t;
    we       : in std_logic;
    set_low  : in std_logic;
    set_high : in std_logic;

    -- output address
    addr   : out unsigned(ADDR_WIDTH-1 downto 0);
    nibble : out std_logic;

    -- The done signal is asserted when the counter has reached the end
    -- address.
    done : buffer std_logic
  );
end pcm_counter;

architecture rtl of pcm_counter is
  signal vck_falling : std_logic;

  -- registers
  signal ctr     : unsigned(ADDR_WIDTH+1 downto 0);
  signal ctr_end : unsigned(7 downto 0);
begin
  -- detect falling edges of the VCK signal
  vck_edge_detector : entity work.edge_detector
  generic map (FALLING => true)
  port map (
    clk  => clk,
    data => vck,
    q    => vck_falling
  );

  latch_comp : process (clk, reset)
  begin
    if reset = '1' then
      ctr_end <= (others => '0');
    elsif rising_edge(clk) then
      if set_high = '1' and we = '1' then
        ctr_end <= unsigned(data);
      end if;
    end if;
  end process;

  latch_counter : process (clk, reset)
  begin
    if reset = '1' then
      ctr <= (others => '0');
    elsif rising_edge(clk) then
      if set_low = '1' and we = '1' then
        ctr(ADDR_WIDTH+1 downto ADDR_WIDTH-6) <= unsigned(data);
        ctr(ADDR_WIDTH-7 downto 0) <= (others => '0');
      elsif vck_falling = '1' and done = '0' then
        ctr <= ctr + 1;
      end if;
    end if;
  end process;

  -- set the address and nibble
  addr   <= ctr(ADDR_WIDTH downto 1);
  nibble <= ctr(0);

  -- set the done signal
  done <= '1' when ctr_end = ctr(ADDR_WIDTH+1 downto ADDR_WIDTH-6) else '0';
end rtl;
