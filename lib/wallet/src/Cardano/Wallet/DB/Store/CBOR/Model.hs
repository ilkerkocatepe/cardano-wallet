{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TypeFamilies #-}

module Cardano.Wallet.DB.Store.CBOR.Model
    ( TxCBORSet (..)
    , DeltaTxCBOR (..)
    )
    where

import Prelude

import Cardano.Wallet.DB.Sqlite.Types
    ( TxId )
import Cardano.Wallet.Read.Tx.CBOR
    ( TxCBOR )
import Data.Delta
    ( Delta (..) )
import Data.Map.Strict
    ( Map )
import qualified Data.Map.Strict as Map
import Fmt
    ( Buildable (..) )
import GHC.Generics
    ( Generic )

newtype TxCBORSet =
    TxCBORSet {relations :: Map TxId TxCBOR}
    deriving ( Eq, Show, Generic, Monoid, Semigroup )

data DeltaTxCBOR
    = Append TxCBORSet
    -- ^ Add or overwrite (by id) transactions cbor.
    | DeleteTx TxId
    -- ^ Remove cbor by transaction id.
    deriving ( Eq, Show, Generic )

instance Buildable DeltaTxCBOR where
    build = build . show

instance Delta DeltaTxCBOR where
    type Base DeltaTxCBOR = TxCBORSet
    apply (Append addendum) x = addendum <> x
    apply (DeleteTx tid) (TxCBORSet m) = TxCBORSet
        $ Map.delete tid m
