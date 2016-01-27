-------------------------------------------------------------------------------
--! @file       hFunction.vhd
--! @brief      The H function of NORX
--! @author     Michael Muehlberghuber (mbgh@iis.ee.ethz.ch)
--! @copyright  Copyright (C) 2015 Integrated Systems Laboratory, ETH Zurich
--! @date       2015-03-03
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.norxPkg.all;

-------------------------------------------------------------------------------
--! @brief The H function of NORX.
--!
--! The H function of NORX is basically a single bitwise AND, a shift by one
--! bit to the left, and two XOR operations. All of these three operations are
--! carried out on the width of one NORX word (i.e., 32 or 64 bit).
-------------------------------------------------------------------------------
entity hFunction is

  port (
    --! @brief The first input to the H function.
    FirstInp_DI : in std_logic_vector(WORD_WIDTH-1 downto 0);

    --! @brief The second input to the H function (will not be altered at all,
    --!   i.e., it is equal to the second output).
    SecondInp_DI : in std_logic_vector(WORD_WIDTH-1 downto 0);

    --! @brief The first output from the H function.
    FirstOutp_DO : out std_logic_vector(WORD_WIDTH-1 downto 0);

    --! @brief The second output from the H function, which is equal to the
    --!   second input of the function.
    SecondOutp_DO : out std_logic_vector(WORD_WIDTH-1 downto 0));

end entity hFunction;


-------------------------------------------------------------------------------
--! @brief Behavioral architecture of the H function of NORX.
-------------------------------------------------------------------------------
  architecture Behavioral of hFunction is

  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------
  signal Inp1Inp2_D      : std_logic_vector(WORD_WIDTH-1 downto 0);  -- AND of two inputs
  signal Inp1Inp2Shift_D : std_logic_vector(WORD_WIDTH-1 downto 0);  -- Shifted value of the AND of the two inputs


begin  -- architecture Behavioral

  -----------------------------------------------------------------------------
  -- Datapath
  -----------------------------------------------------------------------------
  Inp1Inp2_D      <= FirstInp_DI and SecondInp_DI;
  Inp1Inp2Shift_D <= Inp1Inp2_D(WORD_WIDTH-2 downto 0) & '0';

  -----------------------------------------------------------------------------
  -- Output assignments
  -----------------------------------------------------------------------------
  FirstOutp_DO  <= SecondInp_DI xor Inp1Inp2Shift_D xor FirstInp_DI;
  SecondOutp_DO <= SecondInp_DI;


end architecture Behavioral;
