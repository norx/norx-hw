-------------------------------------------------------------------------------
--! @file       norxPkg.vhd
--! @brief      NORX package
--! @author     Michael Muehlberghuber (mbgh@iis.ee.ethz.ch)
--! @copyright  Copyright (C) 2015 Integrated Systems Laboratory, ETH Zurich
--! @date       2015-03-04
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

-------------------------------------------------------------------------------
--! @brief NORX package.
--!
--! A package for NORX as defined in the CAESAR submission document.
-------------------------------------------------------------------------------
package norxPkg is

  -----------------------------------------------------------------------------
  -- Types-independent constants
  -----------------------------------------------------------------------------

  -- The length of the authentication tag in bytes (this constant is only needed
  -- by the test bench in order to know how many bits of the provided output
  -- need to be compared against the expected responses).
  constant TAG_LENGTH : integer := 32;
  
  -- The word width (AKA 'word size' in the CAESAR submission of NORX) of the
  -- 4x4xWORD_WIDTH state of NORX in bits (either 64 or 32).
  constant WORD_WIDTH : natural := 64;
  --constant WORD_WIDTH : natural := 32;

  -- Round constants for a word width (W) = 64.
  constant R0 : natural := 8;
  constant R1 : natural := 19;
  constant R2 : natural := 40;
  constant R3 : natural := 63;

  -- Round constants for a word width (W) = 32.
  --constant R0 : natural := 8;
  --constant R1 : natural := 11;
  --constant R2 : natural := 16;
  --constant R3 : natural := 31;

  -- Initialization constants for W = 64.
  constant U0  : std_logic_vector(WORD_WIDTH-1 downto 0) := x"E4D324772B91DF79";
  constant U1  : std_logic_vector(WORD_WIDTH-1 downto 0) := x"3AEC9ABAAEB02CCB";
  constant U2  : std_logic_vector(WORD_WIDTH-1 downto 0) := x"9DFBA13DB4289311";
  constant U3  : std_logic_vector(WORD_WIDTH-1 downto 0) := x"EF9EB4BF5A97F2C8";
  constant U4  : std_logic_vector(WORD_WIDTH-1 downto 0) := x"3F466E92C1532034";
  constant U5  : std_logic_vector(WORD_WIDTH-1 downto 0) := x"E6E986626CC405C1";
  constant U6  : std_logic_vector(WORD_WIDTH-1 downto 0) := x"ACE40F3B549184E1";
  constant U7  : std_logic_vector(WORD_WIDTH-1 downto 0) := x"D9CFD35762614477";
  constant U8  : std_logic_vector(WORD_WIDTH-1 downto 0) := x"B15E641748DE5E6B";
  constant U9  : std_logic_vector(WORD_WIDTH-1 downto 0) := x"AA95E955E10F8410";
  constant U10 : std_logic_vector(WORD_WIDTH-1 downto 0) := x"28D1034441A9DD40";
  constant U11 : std_logic_vector(WORD_WIDTH-1 downto 0) := x"7F31BBF964E93BF5";
  constant U12 : std_logic_vector(WORD_WIDTH-1 downto 0) := x"B5E9E22493DFFB96";
  constant U13 : std_logic_vector(WORD_WIDTH-1 downto 0) := x"B980C852479FAFBD";
  constant U14 : std_logic_vector(WORD_WIDTH-1 downto 0) := x"DA24516BF55EAFD4";
  constant U15 : std_logic_vector(WORD_WIDTH-1 downto 0) := x"86026AE8536F1501";

  -- The constants determining the type of the output data for the destination.
  constant DSTTUSER_UNKNOWN : std_logic_vector(7 downto 0) := x"00";
  constant DSTTUSER_PAYLOAD : std_logic_vector(7 downto 0) := x"01";
  constant DSTTUSER_TAG     : std_logic_vector(7 downto 0) := x"02";


  -----------------------------------------------------------------------------
  -- Types
  -----------------------------------------------------------------------------
  type matrixArrayType is array (0 to 15) of std_logic_vector(WORD_WIDTH-1 downto 0);
  type rateArrayType is array (0 to 11) of std_logic_vector(WORD_WIDTH-1 downto 0);

  -- A record holding all the I/Os required for one G function.
  type gFunctionIORecordType is record
    AInp_D  : std_logic_vector(WORD_WIDTH-1 downto 0);
    BInp_D  : std_logic_vector(WORD_WIDTH-1 downto 0);
    CInp_D  : std_logic_vector(WORD_WIDTH-1 downto 0);
    DInp_D  : std_logic_vector(WORD_WIDTH-1 downto 0);
    AOutp_D : std_logic_vector(WORD_WIDTH-1 downto 0);
    BOutp_D : std_logic_vector(WORD_WIDTH-1 downto 0);
    COutp_D : std_logic_vector(WORD_WIDTH-1 downto 0);
    DOutp_D : std_logic_vector(WORD_WIDTH-1 downto 0);
  end record gFunctionIORecordType;

  -- A type for the different types of processing phases. Note that since we are
  -- investigating only the NORX64-4-1 version of NORX (i.e., with a parallelism
  -- degree of D = 1), we do not include the types for branching and merging.
  -- Since for the next phase, we do not have to distinguish among plaintext
  -- and ciphertext, but are good with a single "PAYLOAD" phase, we also add a
  -- PAYLOAD phase.
  type phaseType is (
    UNKNOWN, CIPHERKEY_NONCE, HEADER, PLAINTEXT, CIPHERTEXT,
    PAYLOAD, TRAILER, TAG);

  -- A type for determining the current mode (encryption or decryption) the
  -- NORX architecture is running in (determined by the control input provided
  -- by the source).
  type modeType is (ENCRYPTION, DECRYPTION);

end package norxPkg;
