-------------------------------------------------------------------------------
--! @file       ctrlInpDecoder.vhd
--! @brief      Decoder for the control input
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
--! @brief Decoder for the control input coming from the source.
-------------------------------------------------------------------------------
entity ctrlInpDecoder is

  port (
    --! @brief The decimal value received from the source, determining
    --!   the type of data being sent.
    --!
    --! This decimal value needs to be decoded.
    SrcTUser_SI : in std_logic_vector(7 downto 0);

    -- The decoded signals.
    ---------------------------------------------------------------------------

    ---- Indicates that a new cipherkey and a new nonce are applied.
    --NewCipherkeyNonce_SO : out std_logic;

    --! @brief Indicates the type of the current phase.
    CurrentPhase_SO : out phaseType;

    --! @brief Indicates the type of the next phase.
    NextPhase_SO : out phaseType;

    --! @brief Indicates the current mode (encryption/decryption) the NORX
    --!   architecture is running in.
    Mode_SO : out modeType
    );

end entity ctrlInpDecoder;

architecture Behavioral of ctrlInpDecoder is

  -----------------------------------------------------------------------------
  -- Signals
  -----------------------------------------------------------------------------
  signal TUserSrc_S : unsigned(7 downto 0);


begin  -- architecture Behavioral

  -- Convert the std_logic_input to an unsigned.
  TUserSrc_S <= unsigned(SrcTUser_SI);

  -----------------------------------------------------------------------------
  -- Output assignments.
  -----------------------------------------------------------------------------

  CurrentPhase_SO <=
    CIPHERKEY_NONCE when (TUserSrc_S = 1 or TUserSrc_S = 2) else
    HEADER          when (TUserSrc_S = 3 or TUserSrc_S = 4 or TUserSrc_S = 5) else
    PLAINTEXT       when (TUserSrc_S = 6 or TUserSrc_S = 7 or TUserSrc_S = 8) else
    CIPHERTEXT      when (TUserSrc_S = 9 or TUserSrc_S = 10 or TUserSrc_S = 11) else
    TRAILER         when (TUserSrc_S = 12 or TUserSrc_S = 13) else
    UNKNOWN;

  NextPhase_SO <=
    HEADER  when (TUserSrc_S = 1 or TUserSrc_S = 3) else
    PAYLOAD when (TUserSrc_S = 2 or TUserSrc_S = 4 or TUserSrc_S = 6 or TUserSrc_S = 9) else
    TRAILER when (TUserSrc_S = 7 or TUserSrc_S = 10 or TUserSrc_S = 12) else
    TAG     when (TUserSrc_S = 5 or TUserSrc_S = 8 or TUserSrc_S = 11 or TUserSrc_S = 13) else
    UNKNOWN;

  Mode_SO <=
    -- Note that we only need a distinction between encryption and decryption
    -- when receiving payload data. Therefore, we only set the Mode_S signal
    -- accordingly when we receive ciphertext data.
    DECRYPTION when (TUserSrc_S = 9 or TUserSrc_S = 10 or TUserSrc_S = 11) else
    ENCRYPTION;
            
end architecture Behavioral;
