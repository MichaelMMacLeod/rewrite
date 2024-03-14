{-# LANGUAGE DeriveFunctor #-}
{-# LANGUAGE TypeFamilies #-}

module Ast0 (Ast0 (..), Ast0F (..)) where

import Data.Functor.Foldable (Base, Corecursive, Recursive, embed, project)

data Ast0
  = Symbol String
  | Compound [Ast0]
  deriving (Show)

data Ast0F r
  = SymbolF String
  | CompoundF [r]
  deriving (Show, Functor)

type instance Base Ast0 = Ast0F

instance Recursive Ast0 where
  project (Symbol s) = SymbolF s
  project (Compound xs) = CompoundF xs

instance Corecursive Ast0 where
  embed (SymbolF s) = Symbol s
  embed (CompoundF xs) = Compound xs
