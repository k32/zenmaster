{-# LANGUAGE BangPatterns #-}
module LinkGrammar.Process
    (
      makeRuleset
    , Ruleset(..)
    ) where

import LinkGrammar.AST
import Data.PrettyPrint
import Data.Tree
import Data.List
import Data.Traversable
import Control.Arrow
import Control.Monad.State
import Control.Monad.Reader    
import qualified Data.Map as M
import qualified Data.Vector as V

type RuleIndex = [(Int, [Int])]
    
data Ruleset = Ruleset {
      _rules :: V.Vector Rule''
    , _index :: M.Map LinkName RuleIndex
    } -- deriving (Show)

data Rule' = Rule' {
      _lval' :: [NLPWord]
    , _links' :: Link
    } deriving (Show, Eq)

data Rule'' = Rule'' {
      _lval'' :: [NLPWord]
    , _link'' :: Link' Full
    } -- deriving (Show)

makeRuleset :: [Rule] -> Ruleset
makeRuleset rr =
    let
        (macros, rules) = sortOut rr

        rules' = V.fromList $ map (assocFlatten . costPropagate . deMacrify macros [])
                 rules

        index0 = execState $ V.imapM_ makeIndex rules'

        makeIndex idx (Rule'' _ y) = (`runReaderT` []) $ go idx   

        -- unZip (Rule' a b) = Rule'' a $ fromTree b
    in
      Ruleset {
          _rules = rules'
          -- !!!!! HACK HACK HACK !!!!!
        , _index = M.fromDistinctAscList undefined
        }

(=*=) :: LinkID -> LinkID -> Bool
(LinkID x _) =*= (LinkID y _) = f x y
    where
     f [] _                   = True
     f _  []                  = True
     f (a:t₁) (b:t₂)
         | a == b             = f t₁ t₂
         | any (=='*') [a, b] = True

sortOut :: [Rule] -> (M.Map MacroName Link, [Rule'])
sortOut = foldl f (M.empty, [])
    where f (m, a) Rule {_lval = l, _links = r} =
              (
                foldr (\x -> M.insert x r) m m1
              , a1 : a
              )
             where 
               (m1, a1) = (map _macroName *** rule') $ partition isMacro l

               rule' = ((flip Rule') r) . map _ruleDef

          isMacro (RuleDef _) = False
          isMacro _           = True

          split = partition isMacro

deMacrify :: M.Map MacroName Link -> [MacroName] -> Rule' -> Rule'
deMacrify m l (Rule' ł r) =
    let
        f :: [MacroName] -> Link -> State [MacroName] Link
        f l₀ (Node α β) = case α of
                            Macro n -> do
                                if n `elem` l₀
                                   then error $ "deMacrify: Loop detected, see macro " ++ n
                                   else return ()
                                modify (n:) -- TODO: duplicates
                                return $ m M.! n
                            _ -> do
                                c' <- mapM (f l₀) β
                                return Node {
                                             rootLabel = α
                                           , subForest = c'
                                           }
        (r', l₁) = (`runState` l) $ f l r
    in
      if r' == r
         then (Rule' ł r')
         else deMacrify m l₁ (Rule' ł r')

costPropagate :: Rule' -> Rule'
costPropagate = id

assocFlatten :: Rule' -> Rule'
assocFlatten = id
