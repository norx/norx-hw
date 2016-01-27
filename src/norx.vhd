-------------------------------------------------------------------------------
--! @file       norx.vhd
--! @brief      High-throughput NORX based on eight G functions
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
--! @brief High-throughput NORX based on eight G functions
--!
--! A high-throughput implementation of NORX based on eight instances of the G
--! function. The design is supposed to reach a throughput of 100Gbps for the
--! targeted 65nm ASIC technology. An AXI4-Stream Protocol is used for both
--! providing data as well as to obtain the data from the design.
-------------------------------------------------------------------------------
entity norx is

  port (
    --! @brief System clock.
    Clk_CI : in std_logic;

    --! @brief Synchronous, active-low reset.
    Reset_RBI : in std_logic;

    -- AXI4 Stream Protocol for inputs from the source.
    ---------------------------------------------------------------------------
    --! @brief Indicates that the source applies valid data.
    SlaveTValid_SI : in std_logic;

    --! @brief Indicates to the source that the presetn design is ready to
    --!   obtain data.
    SlaveTReady_SO : out std_logic;

    --! @brief User-specific controlling data from the source.
    SlaveTUser_SI : in std_logic_vector(15 downto 0);

    --! @brief Input data from the source.
    SlaveTData_DI : in std_logic_vector(767 downto 0);

    -- AXI4 Stream Protocol for the outputs to the destination.
    ---------------------------------------------------------------------------
    --! @brief Indicates that the present design applies valid data to be
    --!   obtained by the destination.
    MasterTValid_SO : out std_logic;

    --! @brief Indicates that the destination is ready to obtain data.
    MasterTReady_SI : in std_logic;

    --! @brief User-specific data for the destination.
    MasterTUser_SO : out std_logic_vector(7 downto 0);

    --! @brief Output data to the destination.
    MasterTData_DO : out std_logic_vector(767 downto 0)
    );

end entity norx;

architecture Behavioral of norx is

  -----------------------------------------------------------------------------
  -- Types
  -----------------------------------------------------------------------------
  type inputFsmStateType is (RESET, WAIT4INPUT, WAIT4READY);
  type mainFsmStateType is (RESET, IDLE, PROCESS_STATE, COMPUTE_TAG);

  type capacityArrayType is array (0 to 3) of std_logic_vector(WORD_WIDTH-1 downto 0);


  -----------------------------------------------------------------------------
  -- Functions
  -----------------------------------------------------------------------------

  -- purpose: Provides an exclusive-or (XOR) operation between an array of
  -- twelve NORX words containing the current rate and a std_logic_vector.
  function "xor" (
    left  : rateArrayType;
    right : std_logic_vector(767 downto 0))
    return rateArrayType is
    variable result : rateArrayType;
  begin  -- function "xor"
    result(0)  := left(0) xor right(767 downto 704);
    result(1)  := left(1) xor right(703 downto 640);
    result(2)  := left(2) xor right(639 downto 576);
    result(3)  := left(3) xor right(575 downto 512);
    result(4)  := left(4) xor right(511 downto 448);
    result(5)  := left(5) xor right(447 downto 384);
    result(6)  := left(6) xor right(383 downto 320);
    result(7)  := left(7) xor right(319 downto 256);
    result(8)  := left(8) xor right(255 downto 192);
    result(9)  := left(9) xor right(191 downto 128);
    result(10) := left(10) xor right(127 downto 64);
    result(11) := left(11) xor right(63 downto 0);
    return result;
  end function "xor";

  -- purpose: Provides an exclusive-or (XOR) operation between a NORX word and
  -- a five bit std_logic_vector.
  function xor_domain_constant (
    left  : std_logic_vector(WORD_WIDTH-1 downto 0);
    right : std_logic_vector(4 downto 0))
    return std_logic_vector is
    variable result : std_logic_vector(WORD_WIDTH-1 downto 0);
  begin  -- function "xor"
    -- Only the least-significant five bits of the std_logic_vector are
    -- actually being influenced.
    result(WORD_WIDTH-1 downto 5) := left(WORD_WIDTH-1 downto 5);
    result(4 downto 0)            := left(4 downto 0) xor right;
    return result;
  end function xor_domain_constant;

  -- purpose: Converts a std_logic_vector into a state array holding twelve
  -- 64-bit elements.
  function std_logic_vector_2_rate_array (
    inp : std_logic_vector(767 downto 0))
    return rateArrayType is
    variable result : rateArrayType;
  begin  -- function std_logic_vector_2_rate_array
    result(0)  := inp(767 downto 704);
    result(1)  := inp(703 downto 640);
    result(2)  := inp(639 downto 576);
    result(3)  := inp(575 downto 512);
    result(4)  := inp(511 downto 448);
    result(5)  := inp(447 downto 384);
    result(6)  := inp(383 downto 320);
    result(7)  := inp(319 downto 256);
    result(8)  := inp(255 downto 192);
    result(9)  := inp(191 downto 128);
    result(10) := inp(127 downto 64);
    result(11) := inp(63 downto 0);
    return result;
  end function std_logic_vector_2_rate_array;

  -- purpose: Converts a state array holding twelve 64-bit elements into a
  -- std_logic_vector.
  function rate_array_2_std_logic_vector (
    inp : rateArrayType)
    return std_logic_vector is
    variable result : std_logic_vector(767 downto 0);
  begin  -- function rate_array_2_std_logic_vector
    result(767 downto 704) := inp(0);
    result(703 downto 640) := inp(1);
    result(639 downto 576) := inp(2);
    result(575 downto 512) := inp(3);
    result(511 downto 448) := inp(4);
    result(447 downto 384) := inp(5);
    result(383 downto 320) := inp(6);
    result(319 downto 256) := inp(7);
    result(255 downto 192) := inp(8);
    result(191 downto 128) := inp(9);
    result(127 downto 64)  := inp(10);
    result(63 downto 0)    := inp(11);
    return result;
  end function rate_array_2_std_logic_vector;


  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------

  -- Registers
  -----------------------------------------------------------------------------

  -- The register for holding the state of the FSM controlling the input
  -- handshaking.
  signal InputFsmState_SN, InputFsmState_SP : inputFsmStateType;

  -- The register for holding the state of the FSM controlling the actual NORX
  -- computation.
  signal MainFsmState_SN, MainFsmState_SP : mainFsmStateType;

  -- The register holding the NORX state.
  signal NorxStateEn_S              : std_logic;
  signal NorxState_DN, NorxState_DP : matrixArrayType;

  -- The input register for the control input.
  signal SlaveTUserEn_S             : std_logic;
  signal SlaveTUser_SN, SlaveTUser_SP : std_logic_vector(15 downto 0);

  -- The input register for the data input.
  signal SlaveTDataEn_S               : std_logic;
  signal SlaveTData_DN, SlaveTData_DP : std_logic_vector(767 downto 0);

  -- The register for storing the type of the current phase. This is required
  -- since the value identifying the current phase is transmitted at the
  -- beginning of an actual NORX phase, but the value of the domain separation
  -- constant (which is determined by the type of the next phase), is not only
  -- needed within the same clock cycle (e.g., when the cipherkey and the nonce
  -- are provided, we first have to perform a full F^R permutation, before we
  -- need to choose the domain separation constant depending on the type of the
  -- next phase). Meanwhile, the input register may have already been replace
  -- with some new data and thus, the current and next phase ned to be buffered.
  signal CurrentPhaseEn_S                 : std_logic;
  signal CurrentPhase_SN, CurrentPhase_SP : phaseType;

  -- A register for storing the type of the next phase.
  signal NextPhaseEn_S              : std_logic;
  signal NextPhase_SN, NextPhase_SP : phaseType;

  ---- A register for storing the authentication tag.
  --signal Tag_DN, Tag_DP : std_logic_vector(255 downto 0);

  -- A counter for counting the number of times the eight G functions have been
  -- run through.
  signal G8Cnt_SN, G8Cnt_SP : unsigned(3 downto 0);

  -- A register for storing the value indicating whether there is a valid
  -- authentication tag in the respective register or not.
  signal ValidTag_SN, ValidTag_SP : std_logic;

  
  -- Other signals
  -----------------------------------------------------------------------------

  -- The value of the NORX state after the column step.
  signal NorxStatePostCol_D : matrixArrayType;
  
  -- The actual value of the SlaveTUser_S signal determining the type of the
  -- input data.
  signal SlaveTUser_S : std_logic_vector(7 downto 0);

  -- Signal for indicating that valid input data is available in the input
  -- register.
  signal ValidInp_S : std_logic;

  -- Signal indicating that the NORX architecture is ready to process the next
  -- input data (from the input register).
  signal AbsorbInp_S : std_logic;

  -- The value of the norx state after combining it with the required inputs
  -- and domain separation constants.
  signal NextNorxState_D : matrixArrayType;

  -- The output signal.
  signal DstTData_D : rateArrayType;

  -- Signals from the control input decoder.
  signal CurrentPhase_S : phaseType;
  signal NextPhase_S    : phaseType;
  signal Mode_S         : modeType;

  -- Signals of the init module.
  signal InitInp_D   : std_logic_vector(383 downto 0);
  signal InitState_D : matrixArrayType;

  -- Signals of the ciphertext absorbing module.
  signal PayloadLen_S         : std_logic_vector(6 downto 0);
  signal AbsorbedCiphertext_D : rateArrayType;
  signal Payload_D            : rateArrayType;
  
  -- Inputs and outputs to/from the G functions.
  signal G1_D, G2_D, G3_D, G4_D, G5_D, G6_D, G7_D, G8_D : gFunctionIORecordType;

  -- Signals holding the current and the next values of the bitrate and the
  -- capacity.
  signal CurrRate_D, NextRate_D         : rateArrayType;
  signal CurrCapacity_D, NextCapacity_D : capacityArrayType;

  -- Signal holding the value of the current domain separation constant.
  signal DomainConst_D : std_logic_vector(4 downto 0);

  -- Select signal for selecting the current domain separation constant.
  signal SelDomainConst_S : phaseType;

  -- The input to be used as the next rate.
  signal Inp_D : std_logic_vector(767 downto 0);

  -- Select signal for selecting the next input rate or zero (thereby the rate
  -- from the previous state will be chosen for the next state).
  signal SelInp_S : std_logic;

  -- Signal determining whether the present design is ready to obtain data from
  -- a potential upstream circuit (source).
  signal SrcTReady_S : std_logic;

  -- Signal indicating the the NORX architecture is currently busy.
  signal Busy_S : std_logic;

  -- Select signal for selecting the next NORX state.
  signal SelNextNorxState_S : std_logic;

  -- Select signal for selecting the input depending on the mode the NORX
  -- architecture is running in (i.e., encryption or decryption).
  signal SelMode_S : modeType;


begin  -- architecture Behavioral

  -----------------------------------------------------------------------------
  -- Component instantiations
  -----------------------------------------------------------------------------

  -- The input decoder which solely decodes the integer value provided by the
  -- source via the SlaveTUser_SI signal into "more speaking" signals.
  ctrlInpDecoder_1 : entity work.ctrlInpDecoder
    port map (
      SrcTUser_SI     => SlaveTUser_S,
      CurrentPhase_SO => CurrentPhase_S,
      NextPhase_SO    => NextPhase_S,
      Mode_SO         => Mode_S);

  -- The lower byte of the control input determines the actual value indicating
  -- what type of input data is provided by the source.
  SlaveTUser_S <= SlaveTUser_SP(7 downto 0);

  -- The module which creates the initial state of NORX as well as stores
  -- cipherkey. Thereby, the cipherkey must not always be provided in
  -- combination with the nonce prior to processing data.
  init_1 : entity work.init
    port map (
      Inp_DI       => InitInp_D,
      InitState_DO => InitState_D);

  InitInp_D <= SlaveTData_DP(767 downto 384);

  g1 : entity work.gFunction
    port map (
      AInp_DI  => G1_D.AInp_D,
      BInp_DI  => G1_D.BInp_D,
      CInp_DI  => G1_D.CInp_D,
      DInp_DI  => G1_D.DInp_D,
      AOutp_DO => G1_D.AOutp_D,
      BOutp_DO => G1_D.BOutp_D,
      COutp_DO => G1_D.COutp_D,
      DOutp_DO => G1_D.DOutp_D);

  g2 : entity work.gFunction
    port map (
      AInp_DI  => G2_D.AInp_D,
      BInp_DI  => G2_D.BInp_D,
      CInp_DI  => G2_D.CInp_D,
      DInp_DI  => G2_D.DInp_D,
      AOutp_DO => G2_D.AOutp_D,
      BOutp_DO => G2_D.BOutp_D,
      COutp_DO => G2_D.COutp_D,
      DOutp_DO => G2_D.DOutp_D);

  g3 : entity work.gFunction
    port map (
      AInp_DI  => G3_D.AInp_D,
      BInp_DI  => G3_D.BInp_D,
      CInp_DI  => G3_D.CInp_D,
      DInp_DI  => G3_D.DInp_D,
      AOutp_DO => G3_D.AOutp_D,
      BOutp_DO => G3_D.BOutp_D,
      COutp_DO => G3_D.COutp_D,
      DOutp_DO => G3_D.DOutp_D);

  g4 : entity work.gFunction
    port map (
      AInp_DI  => G4_D.AInp_D,
      BInp_DI  => G4_D.BInp_D,
      CInp_DI  => G4_D.CInp_D,
      DInp_DI  => G4_D.DInp_D,
      AOutp_DO => G4_D.AOutp_D,
      BOutp_DO => G4_D.BOutp_D,
      COutp_DO => G4_D.COutp_D,
      DOutp_DO => G4_D.DOutp_D);

  g5: entity work.gFunction
    port map (
      AInp_DI  => G5_D.AInp_D,
      BInp_DI  => G5_D.BInp_D,
      CInp_DI  => G5_D.CInp_D,
      DInp_DI  => G5_D.DInp_D,
      AOutp_DO => G5_D.AOutp_D,
      BOutp_DO => G5_D.BOutp_D,
      COutp_DO => G5_D.COutp_D,
      DOutp_DO => G5_D.DOutp_D);

  g6 : entity work.gFunction
    port map (
      AInp_DI  => G6_D.AInp_D,
      BInp_DI  => G6_D.BInp_D,
      CInp_DI  => G6_D.CInp_D,
      DInp_DI  => G6_D.DInp_D,
      AOutp_DO => G6_D.AOutp_D,
      BOutp_DO => G6_D.BOutp_D,
      COutp_DO => G6_D.COutp_D,
      DOutp_DO => G6_D.DOutp_D);

  g7 : entity work.gFunction
    port map (
      AInp_DI  => G7_D.AInp_D,
      BInp_DI  => G7_D.BInp_D,
      CInp_DI  => G7_D.CInp_D,
      DInp_DI  => G7_D.DInp_D,
      AOutp_DO => G7_D.AOutp_D,
      BOutp_DO => G7_D.BOutp_D,
      COutp_DO => G7_D.COutp_D,
      DOutp_DO => G7_D.DOutp_D);

  g8 : entity work.gFunction
    port map (
      AInp_DI  => G8_D.AInp_D,
      BInp_DI  => G8_D.BInp_D,
      CInp_DI  => G8_D.CInp_D,
      DInp_DI  => G8_D.DInp_D,
      AOutp_DO => G8_D.AOutp_D,
      BOutp_DO => G8_D.BOutp_D,
      COutp_DO => G8_D.COutp_D,
      DOutp_DO => G8_D.DOutp_D);


  absorbCiphertext_1 : entity work.absorbCiphertext
    port map (
      CurrRate_DI    => CurrRate_D,
      Payload_DI     => Payload_D,
      PayloadLen_SI  => PayloadLen_S,
      AbsorbedCiphertext_DO => AbsorbedCiphertext_D);

  Payload_D <= std_logic_vector_2_rate_array(SlaveTData_DP);
  
  -- The first seven bits of the upper byte of the TUser_SI input determine the
  -- legnth of the provided payload (in bytes).
  PayloadLen_S <= SlaveTUser_SP(14 downto 8);

  
  -----------------------------------------------------------------------------
  -- G functions
  -----------------------------------------------------------------------------

  -- Inputs to the first G function.
  G1_D.AInp_D <= NextNorxState_D(0);
  G1_D.BInp_D <= NextNorxState_D(4);
  G1_D.CInp_D <= NextNorxState_D(8);
  G1_D.DInp_D <= NextNorxState_D(12);

  -- Inputs to the second G function.
  G2_D.AInp_D <= NextNorxState_D(1);
  G2_D.BInp_D <= NextNorxState_D(5);
  G2_D.CInp_D <= NextNorxState_D(9);
  G2_D.DInp_D <= NextNorxState_D(13);

  -- Inputs to the third G function.
  G3_D.AInp_D <= NextNorxState_D(2);
  G3_D.BInp_D <= NextNorxState_D(6);
  G3_D.CInp_D <= NextNorxState_D(10);
  G3_D.DInp_D <= NextNorxState_D(14);

  -- Inputs to the third G function.
  G4_D.AInp_D <= NextNorxState_D(3);
  G4_D.BInp_D <= NextNorxState_D(7);
  G4_D.CInp_D <= NextNorxState_D(11);
  G4_D.DInp_D <= NextNorxState_D(15);

  -- The state after the first F iteration.
  NorxStatePostCol_D(0) <= G1_D.AOutp_D;
  NorxStatePostCol_D(1) <= G2_D.AOutp_D;
  NorxStatePostCol_D(2) <= G3_D.AOutp_D;
  NorxStatePostCol_D(3) <= G4_D.AOutp_D;
  NorxStatePostCol_D(4) <= G1_D.BOutp_D;
  NorxStatePostCol_D(5) <= G2_D.BOutp_D;
  NorxStatePostCol_D(6) <= G3_D.BOutp_D;
  NorxStatePostCol_D(7) <= G4_D.BOutp_D;
  NorxStatePostCol_D(8) <= G1_D.COutp_D;
  NorxStatePostCol_D(9) <= G2_D.COutp_D;
  NorxStatePostCol_D(10) <= G3_D.COutp_D;
  NorxStatePostCol_D(11) <= G4_D.COutp_D;
  NorxStatePostCol_D(12) <= G1_D.DOutp_D;
  NorxStatePostCol_D(13) <= G2_D.DOutp_D;
  NorxStatePostCol_D(14) <= G3_D.DOutp_D;
  NorxStatePostCol_D(15) <= G4_D.DOutp_D;


  -- Inputs to the fifth G function.
  G5_D.AInp_D <= NorxStatePostCol_D(0);
  G5_D.BInp_D <= NorxStatePostCol_D(5);
  G5_D.CInp_D <= NorxStatePostCol_D(10);
  G5_D.DInp_D <= NorxStatePostCol_D(15);

  -- Inputs to the sixth G function.
  G6_D.AInp_D <= NorxStatePostCol_D(1);
  G6_D.BInp_D <= NorxStatePostCol_D(6);
  G6_D.CInp_D <= NorxStatePostCol_D(11);
  G6_D.DInp_D <= NorxStatePostCol_D(12);

  -- Inputs to the seventh G function.
  G7_D.AInp_D <= NorxStatePostCol_D(2);
  G7_D.BInp_D <= NorxStatePostCol_D(7);
  G7_D.CInp_D <= NorxStatePostCol_D(8);
  G7_D.DInp_D <= NorxStatePostCol_D(13);

  -- Inputs to the eighth G function.
  G8_D.AInp_D <= NorxStatePostCol_D(3);
  G8_D.BInp_D <= NorxStatePostCol_D(4);
  G8_D.CInp_D <= NorxStatePostCol_D(9);
  G8_D.DInp_D <= NorxStatePostCol_D(14);

  
  -----------------------------------------------------------------------------
  -- Datapath for computing the next value of the rate.
  -----------------------------------------------------------------------------

  -- The value of the current rate is directly coming from the NORX
  -- state-holding register.
  CurrRate_D(0)  <= NorxState_DP(0);
  CurrRate_D(1)  <= NorxState_DP(1);
  CurrRate_D(2)  <= NorxState_DP(2);
  CurrRate_D(3)  <= NorxState_DP(3);
  CurrRate_D(4)  <= NorxState_DP(4);
  CurrRate_D(5)  <= NorxState_DP(5);
  CurrRate_D(6)  <= NorxState_DP(6);
  CurrRate_D(7)  <= NorxState_DP(7);
  CurrRate_D(8)  <= NorxState_DP(8);
  CurrRate_D(9)  <= NorxState_DP(9);
  CurrRate_D(10) <= NorxState_DP(10);
  CurrRate_D(11) <= NorxState_DP(11);

  -- The MUX for selecting the incoming data (or zero).
  Inp_D <= SlaveTData_DP when SelInp_S = '1' else (others => '0');

  -- The value of the output for the destination is computed by XORing the
  -- incoming data with the current value of the rate.
  DstTData_D <= CurrRate_D xor Inp_D;

  -- The value for the next rate is either directly the incoming data (in case
  -- of decryption) or the outgoing data (in case of encryption).
  NextRate_D <=
    AbsorbedCiphertext_D when SelMode_S = DECRYPTION else
    DstTData_D;


  -----------------------------------------------------------------------------
  -- Datapath for computing the next value of the capacity.
  -----------------------------------------------------------------------------

  -- The valur of the current capacity is directly coming from the NORX
  -- state-holding register.
  CurrCapacity_D(0) <= NorxState_DP(12);
  CurrCapacity_D(1) <= NorxState_DP(13);
  CurrCapacity_D(2) <= NorxState_DP(14);
  CurrCapacity_D(3) <= NorxState_DP(15);

  -- The "MUX"" determining the value of the domain separation constant.
  DomainConst_D <=
    std_logic_vector(to_unsigned(1, 5)) when SelDomainConst_S = HEADER else
    std_logic_vector(to_unsigned(2, 5)) when SelDomainConst_S = PLAINTEXT or SelDomainConst_S = CIPHERTEXT or SelDomainConst_S = PAYLOAD else
    std_logic_vector(to_unsigned(4, 5)) when SelDomainConst_S = TRAILER else
    std_logic_vector(to_unsigned(8, 5)) when SelDomainConst_S = TAG else
    std_logic_vector(to_unsigned(0, 5));

  -- The value of the next capacity is determined based on the value of the
  -- domain separation constant, which only affects the last word (s_15) of the
  -- NORX state (and even of that only five bits).
  NextCapacity_D(0) <= CurrCapacity_D(0);
  NextCapacity_D(1) <= CurrCapacity_D(1);
  NextCapacity_D(2) <= CurrCapacity_D(2);
  NextCapacity_D(3) <= xor_domain_constant(CurrCapacity_D(3), DomainConst_D);


  -----------------------------------------------------------------------------
  -- Datapath for computing the value of the next NORX state, which should be
  -- fed into the G functions.
  -----------------------------------------------------------------------------
  NextNorxState_D <=
    InitState_D when SelNextNorxState_S = '1' else
    (NextRate_D(0), NextRate_D(1), NextRate_D(2), NextRate_D(3),
     NextRate_D(4), NextRate_D(5), NextRate_D(6), NextRate_D(7),
     NextRate_D(8), NextRate_D(9), NextRate_D(10), NextRate_D(11),
     NextCapacity_D(0), NextCapacity_D(1), NextCapacity_D(2), NextCapacity_D(3));


  -----------------------------------------------------------------------------
  -- Next-state logic.
  -----------------------------------------------------------------------------

  -- Next states of the control and data inputs.
  SlaveTUser_SN <= SlaveTUser_SI;
  SlaveTData_DN <= SlaveTData_DI;

  -- Next states of the current and next NORX phase.
  CurrentPhase_SN <= CurrentPhase_S;
  NextPhase_SN    <= NextPhase_S;

  -- Next state of the NORX state.
  NorxState_DN(0)  <= G5_D.AOutp_D;
  NorxState_DN(1)  <= G6_D.AOutp_D;
  NorxState_DN(2)  <= G7_D.AOutp_D;
  NorxState_DN(3)  <= G8_D.AOutp_D;
  NorxState_DN(4)  <= G8_D.BOutp_D;
  NorxState_DN(5)  <= G5_D.BOutp_D;
  NorxState_DN(6)  <= G6_D.BOutp_D;
  NorxState_DN(7)  <= G7_D.BOutp_D;
  NorxState_DN(8)  <= G7_D.COutp_D;
  NorxState_DN(9)  <= G8_D.COutp_D;
  NorxState_DN(10) <= G5_D.COutp_D;
  NorxState_DN(11) <= G6_D.COutp_D;
  NorxState_DN(12) <= G6_D.DOutp_D;
  NorxState_DN(13) <= G7_D.DOutp_D;
  NorxState_DN(14) <= G8_D.DOutp_D;
  NorxState_DN(15) <= G5_D.DOutp_D;


  -----------------------------------------------------------------------------
  -- Output assignments
  -----------------------------------------------------------------------------
  MasterTData_DO <= rate_array_2_std_logic_vector(DstTData_D);


  -----------------------------------------------------------------------------
  -- FSM for controlling the input handshaking
  -----------------------------------------------------------------------------
  pComb_InputFSM : process (AbsorbInp_S, InputFsmState_SP, SlaveTValid_SI) is
  begin  -- process pComb_InputFSM

    -- Defaults
    InputFsmState_SN <= InputFsmState_SP;

    SlaveTUserEn_S <= '0';
    SlaveTDataEn_S <= '0';
    SlaveTReady_SO <= '0';
    ValidInp_S     <= '0';

    case InputFsmState_SP is
      -------------------------------------------------------------------------
      -- RESET: The RESET state is only needed in order not to set the
      -- SlaveTReady_SO signal during the asynchronous reset to zero and
      -- therefore, we can change into the next state as soon as the reset is
      -- released.
      -------------------------------------------------------------------------
      when RESET => InputFsmState_SN <= WAIT4INPUT;

      -------------------------------------------------------------------------
      -- WAIT4INPUT: Wait for a new valid input to appear at the input.
      -------------------------------------------------------------------------
      when WAIT4INPUT =>
        SlaveTReady_SO <= '1';
        if SlaveTValid_SI = '1' then
          SlaveTUserEn_S   <= '1';
          SlaveTDataEn_S   <= '1';
          InputFsmState_SN <= WAIT4READY;
        end if;

      -------------------------------------------------------------------------
      -- WAIT4READY: Wait for the NORX architecture to be ready to process in
      -- the data in the input register.
      -------------------------------------------------------------------------
      when WAIT4READY =>
        -- Indicate the NORX architecture that there is valid data in the input
        -- register.
        ValidInp_S <= '1';

        if AbsorbInp_S = '1' then
          -- In case the NORX architecture is ready to process the data in the
          -- input register, we can tell the source that we are ready to obtain
          -- new input data.
          SlaveTReady_SO <= '1';

          if SlaveTValid_SI = '1' then
            -- Since the NORX architecture is ready to process the data in the
            -- input register and we have new data coming from the source, we
            -- are ready to write them into the input registers.
            SlaveTUserEn_S <= '1';
            SlaveTDataEn_S <= '1';
          else
            -- Although the NORX architecture is ready to process t he data in
            -- the input register, there is no new data coming from the source.
            -- Hence, we go  back into the WAIT4INPUT state.
            InputFsmState_SN <= WAIT4INPUT;
          end if;
        end if;
      -------------------------------------------------------------------------
      when others => null;
    end case;

  end process pComb_InputFSM;


  -----------------------------------------------------------------------------
  -- FSM for controlling the actual NORX computation.
  -----------------------------------------------------------------------------
  pComb_MainFSM : process (CurrentPhase_S, CurrentPhase_SP, G8Cnt_SP,
                           MainFsmState_SP, MasterTReady_SI, Mode_S,
                           NextPhase_S, NextPhase_SP, ValidInp_S, ValidTag_SP) is
  begin  -- process pComb_MainFSM

    -- Defaults
    MainFsmState_SN <= MainFsmState_SP;
    G8Cnt_SN        <= G8Cnt_SP;
    ValidTag_SN     <= ValidTag_SP;

    CurrentPhaseEn_S <= '0';
    NextPhaseEn_S    <= '0';
    NorxStateEn_S    <= '0';

    AbsorbInp_S        <= '0';
    SelNextNorxState_S <= '0';
    SelInp_S           <= '0';
    SelMode_S          <= ENCRYPTION;
    SelDomainConst_S   <= UNKNOWN;
    MasterTValid_SO    <= '0';
    MasterTUser_SO     <= DSTTUSER_UNKNOWN;


    case MainFsmState_SP is
      -------------------------------------------------------------------------
      -- RESET: The RESET state is only needed in order not to set the
      -- AbsorbInp_S signal during the asynchronous reset to zero and therefore,
      -- we can change into the next state as soon as the reset is released.
      -------------------------------------------------------------------------
      when RESET => MainFsmState_SN <= IDLE;

      -------------------------------------------------------------------------
      -- IDLE: In the IDLE state we wait until there is some valid data in the
      -- input registers in order to start the NORX computation.
      -------------------------------------------------------------------------
      when IDLE =>
        -- In case there was a valid authentication tag, but the destination is
        -- ready to obtain it, we need to reset the register indicating a valid
        -- authentication tag.
        if ValidTag_SP = '1' then
          MasterTValid_SO <= '1';
          MasterTUser_SO  <= DSTTUSER_TAG;
          if MasterTReady_SI = '1' then
            ValidTag_SN <= '0';
          end if;
        end if;

        -- As long as there is a valid authentication tag in the state
        -- register and the destination is not ready to obtain that data, we
        -- cannot process any further input data.
        if ValidTag_SP = '0' or (ValidTag_SP = '1' and MasterTReady_SI = '1') then

          -- Once we are sure that there is no authentication tag in the state,
          -- we need to wait until there is new valid data in the input
          -- register to be processed through the eight G permutations.
          if ValidInp_S = '1' then
            -- Now that we are sure that there is no data in the state which
            -- must be obtained from the destination and we do not need to
            -- compute the authentication tag, we can go on with processing
            -- new input data (if available).

            -- If the data in the input register is some payload data (i.e.,
            -- either plaintext or ciphertext), we need to make sure that the
            -- destination is ready to obtain the corresponding output.
            -- Otherwise, we cannot process it.
            case CurrentPhase_S is
              -----------------------------------------------------------------
              -- PLAINTEXT | CIPHERTEXT: When there is some payload in the
              -- input register, we need to make sure that the destination can
              -- obtain it before we actually absorb it into the the state.
              -----------------------------------------------------------------
              when PLAINTEXT | CIPHERTEXT =>
                -- As we have a payload in the input register, we need to tell
                -- the destination that we have some valid output.
                MasterTValid_SO <= '1';
                MasterTUser_SO  <= DSTTUSER_PAYLOAD;

                -- Since we have a payload in the input register, we need to
                -- make sure that the destination is ready to obtain the
                -- corresponding output. Otherwise, we cannot process the input
                -- into the state.
                if MasterTReady_SI = '1' then
                  AbsorbInp_S <= '1';

                  -- Since we need the type of the current and the next phase
                  -- later on, we need to buffer it. Thereby, the input
                  -- registers can take new input data as soon as new data is
                  -- available from the source.
                  CurrentPhaseEn_S <= '1';
                  NextPhaseEn_S    <= '1';

                  -- Select the datapath accordingly to absorb the incoming
                  -- payload data.
                  SelInp_S         <= '1';
                  SelMode_S        <= Mode_S;
                  SelDomainConst_S <= NextPhase_S;
                  NorxStateEn_S    <= '1';
                  G8Cnt_SN         <= to_unsigned(3, 4);
                  MainFsmState_SN  <= PROCESS_STATE;

                end if;

              -----------------------------------------------------------------
              -- CIPHERKEY_NONCE: If there the cipherkey and the nonce in the
              -- input register, we need to make sure that it is processed
              -- through the state for two full F^R functions and not just one
              -- (as it is the case for the other input).
              -----------------------------------------------------------------
              when CIPHERKEY_NONCE =>
                AbsorbInp_S <= '1';

                -- Since we need the type of the current and the next phase
                -- later on, we need to buffer it. Thereby, the input registers
                -- can take new input data as soon as new data is available from
                -- the source.
                CurrentPhaseEn_S <= '1';
                NextPhaseEn_S    <= '1';

                -- Select the datapath accordingly to absorb the incoming
                -- payload data.
                SelNextNorxState_S <= '1';
                NorxStateEn_S      <= '1';
                G8Cnt_SN           <= to_unsigned(7, 4);
                MainFsmState_SN    <= PROCESS_STATE;

              when HEADER | TRAILER =>
                AbsorbInp_S <= '1';

                -- Since we need the type of the current and the next phase
                -- later on, we need to buffer it. Thereby, the input registers
                -- can take new input data as soon as new data is available from
                -- the source.
                CurrentPhaseEn_S <= '1';
                NextPhaseEn_S    <= '1';

                -- Select the datapath accordingly to absorb the incoming
                -- payload data.
                SelInp_S         <= '1';
                SelDomainConst_S <= NextPhase_S;
                NorxStateEn_S    <= '1';
                G8Cnt_SN         <= to_unsigned(3, 4);
                MainFsmState_SN  <= PROCESS_STATE;

              when others => null;
            end case;
          end if;
        end if;


      -------------------------------------------------------------------------
      -- PROCESS_STATE: Processes the state through the eight G functions.
      -------------------------------------------------------------------------
      when PROCESS_STATE =>
        G8Cnt_SN      <= G8Cnt_SP-1;
        NorxStateEn_S <= '1';

        -- If we are currently processing a cipherkey and a nonce, we need to
        -- make sure that we XOR the domain constant after the first F^R
        -- operation accordingly to the capacity.
        if CurrentPhase_SP = CIPHERKEY_NONCE and G8Cnt_SP = 4 then
          SelDomainConst_S <= NextPhase_SP;
        end if;

        if NextPhase_SP = TAG then
          if G8Cnt_SP = 0 then
            -- If the previous phase is done and during the next phase, the
            -- authentication tag should be computed, we need to process the
            -- state through the eight G permutations for another full
            -- F^R operation.
            G8Cnt_SN        <= to_unsigned(3, 4);
            MainFsmState_SN <= COMPUTE_TAG;
          end if;
        else
          -- If we are done with the previous phase and the authentication tag
          -- should not be computed in the next phase, we can go back into the
          -- IDLE state in order to absorb any further incoming data.
          if G8Cnt_SP = 1 then
            MainFsmState_SN <= IDLE;
          end if;
        end if;


      -------------------------------------------------------------------------
      -- COMPUTE_TAG: Performs the final F^R iteration, required to compute the
      -- authentication tag.
      -------------------------------------------------------------------------
      when COMPUTE_TAG =>
        G8Cnt_SN      <= G8Cnt_SP-1;
        NorxStateEn_S <= '1';

        if G8Cnt_SP = 1 then
          ValidTag_SN     <= '1';
          MainFsmState_SN <= IDLE;
        end if;


      -------------------------------------------------------------------------
      when others => null;
    end case;
  end process pComb_MainFSM;



-----------------------------------------------------------------------------
-- Memories
-----------------------------------------------------------------------------
  pSequ_FFs : process (Clk_CI, Reset_RBI) is
  begin  -- process pSequ_FFs
    if Reset_RBI = '0' then             -- asynchronous reset (active low)
      InputFsmState_SP <= RESET;
      MainFsmState_SP  <= RESET;
      SlaveTUser_SP    <= (others => '0');
      SlaveTData_DP    <= (others => '0');
      NorxState_DP     <= (others => (others => '0'));
      G8Cnt_SP         <= to_unsigned(0, 4);
      NextPhase_SP     <= UNKNOWN;
      ValidTag_SP      <= '0';
    elsif Clk_CI'event and Clk_CI = '1' then  -- rising clock edge

      -- Registers without enables.
      InputFsmState_SP <= InputFsmState_SN;
      MainFsmState_SP  <= MainFsmState_SN;
      G8Cnt_SP         <= G8Cnt_SN;
      ValidTag_SP      <= ValidTag_SN;

      -- Registers with enables.
      if SlaveTUserEn_S = '1' then SlaveTUser_SP     <= SlaveTUser_SN; end if;
      if SlaveTDataEn_S = '1' then SlaveTData_DP     <= SlaveTData_DN; end if;
      if NorxStateEn_S = '1' then NorxState_DP       <= NorxState_DN; end if;
      if CurrentPhaseEn_S = '1' then CurrentPhase_SP <= CurrentPhase_SN; end if;
      if NextPhaseEn_S = '1' then NextPhase_SP       <= NextPhase_SN; end if;
    end if;
  end process pSequ_FFs;
end architecture Behavioral;
