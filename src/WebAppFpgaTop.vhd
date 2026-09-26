library ieee;
  use ieee.std_logic_1164.ALL;
  use ieee.numeric_std.all;

entity WebAppFpgaTop is
    generic (
        POWER_ON_RESET_CYCLES_G : natural := 1000000
    );

    port (
        Clk100M : in std_logic;
        eth_col     : in  std_logic;
        eth_crs     : in  std_logic;
        eth_mdc     : out std_logic;
        eth_mdio    : inout std_logic;
        eth_ref_clk : out std_logic;
        eth_rstn    : out std_logic;
        eth_rx_clk  : in  std_logic;
        eth_rx_dv   : in  std_logic;
        eth_rxd     : in  std_logic_vector(3 downto 0);
        eth_rxerr   : in  std_logic;
        eth_tx_clk  : in  std_logic;
        eth_tx_en   : out std_logic;
        eth_txd     : out std_logic_vector(3 downto 0);
        UartRx: in std_logic;
        UartTx: out std_logic;
        Btn0: in std_logic;
        Led0: out std_logic;
        Led1: out std_logic;
        Led2: out std_logic;
        Led3: out std_logic
    );
end;

architecture Behavioral of WebAppFpgaTop is

    constant DEBUG_LED_PULSE_CYCLES : natural := 25000000;

    signal reset_counter : natural range 0 to POWER_ON_RESET_CYCLES_G := 0;
    signal blink_counter : unsigned(26 downto 0) := (others => '0');
    signal rx_led_counter : unsigned(24 downto 0) := (others => '0');
    signal tx_led_counter : unsigned(24 downto 0) := (others => '0');
    signal http_led_counter : unsigned(24 downto 0) := (others => '0');
    signal state_led_3_sync : std_logic_vector(1 downto 0) := (others => '0');
    signal eth_rx_dv_sync : std_logic_vector(1 downto 0) := (others => '0');
    signal eth_tx_en_sync : std_logic_vector(1 downto 0) := (others => '0');
    signal eth_tx_en_i : std_logic;
    signal eth_txd_i : std_logic_vector(3 downto 0);
    signal ethernet_frame_detected : std_logic;
    signal tx_activity_seen : std_logic := '0';
    signal tx_activity_blink : std_logic;
    signal reset_active : std_logic := '1';
    signal nreset_active : std_logic := '0';
    signal btn0_sync : std_logic_vector(2 downto 0) := (others => '0');

begin

    eth_tx_en <= eth_tx_en_i;
    eth_txd <= eth_txd_i;
    tx_activity_blink <= blink_counter(25) when tx_activity_seen = '1' else '0';
    nreset_active <= not reset_active;

    -- LED0: RX activity (any incoming Ethernet frame, 250ms pulse)
    Led0 <= '1' when rx_led_counter /= 0 else '0';

    -- LED1: TX activity (any outgoing Ethernet frame, 250ms pulse)
    Led1 <= '1' when tx_led_counter /= 0 else '0';

    -- LED2: Heartbeat (~0.75 Hz), shows FPGA is running
    Led2 <= blink_counter(26);

    -- LED3: Application frame handling, or direct feedback while BTN0 is held.
    Led3 <= '1' when btn0_sync(2) = '1' or http_led_counter /= 0 else '0';

    reset_release_process : process (Clk100M)
    begin
        if rising_edge(Clk100M) then
            btn0_sync <= btn0_sync(1 downto 0) & Btn0;

            if btn0_sync(2) = '1' then
                reset_counter <= 0;
                reset_active <= '1';
            elsif reset_counter < POWER_ON_RESET_CYCLES_G then
                reset_counter <= reset_counter + 1;
                reset_active <= '1';
            else
                reset_active <= '0';
            end if;
        end if;
    end process;

    led_blink_process : process (Clk100M)
    begin
        if rising_edge(Clk100M) then
            if reset_active = '1' then
                blink_counter <= (others => '0');
            else
                blink_counter <= blink_counter + 1;
            end if;
        end if;
    end process;

    ethernet_debug_led_process : process (Clk100M)
    begin
        if rising_edge(Clk100M) then
            eth_rx_dv_sync <= eth_rx_dv_sync(0) & eth_rx_dv;
            eth_tx_en_sync <= eth_tx_en_sync(0) & eth_tx_en_i;

            state_led_3_sync <= state_led_3_sync(0) & ethernet_frame_detected;

            if reset_active = '1' then
                rx_led_counter <= (others => '0');
                tx_led_counter <= (others => '0');
                http_led_counter <= (others => '0');
                tx_activity_seen <= '0';
            else
                if eth_rx_dv_sync(1) = '1' then
                    rx_led_counter <= to_unsigned(DEBUG_LED_PULSE_CYCLES, rx_led_counter'length);
                elsif rx_led_counter /= 0 then
                    rx_led_counter <= rx_led_counter - 1;
                end if;

                if eth_tx_en_sync(1) = '1' then
                    tx_led_counter <= to_unsigned(DEBUG_LED_PULSE_CYCLES, tx_led_counter'length);
                    tx_activity_seen <= '1';
                elsif tx_led_counter /= 0 then
                    tx_led_counter <= tx_led_counter - 1;
                end if;

                -- EthernetFrameDetected is high while the application retains a frame.
                if state_led_3_sync(1) = '1' then
                    http_led_counter <= to_unsigned(DEBUG_LED_PULSE_CYCLES, http_led_counter'length);
                elsif http_led_counter /= 0 then
                    http_led_counter <= http_led_counter - 1;
                end if;
            end if;
        end if;
    end process;

    WebAppFpga_wrapper_i : entity work.WebAppFpga_wrapper
      port map (
        Clk => Clk100M,
        Clk25M => eth_ref_clk,
        Rst => reset_active,
        MDIO_0_mdc => eth_mdc,
        MDIO_0_mdio_io => eth_mdio,
        MII_0_col => eth_col,
        MII_0_crs => eth_crs,
        MII_0_rst_n => eth_rstn,
        MII_0_rx_clk => eth_rx_clk,
        MII_0_rx_dv => eth_rx_dv,
        MII_0_rx_er => eth_rxerr,
        MII_0_rxd => eth_rxd,
        MII_0_tx_clk => eth_tx_clk,
        MII_0_tx_en => eth_tx_en_i,
        MII_0_txd => eth_txd_i,
        UartRx => UartRx,
        UartTx => UartTx,
        EthernetFrameDetected => ethernet_frame_detected
      );

end;
