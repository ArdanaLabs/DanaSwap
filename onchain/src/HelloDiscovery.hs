module HelloDiscovery (
  configScriptCbor,
  nftCbor,
  authTokenCbor,
  vaultScriptCbor,
) where

import Plutarch.Prelude

import Plutarch.Api.V2
  (PValidator
  ,PTxInInfo
  ,PScriptPurpose(PSpending,PMinting)
  ,PMintingPolicy
  ,PTxOutRef
  ,PAddress
  ,PTxId
  ,PPubKeyHash
  ,PDatum(PDatum)
  ,mkValidator
  )

import Plutarch.Api.V1.AssocMap qualified as AssocMap
import Plutarch.Api.V1.Value qualified as Value
import Plutarch.Api.V1.AssocMap (plookup)
import Plutarch.Api.V1.Value (pforgetPositive)
import Plutarch.Api.V1
  (PTokenName (PTokenName)
  ,PValue (PValue)
  ,PCurrencySymbol
  ,PCredential(PScriptCredential)
  )

import Data.Default (Default (def))
import Plutarch.DataRepr (PDataFields)
import Plutarch.Extensions.Api (passert, passert_,pgetContinuingDatum,pfindOwnInput)
import Plutarch.Extensions.Data (parseData)
import Plutarch.Extensions.List (unsingleton)
import Plutarch.Extra.TermCont
import Utils (closedTermToHexString, validatorToHexString)
import Plutarch.Builtin (pforgetData)

configScriptCbor :: String
configScriptCbor = validatorToHexString $ mkValidator def configScript

nftCbor :: Maybe String
nftCbor = closedTermToHexString standardNFT

authTokenCbor :: Maybe String
authTokenCbor = closedTermToHexString authTokenMP

vaultScriptCbor :: Maybe String
vaultScriptCbor = closedTermToHexString vaultAdrValidator

-- | The config validator
-- the config validator
-- th tx being spent must be read only
-- TODO does a read only spend even invoke a validator?
-- if not we can just do const False or something
configScript :: ClosedTerm PValidator
configScript = phoistAcyclic $
  plam $ \_datum _redemer sc -> unTermCont $ do
    PSpending outRef' <- pmatchC (pfield @"purpose" # sc)
    let (outRef :: Term _ PTxOutRef) =
          pfield @"_0" # outRef'
        (refrenceInputOutRefs :: Term _ (PBuiltinList PTxOutRef)) =
          pmap # pfield @"outRef"
            #$ pfield @"referenceInputs"
            #$ pfield @"txInfo" # sc
    passert "wasn't a refrence input" $ pelem # outRef # refrenceInputOutRefs

-- | The standard NFT minting policy
-- parametized by a txid
-- to mint:
-- the txid must be spent as an input
standardNFT :: ClosedTerm (PData :--> PMintingPolicy)
standardNFT = phoistAcyclic $
  plam $ \outRefData _ sc -> unTermCont $ do
    outRef :: Term _ PTxOutRef <- parseData outRefData
    let (inputs :: Term _ (PBuiltinList PTxOutRef)) =
          pmap # pfield @"outRef"
            #$ pfield @"inputs"
            #$ pfield @"txInfo" # sc
    passert "didn't spend out ref" $ pelem # outRef # inputs

-- | The authorisation+discovery token minting policy
-- parametized by the vault address
-- to mint:
-- redeemer must be of the form AuthRedeemer tokenName txid
-- tn must be the hash of the txid
-- the txid must be spent in the transaction
-- the txid and tn as its hash must be included as a datum in the lookups
-- the output at the vault address must be unique
-- its value must include the nft
-- its datum must parse and the counter must be 0
authTokenMP :: ClosedTerm (PData :--> PMintingPolicy)
authTokenMP = phoistAcyclic $
  plam $ \vaultAdrData redeemerData sc -> unTermCont $ do
    -- misc lookups
    vaultAdr :: Term _ PAddress <- parseData vaultAdrData
    PMinting cs' <- pmatchC (pfield @"purpose" # sc)
    cs :: Term _ PCurrencySymbol  <- pletC $ pfield @"_0" # cs'
    info <- pletC $ pfield @"txInfo" # sc
    (redeemer :: Term _ AuthRedeemer) <- parseData redeemerData
    tn <- pletC $ pfield @"tokenName" # redeemer
    txid :: Term _ PTxId <- pletC $ pfield @"txid" # redeemer

    -- Token name is hash of txid
    PTokenName tn' <- pmatchC tn
    passert_ "tn was hash of txid" $
      plookup # pcon (PDatumHash tn') # (pfield @"datums" # info)
          #== pcon (PJust $ pcon $ PDatum $ pforgetData $ pdata txid)

    -- mints exactly one token
    let minting = pfield @"mint" # info
    PValue m <- pmatchC minting
    PJust mintedAtCs <- pmatchC $ AssocMap.plookup # cs # m
    passert_ "did not mint exactly one token of this currency symbol" $
      mintedAtCs #== (AssocMap.psingleton # tn # 1)

    -- Exactly one vault output
    let outputs = pfield @"outputs" # info
    vault <- pletC $ unsingleton $ pfilter # plam ((vaultAdr #==) . (pfield @"address" #)) # outputs

    -- NFT sent to vault
    val <- pletC $ pfield @"value" # vault
    passert_ "nft went to vault" $ (Value.psingleton # cs # tn # 1) #<= pforgetPositive val

    -- Counter starts at 0
    outDatum <- pletC $ pfield @"datum" # vault
    POutputDatum datum' <- pmatchC outDatum
    PDatum dat <- pmatchC $ pfield @"outputDatum" # datum'
    (datum :: Term _ CounterDatum) <- parseData dat
    passert "count wasn't 0" $ (0 :: Term _ PInteger) #== pfield @"count" # datum

-- | The vault address validator
-- paremetized by an asset class
-- to validate:
-- The owner must sign the tx
-- the config must be a read only input
-- the utxo must have a valid nft
-- the redemer must be inc or spend
-- if it's inc
  -- there must be a new output
  -- it must have the same owner
  -- the counter must be 1 higher
  -- the new output must have the same nft
-- if it's spend
  -- the nft must be burned
vaultAdrValidator :: ClosedTerm (PData :--> PValidator)
vaultAdrValidator = plam $ \configNftCsData datum' redeemer' sc -> unTermCont $ do
  datum :: Term _ CounterDatum <- parseData datum'
  info <- pletC $ pfield @"txInfo" # sc
  passert_ "owner signed tx" $
    pelem # (pfield @"owner" # datum) #$ pfield @"signatories" # info
  redeemer <- parseData redeemer'
  configNftCs :: Term _ PCurrencySymbol <- parseData configNftCsData
  PJust config <- pmatchC $ pfind
    # plam (\(ininfo :: Term _ PTxInInfo) -> unTermCont $ do
        out <- pletC $ pfield @"resolved" # ininfo
        pure $ (pfield @"credential" #$ pfield @"address" # out) #== pcon (PScriptCredential $ pdcons # pconstant (mkValidator _) # pdnil ))
    # (pfield @"referenceInputs" # info)
  let nftCs = undefined configNftCsData
  PSpending  outRef <- pmatchC $ pfield @"purpose" # sc
  PJust inInfo <- pmatchC $ pfindOwnInput # (pfield @"inputs" # info) #$ pfield @"_0" # outRef
  passert_ "has nft" $ 0 #< (Value.pvalueOf # (pfield @"value" #$ pfield @"resolved" # inInfo) # nftCs # pconstant "")
  pmatchC redeemer >>= \case
    Inc _ -> do
      datum2 :: Term _ CounterDatum <- pgetContinuingDatum sc
      passert_ "owner is the same" $ pfield @"owner" # datum2 #== pfield @"owner" # datum
      passert "count is 1 more" $ pfield @"count" # datum2 #== pfield @"count" # datum + (1 :: Term _ PInteger)
      -- check has same nft
    Spend _ -> do
      -- NFT was burned
      pure $ popaque $ pcon PUnit


-- Types

data HelloRedemer (s :: S)
  = Inc (Term s (PDataRecord '[]))
  | Spend (Term s (PDataRecord '[]))
  deriving stock (Generic)
  deriving anyclass (PlutusType, PIsData, PEq)

instance DerivePlutusType HelloRedemer where type DPTStrat _ = PlutusTypeData
instance PTryFrom PData (PAsData HelloRedemer)

newtype CounterDatum (s :: S)
  = CounterDatum
      ( Term
          s
          ( PDataRecord
              '[ "owner" ':= PPubKeyHash
               , "count" ':= PInteger
               ]
          )
      )
  deriving stock (Generic)
  deriving anyclass (PlutusType, PIsData, PDataFields, PEq)

instance DerivePlutusType CounterDatum where type DPTStrat _ = PlutusTypeData
instance PTryFrom PData (PAsData CounterDatum)

newtype AuthRedeemer (s :: S)
  = AuthRedeemer
    ( Term
      s
      ( PDataRecord
          '[ "tokenName" ':= PTokenName
           , "txid" ':= PTxId
           ]
      )
    )
  deriving stock (Generic)
  deriving anyclass (PlutusType, PIsData, PDataFields, PEq)
instance DerivePlutusType AuthRedeemer where type DPTStrat _ = PlutusTypeData
instance PTryFrom PData (PAsData AuthRedeemer)

