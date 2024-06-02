{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Ast0 (Ast (..), AstF (..)) where

import Control.DeepSeq (NFData)
import Data.Functor.Foldable
  ( Base,
    Corecursive,
    Recursive (..),
    embed,
    project,
  )
import GHC.Generics (Generic)

data Ast
  = Symbol String
  | Compound [Ast]
  deriving (Show, Eq, Generic, NFData)

data AstF r
  = SymbolF String
  | CompoundF [r]
  deriving (Show, Functor)

type instance Base Ast = AstF

instance Recursive Ast where
  project (Symbol s) = SymbolF s
  project (Compound xs) = CompoundF xs

instance Corecursive Ast where
  embed :: Base Ast Ast -> Ast
  embed (SymbolF s) = Symbol s
  embed (CompoundF xs) = Compound xs