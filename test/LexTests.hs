module LexTests (tests) where

import Data.Char (isSpace)
import Data.Functor.Foldable (ListF (..), fold)
import Hedgehog (Property, forAll, property, (===))
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Internal.Range as Range
import Lex (Token (..))
import qualified Lex
import Test.Tasty (TestTree, testGroup)
import Test.Tasty.HUnit (assertEqual, testCase)
import Test.Tasty.Hedgehog (testProperty)

tests :: TestTree
tests =
  testGroup
    "lex tests"
    [ testCase "lex0" $
        assertEqual "" [TSymbol "abc"] (Lex.lex "abc"),
      testCase "lex1" $
        assertEqual "" [TLeft, TRight] (Lex.lex "()"),
      testCase "lex2" $
        assertEqual "" [TLeft, TSymbol "a", TRight] (Lex.lex "(a)"),
      testCase "lex3" $
        assertEqual "" [TLeft, TSymbol "a", TSymbol "b", TRight] (Lex.lex "(a b)"),
      testCase "lex4" $
        assertEqual "" [] (Lex.lex ""),
      testProperty "lex5" eqUnlexLex
    ]

eqUnlexLex :: Property
eqUnlexLex =
  property $ do
    str <- forAll $ Gen.string (Range.linear 0 100) Gen.ascii
    filter (not . isSpace) str === unlex (Lex.lex str)

unlex :: [Lex.Token] -> String
unlex = fold $ \case
  Nil -> []
  Cons Lex.TLeft acc -> '(' : acc
  Cons Lex.TRight acc -> ')' : acc
  Cons (Lex.TSymbol s) acc -> s ++ acc