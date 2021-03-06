{-# LANGUAGE FlexibleInstances, DeriveGeneric, TemplateHaskell #-}
module LinkGrammar.AST
  (
    Link(..)
 -- , Link'
  , LinkID(..)
  , NodeType(..)
  , Rule(..)
  , LinkName, MacroName
  , NLPWord(..), nlpword, nlpclass
  , LinkDirection(..)
  , LVal(..)
  , exactCompare
  , module Data.Tree
--  , module Data.Tree.Zipper
  )
  where

import Control.Lens
import Data.PrettyPrint
import Data.List
import Data.Tree
import Data.Binary
import GHC.Generics (Generic)
import Control.DeepSeq

data LinkDirection = Plus
                   | Minus
                   deriving (Eq, Show, Generic, Ord)

instance Binary LinkDirection                            
instance NFData LinkDirection

instance PrettyPrint LinkDirection where
  pretty Plus  = "+"
  pretty Minus = "-"

data LinkID = LinkID {
      _linkName :: LinkName
    , _linkDirection :: LinkDirection
    } deriving (Eq, Generic)

instance Show LinkID where
    show (LinkID a b) = a ++ (pretty b)

type LinkName = String

type MacroName = String

data NLPWord =
    NLPWord {
      _nlpword
    , _nlpclass :: String
    }
    deriving (Eq, Generic, Show)
makeLenses ''NLPWord
    
instance Binary NLPWord
instance NFData NLPWord

instance PrettyPrint NLPWord where
    pretty NLPWord {_nlpword = w, _nlpclass = c}
        | null c = w
        | True = w ++ ".[" ++ c ++ "]"

instance Binary LinkID
instance NFData LinkID

instance Ord LinkID where
    compare (LinkID k i) (LinkID l j) =
        case compare i j of
          EQ ->
              go k l where
                    go [] _ = EQ
                    go _ [] = EQ
                    go (a:t1) (b:t2)
                        | a == b || any (=='*') [a,b] = go t1 t2
                        | True                        = compare a b
          a ->
              a

exactCompare :: LinkID -> LinkID -> Ordering
exactCompare (LinkID k i) (LinkID l j) =
    case compare i j of
      EQ -> compare k l
      a  -> a

instance PrettyPrint LinkID where
    pretty (LinkID a Plus) =  a ++ "+"
    pretty (LinkID a Minus) = a ++ "-"

data NodeType = Optional {_cost :: !Float}
              | Link {_cost :: !Float, _link :: !LinkID}
              | LinkAnd {_cost :: !Float}
              | LinkOr {_cost :: !Float}
              | Macro MacroName
              | MultiConnector {_cost :: !Float}
              | Cost Float
              | EmptyLink
              deriving (Eq, Show, Generic)

instance Binary NodeType
instance NFData NodeType

getCost :: NodeType -> Float
getCost (Optional c) = c
getCost (Link c _) = c
getCost (LinkAnd c) = c
getCost (LinkOr c) = c
getCost (MultiConnector c) = c
getCost (Cost c) = c
getCost _ = 0

type Link = Tree NodeType

-- type Link' t = TreePos t NodeType

paren :: Link -> String
paren a@Node {rootLabel = r} =
    case r of
      Link _ _   -> pretty a
      Macro _    -> pretty a
      Optional _ -> pretty a
      Cost _     -> pretty a
      _          -> "(" ++ pretty a ++ ")"

instance PrettyPrint Link where
    pretty Node {rootLabel = r, subForest = l} =
        case r of
          Link _ a         -> pretty a
          Macro a          -> "<" ++ a ++  ">"
          LinkOr _         -> intercalate " or " (map paren l)
          LinkAnd _        -> intercalate " & " (map paren l)
          Optional _       -> "{ " ++ pretty (head l) ++ " }"
          MultiConnector _ -> "@" ++ paren (head l)
          Cost x
              | x /= 1   -> "[ " ++ pretty (head l) ++ " ]" ++ show x ++ " "
              | True     -> "[ " ++ pretty (head l) ++ " ]"
          EmptyLink      -> "()"

data LVal = RuleDef { _ruleDef :: NLPWord }
          | MacroDef { _macroName :: MacroName }
          deriving (Eq, Show, Generic)

instance PrettyPrint LVal where
  pretty (RuleDef a) = pretty a
  pretty (MacroDef a) = "<" ++ (pretty a) ++ ">"

data Rule = Rule
            {
              _lval  :: [LVal]
            , _links :: Link
            }
            deriving (Eq, Show)

instance PrettyPrint Rule where
    pretty (Rule a b) = pretty a ++ " : " ++ pretty b ++ " ; "

instance PrettyPrint [LVal] where
    pretty = unwords . map pretty
