module DUsd.CborTyped
  ( simpleNft
  , configAddressValidator
  , paramAddressValidator
  , priceOracleValidator
  ) where

import Contract.Prelude

import CBOR as CBOR
import Contract.Address (PubKeyHash)
import Contract.Log (logError')
import Contract.Monad (Contract, liftContractM)
import Contract.PlutusData (PlutusData, toData)
import Contract.Prim.ByteArray (hexToByteArray)
import Contract.Scripts (MintingPolicy(..), PlutusScript, Validator(..), applyArgs)
import Contract.Time (POSIXTime)
import Contract.Transaction (TransactionInput, plutusV2Script)
import Contract.Value (CurrencySymbol)
import Effect.Exception (throw)

{- This module should be the only place where CBOR is imported
- all of its exports should handle all of the validator's parameters
- this way there is only one module that needs to be checked
- for type errors between on and off chain code
-}

-- | validator for the price oracle address
priceOracleValidator :: POSIXTime -> PubKeyHash -> CurrencySymbol -> Contract () Validator
priceOracleValidator interval pkh cs =
  decodeCbor CBOR.trivial [ toData interval, toData pkh , toData cs ]
    <#> Validator

-- | The address validator for the config utxo
-- patametized by the admin key and the currency symbol of the config NFT
configAddressValidator :: PubKeyHash -> CurrencySymbol -> Contract () Validator
configAddressValidator pkh cs =
  decodeCbor CBOR.configWithUpdates [ toData pkh, toData cs ]
    <#> Validator

-- | Param address validator supports updates with some basic checks
paramAddressValidator :: PubKeyHash -> CurrencySymbol -> Contract () Validator
paramAddressValidator pkh cs =
  decodeCbor CBOR.paramAdr [ toData pkh, toData cs ]
    <#> Validator

-- | Simple NFT minting policy parametized by a transaction input
simpleNft :: TransactionInput -> Contract () MintingPolicy
simpleNft ref = do
  decodeCbor CBOR.nft [ toData ref ]
    <#> PlutusMintingPolicy

-- This helper should not be exported
decodeCbor :: String -> Array PlutusData -> Contract () PlutusScript
decodeCbor cborHex args = do
  rawScript <- liftContractM "failed to decode cbor"
    $ plutusV2Script
    <$> hexToByteArray cborHex
  applyArgs rawScript args >>= case _ of
    Left err -> do
      logError' $ "error in apply args:" <> show err
      liftEffect $ throw $ show err
    Right newScript -> pure newScript
