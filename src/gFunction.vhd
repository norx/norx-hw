-------------------------------------------------------------------------------
--! @file       gFunction.vhd
--! @brief      The G function of NORX
--! @author     Michael Muehlberghuber (mbgh@iis.ee.ethz.ch)
--! @copyright  Copyright (C) 2015 Integrated Systems Laboratory, ETH Zurich
--! @date       2015-03-03
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;

library work;
use work.norxPkg.all;

-------------------------------------------------------------------------------
--! @brief The G function of NORX.
--!
--! This entity contains a fully combinational implementation of the G function
--! of NORX (since we aim at developing a high-speed implementation of NORX).
-------------------------------------------------------------------------------
entity gFunction is

  port (
    --! @brief  Input word 'a' as defined in the CAESAR submission of NORX.
    AInp_DI : in std_logic_vector(WORD_WIDTH-1 downto 0);

    --! @brief Input word 'b' as defined in the CAESAR submission of NORX.
    BInp_DI : in std_logic_vector(WORD_WIDTH-1 downto 0);

    --! @brief Input word 'c' as defined in the CAESAR submission of NORX.
    CInp_DI : in std_logic_vector(WORD_WIDTH-1 downto 0);

    --! @brief Input word 'd' as defined in the CAESAR submission of NORX.
    DInp_DI : in std_logic_vector(WORD_WIDTH-1 downto 0);

    --! @brief Output word 'a' as defined in the CAESAR submission of NORX.
    AOutp_DO : out std_logic_vector(WORD_WIDTH-1 downto 0);

    --! @brief Output word 'b' as defined in the CAESAR submission of NORX.
    BOutp_DO : out std_logic_vector(WORD_WIDTH-1 downto 0);

    --! @brief Output word 'c' as defined in the CAESAR submission of NORX.
    COutp_DO : out std_logic_vector(WORD_WIDTH-1 downto 0);

    --! @brief Output word 'd' as defined in the CAESAR submission of NORX.
    DOutp_DO : out std_logic_vector(WORD_WIDTH-1 downto 0));

end entity gFunction;


-------------------------------------------------------------------------------
--! @brief Behavioral architecture of the G function of NORX.
-------------------------------------------------------------------------------
architecture Behavioral of gFunction is

  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------

  -- I/O signals of the first H function.
  signal H1Out1_D : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal H1Out2_D : std_logic_vector(WORD_WIDTH-1 downto 0);

  -- I/O signals of the second H function.
  signal H2Out1_D : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal H2Out2_D : std_logic_vector(WORD_WIDTH-1 downto 0);

  -- I/O signals of the third H function.
  signal H3Out1_D : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal H3Out2_D : std_logic_vector(WORD_WIDTH-1 downto 0);

  -- I/O signals of the fourth H function.
  signal H4Out1_D : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal H4Out2_D : std_logic_vector(WORD_WIDTH-1 downto 0);

  -- Intermediate signals
  signal DXH1_D    : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal DXH1Rot_D : std_logic_vector(WORD_WIDTH-1 downto 0);

  signal BXH1_D    : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal BXH1Rot_D : std_logic_vector(WORD_WIDTH-1 downto 0);

  signal H2XH3_D    : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal H2XH3Rot_D : std_logic_vector(WORD_WIDTH-1 downto 0);

  signal H3XH4_D    : std_logic_vector(WORD_WIDTH-1 downto 0);
  signal H3XH4Rot_D : std_logic_vector(WORD_WIDTH-1 downto 0);


  -----------------------------------------------------------------------------
  -- Functions
  -----------------------------------------------------------------------------
  -- purpose: Rotates a given input word by a certain constant.
  function rot_word (
    signal word    : std_logic_vector(WORD_WIDTH-1 downto 0);
    constant const : natural)
    return std_logic_vector is
  begin  -- function rot_word
    return word(const-1 downto 0) & word(WORD_WIDTH-1 downto const);
  end function rot_word;

begin  -- architecture Behavioral

  -----------------------------------------------------------------------------
  -- Datapath of the G function.
  -----------------------------------------------------------------------------

  -- Instantiate the four H functions.
  hFunction_1 : entity work.hFunction
    port map (
      FirstInp_DI   => AInp_DI,
      SecondInp_DI  => BInp_DI,
      FirstOutp_DO  => H1Out1_D,
      SecondOutp_DO => H1Out2_D);

  hFunction_2 : entity work.hFunction
    port map (
      FirstInp_DI   => CInp_DI,
      SecondInp_DI  => DXH1Rot_D,
      FirstOutp_DO  => H2Out1_D,
      SecondOutp_DO => H2Out2_D);

  hFunction_3 : entity work.hFunction
    port map (
      FirstInp_DI   => H1Out1_D,
      SecondInp_DI  => BXH1Rot_D,
      FirstOutp_DO  => H3Out1_D,
      SecondOutp_DO => H3Out2_D);

  hFunction_4 : entity work.hFunction
    port map (
      FirstInp_DI   => H2Out1_D,
      SecondInp_DI  => H2XH3Rot_D,
      FirstOutp_DO  => H4Out1_D,
      SecondOutp_DO => H4Out2_D);


  -----------------------------------------------------------------------------
  -- Datapath
  -----------------------------------------------------------------------------

  -- XOR and rotation before second H function.
  DXH1_D    <= DInp_DI xor H1Out1_D;
  DXH1Rot_D <= rot_word(DXH1_D, R0);

  -- XOR and rotation before third H function.
  BXH1_D    <= H1Out2_D xor H2Out1_D;
  BXH1Rot_D <= rot_word(BXH1_D, R1);

  -- XOR and rotation before fourth H function.
  H2XH3_D    <= H2Out2_D xor H3Out1_D;
  H2XH3Rot_D <= rot_word(H2XH3_D, R2);

  -- XOR and rotation after fourth H function.
  H3XH4_D    <= H3Out2_D xor H4Out1_D;
  H3XH4Rot_D <= rot_word(H3XH4_D, R3);


  -----------------------------------------------------------------------------
  -- Output assignments
  -----------------------------------------------------------------------------
  AOutp_DO <= H3Out1_D;
  BOutp_DO <= H3XH4Rot_D;
  COutp_DO <= H4Out1_D;
  DOutp_DO <= H4Out2_D;

end architecture Behavioral;
