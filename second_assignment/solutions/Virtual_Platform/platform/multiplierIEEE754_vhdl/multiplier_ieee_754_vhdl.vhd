-- Package definition
package states_pkg is

    -- Size of input and output
    constant SIZE               : INTEGER := 32;
    constant SIZE_OF_MANTISSA   : INTEGER := 23;
    constant SIZE_OF_EXPONENT   : INTEGER := 8;
    
    -- States definition
    constant ST_0       : INTEGER := 0;
    constant ST_1       : INTEGER := 1;
    constant ST_2       : INTEGER := 2;
    constant ST_ZERO    : INTEGER := 3;
    constant ST_INF     : INTEGER := 4;
    constant ST_NAN     : INTEGER := 5;
    constant ST_3       : INTEGER := 6;
    constant ST_4       : INTEGER := 7;
    constant ST_5       : INTEGER := 8;
    constant ST_6       : INTEGER := 9;
    constant ST_7       : INTEGER := 10;
    constant ST_8       : INTEGER := 11;
    constant ST_9       : INTEGER := 12;
    constant ST_10      : INTEGER := 13;
    constant ST_11      : INTEGER := 14;
    constant ST_ROUND   : INTEGER := 15;
    constant ST_12      : INTEGER := 16;
    constant ST_NORM    : INTEGER := 17;
    constant ST_DENORM  : INTEGER := 18;
    constant ST_OUT     : INTEGER := 19;
    constant ST_ERR     : INTEGER := 20;
    
    subtype TYPE_STATE is INTEGER range ST_0 to ST_ERR;
end states_pkg;

-- Libraries
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use WORK.states_pkg.ALL;

entity multiplier_ieee_754_vhdl is
    port (
        clk         : in    STD_LOGIC;
        rst         : in    STD_LOGIC;
        op1         : in    STD_LOGIC_VECTOR(SIZE-1 downto 0);
        op2         : in    STD_LOGIC_VECTOR(SIZE-1 downto 0);
        in_rdy      : in    STD_LOGIC;
        res         : out   STD_LOGIC_VECTOR(SIZE-1 downto 0);
        res_rdy     : out   STD_LOGIC
    );
end entity multiplier_ieee_754_vhdl;


architecture arch_multiplier_ieee_754_vhdl of multiplier_ieee_754_vhdl is
    -- aux signals
    signal m            : STD_LOGIC_VECTOR(SIZE_OF_MANTISSA - 1 DOWNTO 0) := (OTHERS => '0');
    signal m1           : STD_LOGIC_VECTOR(SIZE_OF_MANTISSA DOWNTO 0) := (OTHERS => '0');
    signal m2           : STD_LOGIC_VECTOR(SIZE_OF_MANTISSA DOWNTO 0) := (OTHERS => '0');
    signal tmpm         : STD_LOGIC_VECTOR(((SIZE_OF_MANTISSA + 1) * 2) - 1 DOWNTO 0) := (OTHERS => '0');
    signal tmpexp       : STD_LOGIC_VECTOR(SIZE_OF_EXPONENT DOWNTO 0) := (OTHERS => '0');
    signal exp          : STD_LOGIC_VECTOR(SIZE_OF_EXPONENT - 1 DOWNTO 0) := (OTHERS => '0');
    signal s            : STD_LOGIC;
    
    -- State managment
    signal next_state : TYPE_STATE := ST_0;   
begin
    -- FSM
    FSM : process(clk, rst)
    begin
        if rst = '1' then
            next_state <= ST_0;
        elsif clk'EVENT and clk = '1' then
            case next_State is
                when ST_0 =>
                    -- Init or reset
                    next_state <= ST_1;
                when ST_1 =>
                    -- Wait for in_rdy
                    if in_rdy = '1' then
                        next_state <= ST_2;
                    else
                        next_state <= ST_1;
                    end if;
                when ST_2 =>
                    -- Input dispatch
                    if (op1(30 downto 23) = 255 and m1 /= 0) or (op2(30 downto 23) = 255 and m2 /= 0) then
                        -- op1 or op2 are nan
                        next_state <= ST_NAN;
                    elsif (op1(30 downto 23) = 255 and m1 = 0 and op2(30 downto 23) = 0 and m2 = 0) 
                    or (op2(30 downto 23) = 255 and m2 = 0 and op1(30 downto 23) = 0 and m1 = 0) then
                        -- op1 is inf and op2 is 0 or the other way around
                        next_state <= ST_NAN;
                    elsif (op1(30 downto 23) = 255 and m1 = 0) or (op2(30 downto 23) = 255 and m2 = 0) then
                        -- op1 or op2 are inf
                        next_state <= ST_INF;
                    elsif (op1(30 downto 23) = 0 and m1 = 0) or (op2(30 downto 23) = 0 and m2 = 0) then
                        -- op1 or op2 are zero
                        next_state <= ST_ZERO;
                    else
                        -- op1 and/or op2 are normalized or denormalized numbers
                        next_state <= ST_3;
                    end if;
                when ST_3 =>
                    -- Manage normalized and denormalized input
                    if (op1(30 downto 23) = 0 or op2(30 downto 23) = 0) then
                        -- op1 and op2 are denormalized
                        next_state <= ST_ERR;
                    else
                        -- op1 and/or op2 are not normalized
                        next_state <= ST_4;
                    end if;
                when ST_4 =>
                    -- Check if mantissa result is normalized or not
                    if (tmpm(47 downto 46) = "10") or (tmpm(47 downto 46) = "11") then
                        -- Basic normalizzation
                        next_state <= ST_5;
                    elsif (tmpm(47 downto 46) = "00") then
                        -- Shift normalization
                        next_state <= ST_6;
                    else -- case "10"
                        -- Already normalized
                        next_state <= ST_NORM;
                    end if;
                when ST_5 =>
                    -- Number normalizes
                    next_state <= ST_NORM;
                when ST_6 =>
                    -- Check exponent overflow after shift normaliazzation
                    if tmpexp(8) = '1' then
                        -- Overflow
                        next_state <= ST_7;
                    else
                        -- No overflow but can get underflow
                        next_state <= ST_8;
                    end if;
                when ST_7 =>
                    -- Manage overflow during multiplication
                    if (tmpm(47 downto 46) = "00") then
                        next_state <= ST_7;
                    else
                        next_state <= ST_NORM;
                    end if;
                when ST_8 =>
                    -- Check and manage underflow
                    if (tmpexp(8 downto 0) = 0) then
                        -- Underflow
                        next_state <= ST_DENORM;
                    elsif (tmpm(47 downto 46) = "00") then
                        next_state <= ST_8;
                    else
                        -- Finish normalization
                        next_state <= ST_NORM;
                    end if;
                when ST_NORM =>
                    if tmpexp(8) = '1' then
                        next_state <= ST_INF;
                    else
                        next_state <= ST_9;
                    end if;
                when ST_DENORM =>
                    next_state <= ST_10;
                when ST_9 =>
                    next_state <= ST_10;
                when ST_10 =>
                    if tmpm(23) = '0' then
                        -- Prepare result
                        next_state <= ST_11;
                    else
                        next_state <= ST_ROUND;
                    end if;
                when ST_11 =>
                    -- Prepare result
                    next_state <= ST_OUT;
                when ST_ROUND =>
                    if (tmpm(47 downto 46) = "01") then
                        next_state <= ST_12;
                    else
                        -- Prepare result
                        next_state <= ST_11;
                    end if;
                when ST_12 =>
                    next_state <= ST_OUT;
                when ST_ZERO => 
                    next_state <= ST_OUT;
                when ST_NAN => 
                    next_state <= ST_OUT;
                when ST_INF => 
                    next_State <= ST_OUT;
                when ST_OUT =>
                    next_state <= ST_0;
                when ST_ERR =>
                    next_state <= ST_0;
                when OTHERS => 
                    next_state <= ST_0;
            end case;
        end if;
     end process FSM;
     
     -- DATAPATH
     DATAPATH : process(next_state)
     begin
        case next_state is
            when ST_0 =>
                -- Reset all 
                m <= (others => '0');
                m1 <= (others => '0');
                m2 <= (others => '0');
                tmpm <= (others => '0');
                tmpexp <= (others => '0');
                exp <= (others => '0');
                s <= '0';
                res <= (others => '0');
                res_rdy <= '0'; 
            when ST_1 =>
                -- Do Nothing
            when ST_2 =>
                m1(22 downto 0) <= op1(22 downto 0);
                m2(22 downto 0) <= op2(22 downto 0);
                s <= op1(31) xor op2(31);
            when ST_3 =>
                m1(23) <= '1';
                m2(23) <= '1';
            when ST_4 =>
                -- sum - bias
                tmpexp <= ('0' & op1(30 downto 23)) + ('0' & op2(30 downto 23)) - 127;
                -- Mantix multiplication
                tmpm <= m1 * m2;
            when ST_5 =>
                -- tmpm >> 1
                tmpm <= '0' & tmpm(((SIZE_OF_MANTISSA + 1) * 2) - 1 downto 1);
                tmpexp <= tmpexp + 1;
            when ST_6 =>
                -- Nothing to do
            WHEN ST_7 => 
                -- tmpm << 1
                tmpm <= '0' & tmpm(((SIZE_OF_MANTISSA + 1) * 2) - 2 downto 0); 
                tmpexp <= tmpexp - 1;
            WHEN ST_8 => 
                -- tmpm << 1
                tmpm <= '0' & tmpm(((SIZE_OF_MANTISSA + 1) * 2) - 2 downto 0);
                tmpexp <= tmpexp - 1;
            WHEN ST_NORM =>
                -- Do nothing
            WHEN ST_DENORM =>
                exp <= (others => '0');
            WHEN ST_9 =>
                exp <= tmpexp(7 downto 0);
            WHEN ST_10 =>
                -- Do nothing
            WHEN ST_11 => 
                m <= tmpm(45 downto 23);
            WHEN ST_ROUND =>
                tmpm(47 downto 22) <= tmpm(47 downto 22) + 1;
            WHEN ST_12 => 
                tmpexp <= tmpexp + 1;
            WHEN ST_NAN =>
                exp <= (others => '1');
                m <= (22 => '1', 21 downto 0 => '0');
                s <= '0';
            WHEN ST_INF => 
                exp <= (others => '1');
                m <= (others => '0');
            WHEN ST_ZERO => 
                exp <= (others => '0');
                m <= (others => '0');
            WHEN ST_OUT => 
                res_rdy <= '1';
                res(31) <= s;
                res(30 downto 23) <= exp;
                res(22 downto 0) <= m;
            WHEN ST_ERR => 
                res_rdy <= '1';
                res <= (others => '0');
            WHEN OTHERS => 
                    res_rdy <= '1';
                -- Do nothing
        end case;
     end process DATAPATH;
end architecture arch_multiplier_ieee_754_vhdl;
