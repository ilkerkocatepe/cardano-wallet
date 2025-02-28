{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE KindSignatures #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE StandaloneDeriving #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE UndecidableInstances #-}

module Cardano.Wallet.Shelley.Network.Discriminant
    ( SomeNetworkDiscriminant (..)
    , networkDiscriminantToId
    , discriminantNetwork
    , EncodeAddress (..)
    , EncodeStakeAddress (..)
    , DecodeAddress (..)
    , DecodeStakeAddress (..)
    , HasNetworkId (..)
    ) where

import Prelude

import Cardano.Api.Shelley
    ( NetworkId )
import Cardano.Wallet.Primitive.AddressDerivation
    ( DelegationAddress
    , Depth (..)
    , NetworkDiscriminant (..)
    , NetworkDiscriminantVal
    , PaymentAddress
    )
import Cardano.Wallet.Primitive.AddressDerivation.Byron
    ( ByronKey )
import Cardano.Wallet.Primitive.AddressDerivation.Icarus
    ( IcarusKey )
import Cardano.Wallet.Primitive.AddressDerivation.Shelley
    ( ShelleyKey )
import Cardano.Wallet.Primitive.Types.Address
    ( Address (..) )
import Control.Arrow
    ( (>>>) )
import Data.Proxy
    ( Proxy (..) )
import Data.Text
    ( Text )
import Data.Text.Class
    ( TextDecodingError )
import Data.Typeable
    ( Typeable )
import GHC.TypeLits
    ( KnownNat, natVal )

import qualified Cardano.Api as Cardano
import qualified Cardano.Ledger.BaseTypes as Ledger
import qualified Cardano.Wallet.Primitive.Types.RewardAccount as W

-- | Encapsulate a network discriminant and the necessary constraints it should
-- satisfy.
data SomeNetworkDiscriminant where
    SomeNetworkDiscriminant
        :: forall (n :: NetworkDiscriminant).
            ( NetworkDiscriminantVal n
            , PaymentAddress n IcarusKey 'CredFromKeyK
            , PaymentAddress n ByronKey 'CredFromKeyK
            , PaymentAddress n ShelleyKey 'CredFromKeyK
            , EncodeAddress n
            , DecodeAddress n
            , EncodeStakeAddress n
            , DecodeStakeAddress n
            , DelegationAddress n ShelleyKey 'CredFromKeyK
            , HasNetworkId n
            , Typeable n
            )
        => Proxy n
        -> SomeNetworkDiscriminant

deriving instance Show SomeNetworkDiscriminant

-- | An abstract class to allow encoding of addresses depending on the target
-- backend used.
class EncodeAddress (n :: NetworkDiscriminant) where
    encodeAddress :: Address -> Text

instance EncodeAddress 'Mainnet => EncodeAddress ('Staging pm) where
    encodeAddress = encodeAddress @'Mainnet

-- | An abstract class to allow decoding of addresses depending on the target
-- backend used.
class DecodeAddress (n :: NetworkDiscriminant) where
    decodeAddress :: Text -> Either TextDecodingError Address

instance DecodeAddress 'Mainnet => DecodeAddress ('Staging pm) where
    decodeAddress = decodeAddress @'Mainnet

class EncodeStakeAddress (n :: NetworkDiscriminant) where
    encodeStakeAddress :: W.RewardAccount -> Text

instance EncodeStakeAddress 'Mainnet => EncodeStakeAddress ('Staging pm) where
    encodeStakeAddress = encodeStakeAddress @'Mainnet

class DecodeStakeAddress (n :: NetworkDiscriminant) where
    decodeStakeAddress :: Text -> Either TextDecodingError W.RewardAccount

instance DecodeStakeAddress 'Mainnet => DecodeStakeAddress ('Staging pm) where
    decodeStakeAddress = decodeStakeAddress @'Mainnet

networkDiscriminantToId :: SomeNetworkDiscriminant -> NetworkId
networkDiscriminantToId (SomeNetworkDiscriminant proxy) = networkIdVal proxy

discriminantNetwork :: SomeNetworkDiscriminant -> Ledger.Network
discriminantNetwork = networkDiscriminantToId >>> \case
    Cardano.Mainnet -> Ledger.Mainnet
    Cardano.Testnet _magic -> Ledger.Testnet

-- | Class to extract a @NetworkId@ from @NetworkDiscriminant@.
class HasNetworkId (n :: NetworkDiscriminant) where
    networkIdVal :: Proxy n -> NetworkId

instance HasNetworkId 'Mainnet where
    networkIdVal _ = Cardano.Mainnet

instance KnownNat protocolMagic => HasNetworkId ('Testnet protocolMagic) where
    networkIdVal _ = Cardano.Testnet networkMagic
      where
        networkMagic =
            Cardano.NetworkMagic . fromIntegral . natVal $ Proxy @protocolMagic

instance HasNetworkId ('Staging protocolMagic) where
    networkIdVal _ = Cardano.Mainnet
