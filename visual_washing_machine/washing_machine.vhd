library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity washing_machine is
    Port (
        clk         : in  STD_LOGIC;   -- тактовый сигнал
        reset       : in  STD_LOGIC;   -- асинхронный сброс (активный уровень '1')
        start       : in  STD_LOGIC;   -- кнопка "Старт"
        door_closed : in  STD_LOGIC;   -- датчик двери: ('1' = дверь закрыта)
        water_full  : in  STD_LOGIC;   -- датчик уровня воды

        water_valve : out STD_LOGIC;   -- клапан подачи воды
        drain_pump  : out STD_LOGIC;   -- сливной насос
        motor_on    : out STD_LOGIC;   -- вращение барабана (низкая скорость)
        motor_fast  : out STD_LOGIC;   -- быстрое вращение барабана
        done_led    : out STD_LOGIC;   -- индикатор-светодиод завершения стирки
        error_led   : out STD_LOGIC;   -- индикатор-светодиод о наличии ошибки в работе машины
        state_out   : out STD_LOGIC_VECTOR(2 downto 0)  -- код-индикатор текущего состояния
    );
end washing_machine;

architecture Behavioral of washing_machine is
    
    -- Тип данных с этапами работы машины
    type state_type is (S_IDLE,    -- ожидание запуска
                        S_FILL,    -- набор воды
                        S_WASH,    -- стирка
                        S_DRAIN,   -- слив мыльной воды
                        S_RINSE,   -- полоскание
                        S_SPIN,    -- отжим
                        S_DONE,    -- индикация конца стирки 
                        S_ERROR);  -- индикация ошибки стирки 

    signal state : state_type := S_IDLE;

    -- Временные промежутки для режимов     
    constant T_FILL  : natural := 8;    -- набор воды
    constant T_WASH  : natural := 20;   -- стирка
    constant T_DRAIN : natural := 6;    -- слив
    constant T_RINSE : natural := 12;   -- полоскание
    constant T_SPIN  : natural := 10;   -- отжим

    -- Счетчики
    signal st_key_counter  : natural range 0 to 3; -- счетчик для кнопки start 
    signal st_key_detection: STD_LOGIC := '0'; -- признак нажатия кнопки start без дребезга 
    signal timer           : natural range 0 to 31 := 0; -- счетчик для этапов машины

begin
    
    -- Защита от дребезга кнопки start
    fsm_prot_rattling : process(clk)
    begin
        if(st_key_counter = 3) then
            st_key_counter   <= 0;
            st_key_detection <= '1';
        end if;
         
        if start = '1' then
            if rising_edge(clk) then
                if not(st_key_counter = 3) then
                    st_key_counter   <= st_key_counter + 1;
                    st_key_detection <= '0';                         
                end if;
            end if;
        else
            st_key_counter   <= 0;
            st_key_detection <= '0';                   
        end if;
    end process fsm_prot_rattling;   

    -- Процесс определения перехода к следующему этапу машины
    fsm_transitions : process(clk, reset)
    begin
        if reset = '1' then 
            -- Асинхронный сброс на этап ожидания
            state <= S_IDLE;
            timer <= 0;

        elsif rising_edge(clk) then
            case state is

                when S_IDLE =>
                    timer <= 0;
                    if st_key_detection = '1' and door_closed = '1' then
                        state <= S_FILL;
                    end if;
  
                when S_FILL =>
                    if water_full = '1' then
                        timer <= 0;
                        state <= S_WASH;
                    elsif timer = T_FILL - 1 then
                        timer <= 0;
                        state <= S_ERROR;
                    else
                        timer <= timer + 1;
                    end if;
 
                when S_WASH =>
                    if timer = T_WASH - 1 then
                        timer <= 0;
                        state <= S_DRAIN;
                    else
                        timer <= timer + 1;
                    end if;

                when S_DRAIN =>
                    if timer = T_DRAIN - 1 then
                        if water_full = '1' then
                            timer <= 0;
                            state <= S_ERROR;
                        else 
                            timer <= 0;
                            state <= S_RINSE;
                        end if;
                    else
                        timer <= timer + 1;
                    end if;

                when S_RINSE =>
                    if timer = T_RINSE - 1 then
                        timer <= 0;
                        state <= S_SPIN;
                    else
                        timer <= timer + 1;
                    end if;

                when S_SPIN =>
                    if timer = T_SPIN - 1 then
                        timer <= 0;
                        state <= S_DONE;
                    else
                        timer <= timer + 1;
                    end if;
                
                when S_DONE =>
                    timer <= 0;
                    if door_closed = '0' then
                        state <= S_IDLE;
                    end if;

                when S_ERROR =>
                    timer <= 0;

            end case;
        end if;
    end process fsm_transitions;

    -- Процесс начальной инициализации выходных сигналов
    fsm_outputs : process(state)
    begin

        water_valve <= '0';
        drain_pump  <= '0';
        motor_on    <= '0';
        motor_fast  <= '0';
        done_led    <= '0';
        error_led   <= '0';

        case state is

            when S_IDLE =>
                state_out <= "000";
                -- Ожидание нажатия кнопки и закрытия двери

            when S_FILL =>
                state_out   <= "001";
                water_valve <= '1';       -- открытие клапана набора воды

            when S_WASH =>
                state_out <= "010";
                motor_on  <= '1';         -- включение вращения мотора барабана на низкой скорости

            when S_DRAIN =>
                state_out  <= "011";
                drain_pump <= '1';        -- включение насоса откачки воды

            when S_RINSE =>
                state_out   <= "100";
                water_valve <= '1';       -- включение подачи воды (проточное полоскание)
                motor_on    <= '1';       -- включение вращения мотора барабана на низкой скорости

            when S_SPIN =>
                state_out  <= "101";
                motor_on   <= '1';
                motor_fast <= '1';        -- включение вращения мотора барабана на высокой скорости
                drain_pump <= '1';        -- откачка выжатой воды

            when S_DONE =>
                state_out <= "110";
                done_led  <= '1';         -- индикация светодиодом о завершении цикла

            when S_ERROR =>
                state_out <= "111";
                error_led <= '1';         -- индикация светодиодом о ошибки стирки

        end case;
    end process fsm_outputs;

end Behavioral;

