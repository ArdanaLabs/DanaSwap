module Main (main) where

import Hello
import HelloDiscovery

import Control.Monad (unless)
import System.Directory (doesDirectoryExist)
import System.Environment (getArgs)
import System.Exit (die)
import Utils (Cbor (..), toPureScript)

{- | Main takes a directory as a comand line argument
  and creates a file CBOR.purs in that directory
  which will provide variables as configured in
  the cbors constant
-}
main :: IO ()
main = getArgs >>= \case
  [out] -> do
    exists <- doesDirectoryExist out
    unless exists $ die $ "directory: " <> out <> " does not exist"
    writeFile (out ++ "/CBOR.purs")
      . ( "--this file was automatically generated by the onchain code\n"
            <>
        )
      =<< toPureScript helloConfig cbors
  _ -> die "usage: cabal run hello-world <file_path>"

cbors :: [Cbor]
cbors =
  [ Cbor "paramHello" paramHelloCbor
  , Cbor "hello" $ const $ pure helloWorldCbor
  , Cbor "trivial" trivialCbor
  , Cbor "trivialFail" trivialFailCbor
  , Cbor "trivialSerialise" trivialSerialise
  , Cbor "nft" nftCbor
  , Cbor "configScript" configScriptCbor
  , Cbor "vault" vaultScriptCbor
  , Cbor "vaultAuthMp" authTokenCbor
  ]
