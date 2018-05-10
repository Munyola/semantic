{-# LANGUAGE OverloadedLists #-}
module Analysis.TypeScript.Spec (spec) where

import Data.Abstract.Environment as Env
import Data.Abstract.Evaluatable
import qualified Language.TypeScript.Assignment as TypeScript
import Data.Abstract.Value as Value
import Data.Abstract.Number as Number
import qualified Data.Language as Language
import Data.Sum

import SpecHelpers

spec :: Spec
spec = parallel $ do
  describe "evaluates TypeScript" $ do
    it "imports with aliased symbols" $ do
      env <- environment . snd <$> evaluate "main.ts"
      Env.names env `shouldBe` [ "bar", "quz" ]

    it "imports with qualified names" $ do
      res <- snd <$> evaluate "main1.ts"
      environment res `shouldBe` [ ("b", addr 0)
                                 , ("z", addr 4)
                                 ]

      heapLookup (Address (Precise 0)) (heap res) `shouldBe` ns "b" [ ("baz", addr 1)
                                                                    , ("foo", addr 3) ]
      heapLookup (Address (Precise 4)) (heap res) `shouldBe` ns "z" [ ("baz", addr 1)
                                                                    , ("foo", addr 3) ]

    it "side effect only imports" $ do
      env <- environment . snd <$> evaluate "main2.ts"
      env `shouldBe` emptyEnv

    it "fails exporting symbols not defined in the module" $ do
      v <- fst <$> evaluate "bad-export.ts"
      v `shouldBe` Left (SomeExc (injectSum @(EvalError (Value Precise)) (ExportError "foo.ts" (Name "pip"))))

    it "evaluates early return statements" $ do
      res <- evaluate "early-return.ts"
      fst res `shouldBe` Right [injValue (Value.Float (Number.Decimal 123.0))]

  where
    fixtures = "test/fixtures/typescript/analysis/"
    evaluate entry = evalTypeScriptProject (fixtures <> entry)
    evalTypeScriptProject path = testEvaluating <$> evaluateProject typescriptParser Language.TypeScript Nothing path
