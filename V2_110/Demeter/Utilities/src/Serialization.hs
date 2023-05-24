{-# LANGUAGE LambdaCase #-}

module Serialization
  ( validatorToScript
  , policyToScript
  , codeToScript
  , writeCodeToFile
  , writeValidatorToFile
  , writePolicyToFile
  , dataToJSON
  , printDataToJSON
  , writeDataToFile
  , currencySymbol
  ) where

import qualified Cardano.Api                 as Api
import           Cardano.Api           (Error (displayError), PlutusScript,
                                        PlutusScriptV2, prettyPrintJSON,
                                        writeFileJSON, writeFileTextEnvelope)
import           Cardano.Api.Shelley   (PlutusScript (..), fromPlutusData,
                                        scriptDataToJsonDetailedSchema)
import           Codec.Serialise       (Serialise, serialise)
import           Data.Aeson            (Value)
import qualified Data.ByteString.Char8 as BS8
import qualified Data.ByteString.Lazy  as BSL
import qualified Data.ByteString.Short as BSS
import           Plutus.V1.Ledger.Api  (ToData)
import qualified Plutus.V2.Ledger.Api  as PlutusV2
import           Plutus.V2.Ledger.Api  (CurrencySymbol (CurrencySymbol)
                                       , MintingPolicy
                                       , MintingPolicyHash (MintingPolicyHash)
                                       , POSIXTime
                                       , Validator
                                       , ValidatorHash (ValidatorHash)
                                       , ScriptContext
                                       , UnsafeFromData
                                       , unsafeFromBuiltinData)
import           PlutusTx              (CompiledCode)
import           PlutusTx.Builtins.Internal  (BuiltinByteString (..))
import           Text.Printf           (printf)

currencySymbol :: MintingPolicy -> CurrencySymbol
currencySymbol = PlutusV2.CurrencySymbol . BuiltinByteString . Api.serialiseToRawBytes . hashScript . policyToScript

hashScript :: Api.PlutusScript Api.PlutusScriptV2 -> Api.ScriptHash
hashScript = Api.hashScript . Api.PlutusScript Api.PlutusScriptV2

serializableToScript :: Serialise a => a -> PlutusScript PlutusScriptV2
serializableToScript = PlutusScriptSerialised . BSS.toShort . BSL.toStrict . serialise

-- Serialize compiled code
codeToScript :: CompiledCode a -> PlutusScript PlutusScriptV2
codeToScript = serializableToScript . PlutusV2.fromCompiledCode

-- Serialize validator
validatorToScript :: PlutusV2.Validator -> PlutusScript PlutusScriptV2
validatorToScript = serializableToScript

-- Serialize minting policy
policyToScript :: PlutusV2.MintingPolicy -> PlutusScript PlutusScriptV2
policyToScript = serializableToScript

-- Create file with Plutus script
writeScriptToFile :: FilePath -> PlutusScript PlutusScriptV2 -> IO ()
writeScriptToFile filePath script =
  writeFileTextEnvelope filePath Nothing script >>= \case
    Left err -> print $ displayError err
    Right () -> putStrLn $ "Serialized script to: " ++ filePath

-- Create file with compiled code
writeCodeToFile :: FilePath -> CompiledCode a -> IO ()
writeCodeToFile filePath = writeScriptToFile filePath . codeToScript

-- Create file with compiled Plutus validator
writeValidatorToFile :: FilePath -> PlutusV2.Validator -> IO ()
writeValidatorToFile filePath = writeScriptToFile filePath . validatorToScript

-- Create file with compiled Plutus minting policy
writePolicyToFile :: FilePath -> PlutusV2.MintingPolicy -> IO ()
writePolicyToFile filePath = writeScriptToFile filePath . policyToScript


-- Write data to file in Cardano API readable format (DATA)
dataToJSON :: ToData a => a -> Value
dataToJSON = scriptDataToJsonDetailedSchema . fromPlutusData . PlutusV2.toData

printDataToJSON :: ToData a => a -> IO ()
printDataToJSON = putStrLn . BS8.unpack . prettyPrintJSON . dataToJSON

writeDataToFile :: ToData a => FilePath -> a -> IO ()
writeDataToFile filePath x = do
  let v = dataToJSON x
  writeFileJSON filePath v >>= \case
   Left err -> print $ displayError err
   Right () -> printf "Wrote data to: %s\n%s\n" filePath $ BS8.unpack $ prettyPrintJSON v