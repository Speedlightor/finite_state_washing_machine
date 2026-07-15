library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity washing_machine_tb is
end washing_machine_tb;

architecture Behavioral of washing_machine_tb is

    -- Инициализация начальных значений на входах
    signal clk         : STD_LOGIC := '0';
    signal reset       : STD_LOGIC := '0';
    signal start       : STD_LOGIC := '0';
    signal door_closed : STD_LOGIC := '0';   

    signal water_valve : STD_LOGIC;
    signal drain_pump  : STD_LOGIC;
    signal motor_on    : STD_LOGIC;
    signal motor_fast  : STD_LOGIC;
    signal done_led    : STD_LOGIC;
    signal state_out   : STD_LOGIC_VECTOR(2 downto 0);

    -- Период тактового сигнала
    constant CLK_PERIOD : time := 10 ns; -- частота тактирования 100 МГц 
    constant KEY_DELAY: time := CLK_PERIOD*3; -- минимальное время нажатия кнопки для принятия решения о её нажатии (0,25 sec) 
    -- Флаг окончания симуляции
    signal sim_done : boolean := false;

begin

    -- Подключение тестируемого модуля
    uut : entity work.washing_machine -- (UUT = Unit Under Test)

        port map (
            clk         => clk,
            reset       => reset,
            start       => start,
            door_closed => door_closed,
            water_valve => water_valve,
            drain_pump  => drain_pump,
            motor_on    => motor_on,
            motor_fast  => motor_fast,
            done_led    => done_led,
            state_out   => state_out
        );

    -- Генератор тактового сигнала
    clk_gen : process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;   -- тест окончен: процесс останавливается навсегда
    end process clk_gen;

    -- Сценарий тестирования.
    script : process
    begin
        
        -- Тест 1. Старт при ОТКРЫТОЙ двери (door_closed = '0')         
        report "TEST 1: start with open door";
        start <= '1';
        wait for 2 * KEY_DELAY;
        start <= '0';
        wait for 2 * KEY_DELAY;
        -- Ожидаемый результат: state_out = "000" (S_IDLE)
        
        -- Тест 2. Испытание на дребезг кнопки start       
        report "TEST 2: checking the protection of the button from rattling";
        start <= '1';                  -- нажимаем "Старт"
        door_closed <= '1';            -- закрываем дверь
        wait for 2 * CLK_PERIOD;
        start <= '0';                  -- отпускаем кнопку
        wait for 2 * CLK_PERIOD;
        -- Ожидаемый результат: state_out = "000" (S_IDLE)
        
        -- Тест 3. Нормальный запуск полного цикла        
        report "TEST 3: normal start, full wash cycle";         
        start <= '1';                  
        wait for 2 * KEY_DELAY;
        start <= '0';                  
        -- (Полный цикл: 8 + 20 + 6 + 12 + 10 = 56 тактов)
        -- (Ожидаем с запасом, чтобы застать машину в состоянии S_DONE)
        wait for 65 * CLK_PERIOD;
        -- Ожидаемый результат: state_out = "110" (S_DONE), done_led = '1'
        
        -- Тест 4. Открываем дверь после стирки
        report "TEST 4: open door after wash (back to IDLE)";
        door_closed <= '0';
        wait for 4 * CLK_PERIOD;
        -- Ожидаемый результат: state_out = "000" (S_IDLE), done_led = '0'
       
        -- Тест 5. Сброс в середине цикла        
        report "TEST 5: reset in the middle of the cycle";
        door_closed <= '1';
        wait for 2 * CLK_PERIOD;
        start <= '1';
        wait for 2 * KEY_DELAY;
        start <= '0';

        wait for 15 * CLK_PERIOD;      -- машина сейчас на этапе стирки (S_WASH)
        reset <= '1';                  -- аварийный сброс
        wait for 2 * CLK_PERIOD;
        reset <= '0';
        wait for 5 * CLK_PERIOD;
        -- Ожидаемый результат: state_out = "000" (S_IDLE)

        report "SIMULATION FINISHED";
        sim_done <= true;              -- останавливаем генератор тактов
        wait;
    end process script;

end Behavioral;
