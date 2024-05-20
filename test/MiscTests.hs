module MiscTests (tests) where

import Ast0 (Ast (..), replace0At)
import AstC0
  ( Index,
    IndexElement (Between, LenMinus, ZeroPlus),
  )
import qualified AstP0
import Compile
  ( RuleDefinition (_variables),
    compile0to1,
    compile0toRuleDefinition,
    compile1toP0,
    ruleDefinitionPredicates,
  )
import Data.Either.Extra (fromRight')
import qualified Data.HashMap.Strict as H
import Data.Text (Text)
import Display (displayP0)
import Environment (createEnvironment)
import Error (ErrorType (..), CompileResult)
import Interpret (runProgram)
import Predicate
  ( IndexedPredicate (IndexedPredicate),
    Predicate (LengthEqualTo, LengthGreaterThanOrEqualTo, SymbolEqualTo),
    applyPredicate,
  )
import qualified Read
import Test.Tasty (TestTree, localOption, mkTimeout, testGroup)
import Test.Tasty.HUnit (Assertion, assertBool, assertEqual, assertFailure, testCase)
import Utils (getAtC0Index)

tests :: TestTree
tests =
  testGroup
    "misc tests"
    [ getAtC0IndexTest 0 "(0 1 2 3 4 5 6 7)" [Between 2 1] "(2 3 4 5 6)",
      getAtC0IndexTest 1 "(0 (1 2 3 4 5) (6 7 8 9 10))" [Between 1 0, LenMinus 1] "(5 10)",
      getAtC0IndexTest
        2
        "(((a (b c) (d e f)) (f (g h i j k)) (k (l))) last)"
        [ZeroPlus 0, Between 1 0, LenMinus 1]
        "((g h i j k) (l))",
      applyPredicateTest 0 "(start a a a a a end)" (SymbolEqualTo "a") [Between 1 1] True,
      applyPredicateTest 1 "(start a a middle a a end)" (SymbolEqualTo "a") [Between 1 1] False,
      applyPredicateTest 2 "()" (SymbolEqualTo "a") [Between 0 0] True,
      applyPredicateTest 3 "()" (SymbolEqualTo "a") [] False,
      applyPredicateTest 4 "(1 2 3)" (LengthEqualTo 3) [] True,
      applyPredicateTest 5 "((a) (b c) (d e f) (g h i j))" (LengthGreaterThanOrEqualTo 1) [Between 0 0] True,
      applyPredicateTest 6 "((a) (b c) (d e f) () (g h i j))" (LengthGreaterThanOrEqualTo 1) [Between 0 0] False,
      compile1ToP0Test
        0
        "(a b c .. d e)"
        ( Right $
            AstP0.CompoundWithEllipses
              [AstP0.Symbol "a", AstP0.Symbol "b"]
              (AstP0.Symbol "c")
              [AstP0.Symbol "d", AstP0.Symbol "e"]
        ),
      compile1ToP0Test
        1
        "(a b c d e)"
        ( Right $
            AstP0.CompoundWithoutEllipses
              [ AstP0.Symbol "a",
                AstP0.Symbol "b",
                AstP0.Symbol "c",
                AstP0.Symbol "d",
                AstP0.Symbol "e"
              ]
        ),
      compile1ToP0Test 2 "(a .. b c d .. e)" (Left MoreThanOneEllipsisInSingleCompoundTermOfPattern),
      testCase "ruleDefinitionVariableBindings0" $
        ruleDefinitionVariableBindingsTest
          "(def $a 0)"
          (Right [("$a", [])]),
      testCase "ruleDefinitionVariableBindings1" $
        ruleDefinitionVariableBindingsTest
          "(def ($a) 0)"
          (Right [("$a", [ZeroPlus 0])]),
      testCase "ruleDefinitionVariableBindings2" $
        ruleDefinitionVariableBindingsTest
          "(def ($a $b) 0)"
          ( Right
              [ ("$a", [ZeroPlus 0]),
                ("$b", [ZeroPlus 1])
              ]
          ),
      testCase "ruleDefinitionVariableBindings3" $
        ruleDefinitionVariableBindingsTest
          "(def ($a .. $b) 0)"
          ( Right
              [ ("$a", [Between 0 1]),
                ("$b", [LenMinus 1])
              ]
          ),
      testCase "ruleDefinitionVariableBindings4" $
        ruleDefinitionVariableBindingsTest
          "(def ((0 $a .. $b 1 2 3) ..) 0)"
          ( Right
              [ ("$a", [Between 0 0, Between 1 4]),
                ("$b", [Between 0 0, LenMinus 4])
              ]
          ),
      testCase "ruleDefinitionVariableBindings5" $
        ruleDefinitionVariableBindingsTest
          "(def ($a $a) 0)"
          (Left VariableUsedMoreThanOnceInPattern),
      testCase "ruleDefinitionVariableBindings6" $
        ruleDefinitionVariableBindingsTest
          "(def ($a .. (((((($a)))) ..) ..)) 0)"
          (Left VariableUsedMoreThanOnceInPattern),
      testCase "ruleDefinitionPredicates0" $
        ruleDefinitionPredicatesTest
          "(def (flatten (list (list $xs ..) ..)) (list $xs .. ..))"
          ( Right
              [ IndexedPredicate (LengthEqualTo 2) [],
                IndexedPredicate (SymbolEqualTo "flatten") [ZeroPlus 0],
                IndexedPredicate (LengthGreaterThanOrEqualTo 1) [ZeroPlus 1],
                IndexedPredicate (SymbolEqualTo "list") [ZeroPlus 1, ZeroPlus 0],
                IndexedPredicate (LengthGreaterThanOrEqualTo 1) [ZeroPlus 1, Between 1 0],
                IndexedPredicate (SymbolEqualTo "list") [ZeroPlus 1, Between 1 0, ZeroPlus 0]
              ]
          ),
      replaceAtTest 0 "(0 1 2 3 4 5)" [3] "THREE" "(0 1 2 THREE 4 5)",
      replaceAtTest 1 "(0 (10 11))" [1, 0] "ten" "(0 (ten 11))",
      replaceAtTest 2 "()" [1, 2, 3, 4, 5] "x" "()",
      runProgramTest
        0
        "(def x y)"
        "x"
        (Right "y"),
      runProgramTest
        1
        "(def a A)\
        \(def b B)"
        "a"
        (Right "A"),
      runProgramTest
        2
        "(def a A)\
        \(def b B)"
        "b"
        (Right "B"),
      runProgramTest
        3
        "(def ($x $y) $y)"
        "(a (b (c (d (e (f (g h)))))))"
        (Right "h"),
      runProgramTest
        4
        "(def ($x) $x)"
        "((0))"
        (Right "0"),
      runProgramTest
        5
        "(def ($x) $x)"
        "(0)"
        (Right "0"),
      runProgramTest
        6
        "(def (add $n 0) $n)\
        \(def (add $n (succ $m)) (succ (add $n $m)))"
        "(add 0 (succ 0))"
        (Right "(succ 0)"),
      runProgramTest
        7
        "(def (1 (2 $n)) $n)"
        "(1 (2 3))"
        (Right "3"),
      runProgramTest
        8
        "(def (1 (2 (3 $n))) $n)"
        "(1 (2 (3 4)))"
        (Right "4"),
      runProgramTest
        9
        "(def (A B) C)\
        \(def b B)"
        "(A b)"
        (Right "C"),
      runProgramTest
        10
        "(def (A B) B)\
        \(def b B)"
        "(A (A b))"
        (Right "B"),
      runProgramTest
        11
        "(def (add $n 0) $n)\
        \(def (add $n (succ $m)) (succ (add $n $m)))"
        "(add 0 (succ (succ 0)))"
        (Right "(succ (succ 0))"),
      runProgramTest
        12
        "(def 1 (S 0))\
        \(def 2 (S 1))\
        \(def 3 (S 2))\
        \(def 4 (S 3))\
        \(def 5 (S 4))\
        \(def 6 (S 5))\
        \(def 7 (S 6))\
        \(def 8 (S 7))\
        \(def (+ $n 0) $n)\
        \(def (+ $n (S $m)) (+ (S $n) $m))\
        \(def (fib 0) 0)\
        \(def (fib (S 0)) (S 0))\
        \(def (fib (S (S $n))) (+ (fib $n) (fib (S $n))))\
        \(def (equal 0 0) true)\
        \(def (equal (S $m) 0) false)\
        \(def (equal 0 (S $n)) false)\
        \(def (equal (S $m) (S $n)) (equal $m $n))"
        "(equal (fib 6) 8)"
        (Right "true"),
      runProgramTest
        14
        "(def (flatten (list (list $x ..) ..))\
        \  (list $x .. ..))"
        "(flatten (list (list 1 2 3 4 5 6) (list a b c) (list) (list d)))"
        (Right "(list 1 2 3 4 5 6 a b c d)"),
      runProgramTest
        15
        "(def (read ($c ..) 0 $x ..)\
        \     (read (0 $c ..) $x ..))"
        "(read () 0 0 0 0 0)"
        (Right "(read (0 0 0 0 0))"),
      localOption (mkTimeout 1000000 {- 1 second in microseconds -}) $
        -- The point of this test is to ensure that, when failing to match
        -- a term to a rule, we try to apply rules to subterms in a
        -- \*breadth-first* and not *depth-first* search fashion. This test
        -- should go into an infinite loop if *depth-first* is chosen,
        -- but should finish quickly if *breadth-first* is chosen, hence
        -- the timeout.
        runProgramTest
          16
          "(def (take 0 $c)\
          \  nil)\
          \(def (take (S $n) (cons $a $d))\
          \  (cons $a (take $n $d)))\
          \\
          \(def (repeat $x)\
          \  (cons $x (repeat $x)))\
          \\
          \(def (map $f nil)\
          \  nil)\
          \(def (map $f (cons $a $d))\
          \  (cons ($f $a)\
          \        (map $f $d)))\
          \\
          \(def (foldr $f $z nil)\
          \  $z)\
          \(def (foldr $f $z (cons $a $d))\
          \  ($f $a (foldr $f $z $d)))\
          \\
          \(def (add $n 0)\
          \  $n)\
          \(def (add $n (S $m))\
          \  (S (add $n $m)))\
          \\
          \(def (mul $n 0)\
          \  0)\
          \(def (mul $n (S $m))\
          \  (add $n (mul $n $m)))\
          \\
          \(def (zipWith $f $c nil)\
          \  nil)\
          \(def (zipWith $f nil $c)\
          \  nil)\
          \(def (zipWith $f (cons $a1 $d1) (cons $a2 $d2))\
          \  (cons ($f $a1 $a2)\
          \        (zipWith $f $d1 $d2)))\
          \\
          \(def (equal 0 0)\
          \  true)\
          \(def (equal 0 (S $m))\
          \  false)\
          \(def (equal (S $n) 0)\
          \  false)\
          \(def (equal (S $n) (S $m))\
          \  (equal $n $m))"
          "(equal\
          \  (mul\
          \    (S (S (S (S 0))))\
          \    (add\
          \      (S (S 0))\
          \      (S (S (S 0)))))\
          \  (foldr add 0\
          \    (take (S (S (S (S 0))))\
          \      (zipWith add\
          \        (repeat (S (S 0)))\
          \        (repeat (S (S (S 0))))))))"
          (Right "true"),
      runProgramOverlappingPatternsTest
        0
        "(def A B)\
        \(def A C)"
        ("A", "A"),
      runProgramOverlappingPatternsTest
        1
        "(def (A B C) X)\
        \(def (A B C) Y)"
        ("(A B C)", "(A B C)"),
      runProgramOverlappingPatternsTest
        2
        "(def (A $B C) X)\
        \(def (A B C) Y)"
        ("(A $B C)", "(A B C)"),
      runProgramOverlappingPatternsTest
        3
        "(def (A $B .. C) X)\
        \(def (A B C) Y)"
        ("(A $B .. C)", "(A B C)"),
      runProgramOverlappingPatternsTest
        4
        "(def (A $B .. C) X)\
        \(def (A B1 B2 B3 B4 B5 C) Y)"
        ("(A $B .. C)", "(A B1 B2 B3 B4 B5 C)"),
      runProgramOverlappingPatternsTest
        5
        "(def (A $B .. C) X)\
        \(def (A (B1) (B2 B3) B4 B5 C) Y)"
        ("(A $B .. C)", "(A (B1) (B2 B3) B4 B5 C)"),
      runProgramOverlappingPatternsTest
        6
        "(def A X)\
        \(def B Y)\
        \(def A Y)"
        ("A", "A"),
      runProgramOverlappingPatternsTest
        6
        "(def (add $n 0) $n)\
        \(def (add 0 $m) $m)"
        ("(add $n 0)", "(add 0 $m)")
    ]

runProgramOverlappingPatternsTest :: Int -> Text -> (Text, Text) -> TestTree
runProgramOverlappingPatternsTest number rules (overlap1Text, overlap2Text) =
  let compileP0 :: Text -> AstP0.Ast
      compileP0 = fromRight' . compile1toP0 . compile0to1 . head . fromRight' . Read.read
      (overlap1, overlap2) = (compileP0 overlap1Text, compileP0 overlap2Text)
   in testCase ("runProgramOverlappingPatterns#" ++ show number) $
        case createEnvironment rules of
          Right _ -> assertFailure "expected compilation failure"
          Left (OverlappingPatterns (o1, o2)) ->
            assertBool
              ( "expected these patterns: "
                  ++ show (displayP0 overlap1, displayP0 overlap2)
                  ++ " but recieved these patterns instead: "
                  ++ show (displayP0 o1, displayP0 o2)
              )
              ( o1 == overlap1 && o2 == overlap2
                  || o1 == overlap2 && o2 == overlap1
              )
          Left _ -> assertFailure "wrong error message"

runProgramTest :: Int -> Text -> Text -> CompileResult Text -> TestTree
runProgramTest number rules input expected =
  testCase ("runProgram#" ++ show number) $
    assertEqual
      ""
      (head . Read.read' <$> expected)
      (head <$> runProgram rules input)

replaceAtTest :: Int -> Text -> [Int] -> Text -> Text -> TestTree
replaceAtTest number ast index replacement expected =
  testCase ("replace0At#" ++ show number) $
    assertEqual
      ""
      (head $ Read.read' expected)
      ( replace0At
          (head $ Read.read' ast)
          index
          (head $ Read.read' replacement)
      )

compoundToList :: Ast -> [Ast]
compoundToList (Compound xs) = xs
compoundToList _ = error "expected compound in compoundToList"

getAtC0IndexTest :: Int -> Text -> AstC0.Index -> Text -> TestTree
getAtC0IndexTest number input index expected =
  testCase ("getAtC0IndexTest#" ++ show number) $
    assertEqual
      ""
      (compoundToList $ head $ Read.read' expected)
      ( getAtC0Index
          index
          (head $ Read.read' input)
      )

applyPredicateTest :: Int -> Text -> Predicate -> AstC0.Index -> Bool -> TestTree
applyPredicateTest number input predicate index expected =
  testCase ("applyPredicate#" ++ show number) $
    assertBool
      ""
      ( expected
          == applyPredicate
            (IndexedPredicate predicate index)
            (head $ Read.read' input)
      )

compile1ToP0Test :: Int -> Text -> CompileResult AstP0.Ast -> TestTree
compile1ToP0Test number input expected =
  testCase ("compile1ToP0#" ++ show number) $
    assertEqual
      ""
      expected
      (compile1toP0 (compile0to1 $ head $ Read.read' input))

ruleDefinitionVariableBindingsTest :: Text -> CompileResult [(String, AstC0.Index)] -> Assertion
ruleDefinitionVariableBindingsTest input expected =
  assertEqual
    ""
    (fmap H.fromList expected)
    (_variables <$> compile0toRuleDefinition (head $ Read.read' input))

ruleDefinitionPredicatesTest :: Text -> CompileResult [IndexedPredicate] -> Assertion
ruleDefinitionPredicatesTest input expected =
  assertEqual
    ""
    expected
    ( ruleDefinitionPredicates $
        fromRight' $
          compile0toRuleDefinition $
            head $
              Read.read' input
    )