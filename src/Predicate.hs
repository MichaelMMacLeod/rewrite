module Predicate
  ( Predicate (..),
    IndexedPredicate (..),
    applyPredicate,
  )
where

import qualified Ast0
import AstC0 (getAtC0Index)
import qualified AstC0

data Predicate
  = SymbolEqualTo String
  | LengthEqualTo Int
  | LengthGreaterThanOrEqualTo Int
  deriving (Eq, Show, Ord)

toFunc :: Predicate -> (Ast0.Ast -> Bool)
toFunc (SymbolEqualTo str1) (Ast0.Symbol str2) = str1 == str2
toFunc (LengthEqualTo n) (Ast0.Compound xs) = length xs == n
toFunc (LengthGreaterThanOrEqualTo n) (Ast0.Compound xs) = length xs >= n
toFunc _ _ = False

data IndexedPredicate = IndexedPredicate Predicate AstC0.Index
  deriving (Eq, Show, Ord)

applyPredicate :: IndexedPredicate -> Ast0.Ast -> Bool
applyPredicate (IndexedPredicate p i) ast = all (toFunc p) (getAtC0Index i ast)