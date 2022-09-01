module Test.Main
  ( main
  ) where

import Prelude

import Data.Maybe (Maybe(Just, Nothing))
import Effect (Effect)
import Effect.Aff (launchAff_)
import Effect.Exception (throw)
import Faucet (topupKeyWallet)
import Node.Process (lookupEnv)
import Test.HelloWorld.Api as Test.HelloWorld.Api
import Test.HelloWorld.Encoding as Encoding
import Test.HelloWorld.EnvRunner (Mode(..), getEnvRunner)
import Test.Spec (describe)
import Test.Spec.Reporter.Console (consoleReporter)
import Test.Spec.Runner (runSpec', defaultConfig)

main :: Effect Unit
main = do
  mode <- lookupEnv "MODE" >>= case _ of
    Just "local" -> pure Local
    Just "testnet" -> do
      launchAff_ $ topupKeyWallet "addr_test1qrwdtldyjseyn3k978de87renmp2kt3vcajk65nk543tw865kp7y0evgnnne7ukzhqsmdmyefhpevpepl9p7xpe8zqpsag6004"
      pure Testnet
    Just e -> throw $ "expected local or testnet got: " <> e
    Nothing -> throw "expected MODE to be set"
  launchAff_ do
    envRunner <- getEnvRunner mode
    runSpec' defaultConfig { timeout = Nothing } [ consoleReporter ] $
      case mode of
        Local -> do
          describe "pure tests" do
            Encoding.spec
            Test.HelloWorld.Api.spec envRunner
            Test.HelloWorld.Api.localOnlySpec
        Testnet -> do
          describe "pure tests" do
            Encoding.spec
          describe "impure tests" do
            Test.HelloWorld.Api.spec envRunner
