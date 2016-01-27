-------------------------------------------------------------------------------
--! @file       init.vhd
--! @brief      Initialization of the NORX state
--! @author     Michael Muehlberghuber (mbgh@iis.ee.ethz.ch)
--! @copyright  Copyright (C) 2015 Integrated Systems Laboratory, ETH Zurich
--! @date       2015-04-02
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.norxPkg.all;

-------------------------------------------------------------------------------
--! @brief Initialization of the NORX state
--!
--! Takes the cipherkey and the nonce and performs the initialization as
--! described by the authors of NORX. Note that since we determine the domain
--! parameters of NORX to be that of NORX64-4-1 and adhere to the suggestion of
--! the NORX authors to use a four-word width wide authentication tag size
--! (i.e., 256 bit), no other variables are required throughout the
--! initialization than the cipherkey and the nonce.
-------------------------------------------------------------------------------
entity init is

  port (
    --! @brief The upper 384 bits of the data input.
    --!
    --! The upper 384 bits of the data input are expected to hold both the
    --! 128-bit wide nonce and the 256-bit wide cipherkey.
    Inp_DI       : in  std_logic_vector(383 downto 0);
    InitState_DO : out matrixArrayType);

end entity init;

-------------------------------------------------------------------------------
--! @brief Behavioral architecture. 
-------------------------------------------------------------------------------
architecture Behavioral of init is

  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------
  signal InitState_D : matrixArrayType;

  
begin  -- architecture Behavioral

  -----------------------------------------------------------------------------
  -- Computation of the initialization state of NORX.
  -----------------------------------------------------------------------------

  -- We expect the nonce to be provided word-by-word in little-endian format
  -- (i.e., the least significant word of the nonce is expected ot be provided
  -- first) in the upper 128 bits of the input data.
  InitState_D(0) <= Inp_DI(383 downto 320);
  InitState_D(1) <= Inp_DI(319 downto 256);

  InitState_D(2) <= U2;
  InitState_D(3) <= U3;

  -- We expect the words of the cipherkey to be provided in little-endian
  -- format (i.e., the least significant word comes first) right after the
  -- nonce within the input data.
  InitState_D(4)  <= Inp_DI(255 downto 192);
  InitState_D(5)  <= Inp_DI(191 downto 128);
  InitState_D(6)  <= Inp_DI(127 downto 64);
  InitState_D(7)  <= Inp_DI(63 downto 0);
  InitState_D(8)  <= U8;
  InitState_D(9)  <= U9;
  InitState_D(10) <= U10;
  InitState_D(11) <= U11;
  InitState_D(12) <= U12;
  InitState_D(13) <= U13;
  InitState_D(14) <= U14;
  InitState_D(15) <= U15;


  -----------------------------------------------------------------------------
  -- Output assignments
  -----------------------------------------------------------------------------
  InitState_DO(0)  <= InitState_D(0);
  InitState_DO(1)  <= InitState_D(1);
  InitState_DO(2)  <= InitState_D(2);
  InitState_DO(3)  <= InitState_D(3);
  InitState_DO(4)  <= InitState_D(4);
  InitState_DO(5)  <= InitState_D(5);
  InitState_DO(6)  <= InitState_D(6);
  InitState_DO(7)  <= InitState_D(7);
  InitState_DO(8)  <= InitState_D(8);
  InitState_DO(9)  <= InitState_D(9);
  InitState_DO(10) <= InitState_D(10);
  InitState_DO(11) <= InitState_D(11);
  -- S12 = S12 xor w
  InitState_DO(12) <= InitState_D(12) xor x"0000000000000040";
  -- S13 = S13 xor l
  InitState_DO(13) <= InitState_D(13) xor x"0000000000000004";
  -- S14 = S14 xor p
  InitState_DO(14) <= InitState_D(14) xor x"0000000000000001";
  -- S15 = S15 xor t
  InitState_DO(15) <= InitState_D(15) xor x"0000000000000100";

end architecture Behavioral;
