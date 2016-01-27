-------------------------------------------------------------------------------
--! @file       absorbCiphertext.vhd
--! @brief      Absorbs the ciphertext into the NORX state
--! @author     Michael Muehlberghuber (mbgh@iis.ee.ethz.ch)
--! @copyright  Copyright (C) 2015 Integrated Systems Laboratory, ETH Zurich
--! @date       2015-04-07
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.norxPkg.all;

-------------------------------------------------------------------------------
--! @brief Absorbs the ciphertext into the NORX state
--!
--! For the decryption part of NORX, we need to use only a certain number of
--! bytes from the state, depending on the actual length of the incoming
--! ciphertext. The other bytes are taken from the incoming ciphertext. Hence,
--! this module absorbs the needed number of ciphertext bytes into the state
--! (depending on the length of the payload) and leaves the other bytes
--! untouched.
-------------------------------------------------------------------------------
entity absorbCiphertext is

  port (
    --! @brief The curent rate of the NORX state.
    CurrRate_DI : in rateArrayType;

    --! @brief The payload to be integrated into the state.
    Payload_DI : in rateArrayType;

    --! @brief The length of the incoming payload (in bytes).
    PayloadLen_SI : in std_logic_vector(6 downto 0);

    --! @brief The absorbed ciphertext depending on the payload length.
    --!
    --! The absorbed ciphertext (from the previous state and the incoming
    --! data), depending on the length of the payload (in bytes).
    AbsorbedCiphertext_DO : out rateArrayType);

end entity absorbCiphertext;


-------------------------------------------------------------------------------
--! @brief Behavioral architecture.
-------------------------------------------------------------------------------
architecture Behavioral of absorbCiphertext is

  -----------------------------------------------------------------------------
  -- Types
  -----------------------------------------------------------------------------
  type rateByteArrayType is array (0 to 95) of std_logic_vector(7 downto 0);
  type wordByteArrayType is array (0 to 7) of std_logic_vector(7 downto 0);


  -----------------------------------------------------------------------------
  -- Functions
  -----------------------------------------------------------------------------

  -- purpose: Converts one NORX word of 64-bits into an array of eigth bytes.
  function word_2_byte_array (
    word_inp : in std_logic_vector(WORD_WIDTH-1 downto 0))
    return wordByteArrayType is
    variable result : wordByteArrayType;
  begin  -- function word_2_byte_array
    result(0) := word_inp(7 downto 0);
    result(1) := word_inp(15 downto 8);
    result(2) := word_inp(23 downto 16);
    result(3) := word_inp(31 downto 24);
    result(4) := word_inp(39 downto 32);
    result(5) := word_inp(47 downto 40);
    result(6) := word_inp(55 downto 48);
    result(7) := word_inp(63 downto 56);
    return result;
  end function word_2_byte_array;


  -- purpose: Converts an array of eight bytes into a NORX word of 64-bits.
  function byte_array_2_word (
    word_byte_array : in wordByteArrayType)
    return std_logic_vector is
    variable result : std_logic_vector(WORD_WIDTH-1 downto 0);
  begin  -- function byte_array_2_word
    result(7 downto 0)   := word_byte_array(0);
    result(15 downto 8)  := word_byte_array(1);
    result(23 downto 16) := word_byte_array(2);
    result(31 downto 24) := word_byte_array(3);
    result(39 downto 32) := word_byte_array(4);
    result(47 downto 40) := word_byte_array(5);
    result(55 downto 48) := word_byte_array(6);
    result(63 downto 56) := word_byte_array(7);

    return result;
  end function byte_array_2_word;


  -- purpose: Converts a NORX rate, represented as an array of twelve 64-bit words,
  -- into a NORX rate, represented as an array of 96 bytes.
  function word_rate_2_byte_rate (
    inp : rateArrayType)
    return rateByteArrayType is
    variable word_byte_array : wordByteArrayType;
    variable result          : rateByteArrayType;
  begin  -- function word_rate_2_byte_rate

    -- Convert each of the ten 64-bit words into a byte array;
    (result(0), result(1), result(2), result(3), result(4), result(5), result(6), result(7))         := word_2_byte_array(inp(0));
    (result(8), result(9), result(10), result(11), result(12), result(13), result(14), result(15))   := word_2_byte_array(inp(1));
    (result(16), result(17), result(18), result(19), result(20), result(21), result(22), result(23)) := word_2_byte_array(inp(2));
    (result(24), result(25), result(26), result(27), result(28), result(29), result(30), result(31)) := word_2_byte_array(inp(3));
    (result(32), result(33), result(34), result(35), result(36), result(37), result(38), result(39)) := word_2_byte_array(inp(4));
    (result(40), result(41), result(42), result(43), result(44), result(45), result(46), result(47)) := word_2_byte_array(inp(5));
    (result(48), result(49), result(50), result(51), result(52), result(53), result(54), result(55)) := word_2_byte_array(inp(6));
    (result(56), result(57), result(58), result(59), result(60), result(61), result(62), result(63)) := word_2_byte_array(inp(7));
    (result(64), result(65), result(66), result(67), result(68), result(69), result(70), result(71)) := word_2_byte_array(inp(8));
    (result(72), result(73), result(74), result(75), result(76), result(77), result(78), result(79)) := word_2_byte_array(inp(9));
    (result(80), result(81), result(82), result(83), result(84), result(85), result(86), result(87)) := word_2_byte_array(inp(10));
    (result(88), result(89), result(90), result(91), result(92), result(93), result(94), result(95)) := word_2_byte_array(inp(11));

    return result;
  end function word_rate_2_byte_rate;

  -- purpose: Converts a NORX rate, represented as an array of 96 bytes, into a
  -- NORX rate, represented as an array of twelve 64-bit words.
  function byte_rate_2_word_rate (
    inp : rateByteArrayType)
    return rateArrayType is
    variable result : rateArrayType;
  begin  -- function byte_rate_2_word_rate

    -- Convert a group of eight bytes into one word.
    result(0)  := byte_array_2_word((inp(0), inp(1), inp(2), inp(3), inp(4), inp(5), inp(6), inp(7)));
    result(1)  := byte_array_2_word((inp(8), inp(9), inp(10), inp(11), inp(12), inp(13), inp(14), inp(15)));
    result(2)  := byte_array_2_word((inp(16), inp(17), inp(18), inp(19), inp(20), inp(21), inp(22), inp(23)));
    result(3)  := byte_array_2_word((inp(24), inp(25), inp(26), inp(27), inp(28), inp(29), inp(30), inp(31)));
    result(4)  := byte_array_2_word((inp(32), inp(33), inp(34), inp(35), inp(36), inp(37), inp(38), inp(39)));
    result(5)  := byte_array_2_word((inp(40), inp(41), inp(42), inp(43), inp(44), inp(45), inp(46), inp(47)));
    result(6)  := byte_array_2_word((inp(48), inp(49), inp(50), inp(51), inp(52), inp(53), inp(54), inp(55)));
    result(7)  := byte_array_2_word((inp(56), inp(57), inp(58), inp(59), inp(60), inp(61), inp(62), inp(63)));
    result(8)  := byte_array_2_word((inp(64), inp(65), inp(66), inp(67), inp(68), inp(69), inp(70), inp(71)));
    result(9)  := byte_array_2_word((inp(72), inp(73), inp(74), inp(75), inp(76), inp(77), inp(78), inp(79)));
    result(10) := byte_array_2_word((inp(80), inp(81), inp(82), inp(83), inp(84), inp(85), inp(86), inp(87)));
    result(11) := byte_array_2_word((inp(88), inp(89), inp(90), inp(91), inp(92), inp(93), inp(94), inp(95)));

    return result;
  end function byte_rate_2_word_rate;


  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------
  signal CurrRate_D           : rateByteArrayType;
  signal Payload_D            : rateByteArrayType;
  signal CombinedRate_D       : rateByteArrayType;
  signal FirstByteCorr_D      : rateByteArrayType;
  signal LastByteCorr_D       : rateByteArrayType;
  signal AbsorbedCiphertext_D : rateByteArrayType;

  signal PayloadLen_S : unsigned(6 downto 0);

begin  -- architecture Behavioral

  -- Convert the incoming word-based rate into a byte array representing the
  -- rate.
  CurrRate_D <= word_rate_2_byte_rate(CurrRate_DI);
  Payload_D  <= word_rate_2_byte_rate(Payload_DI);

  -- Cast of the incoming payload length.
  PayloadLen_S <= unsigned(PayloadLen_SI);


  -- Create the MUX network, required to select either the current rate or the
  -- incoming payload depending on the length of the payload.
  gen_CombinedRate : for i in 0 to 95 generate
    CombinedRate_D(i) <= Payload_D(i) when i < PayloadLen_S else CurrRate_D(i);
  end generate gen_CombinedRate;

  
  -----------------------------------------------------------------------------
  -- Corrections, needed for the last input block.
  -----------------------------------------------------------------------------
  
  -- Next, we need to correct the first byte after the payload input.
  gen_FirstByteCorr : for i in 0 to 95 generate
    -- The first bit of the byte, which comes right after the payload, needs to
    -- be flipped.
    FirstByteCorr_D(i) <= CombinedRate_D(i) xor x"01" when i = PayloadLen_S else CombinedRate_D(i);
  end generate gen_FirstByteCorr;

  -- Only the last byte of the last block needs to be adapted.
  gen_LastByteCorr : for i in 0 to 94 generate
    LastByteCorr_D(i) <= FirstByteCorr_D(i);
  end generate gen_LastByteCorr;

  -- Finally, the last byte of the last block must be corrected.
  LastByteCorr_D(95) <= FirstByteCorr_D(95) xor x"80";

  -- Only the last block needs to be adapted.
  AbsorbedCiphertext_D <= LastByteCorr_D when PayloadLen_S < 96 else Payload_D;
  

  -----------------------------------------------------------------------------
  -- Output assignment
  -----------------------------------------------------------------------------
  
  -- Convert the byte-array-based rate back into the word-array-based rate.
  AbsorbedCiphertext_DO <= byte_rate_2_word_rate(AbsorbedCiphertext_D);

end architecture Behavioral;
