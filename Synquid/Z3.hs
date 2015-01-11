{-# LANGUAGE TypeSynonymInstances, FlexibleInstances, TemplateHaskell #-}

-- | Interface to Z3
module Synquid.Z3 (solveSMTConstraints) where

import Synquid.Logic hiding (Sat, Unsat)
import qualified Synquid.Logic as Logic
import Z3.Monad

import Data.Maybe
import qualified Data.Set as Set
import Data.Set (Set)
import qualified Data.Map as Map
import Data.Map (Map)

import Control.Monad
import Control.Monad.Trans
import Control.Monad.Trans.State
import Control.Applicative
import Control.Lens

import System.IO.Unsafe

-- | Z3 state while building constraints
data Z3Env = Z3Env {
  _intSort :: Maybe Sort,     -- ^ Sorts (so far only int)
  _symbols :: Map Id Symbol   -- ^ Variable symbols
}

makeLenses ''Z3Env

type Z3State = StateT Z3Env Z3   

instance MonadZ3 Z3State where
    getSolver = lift getSolver
    getContext = lift getContext

emptyEnv :: Z3Env
emptyEnv = Z3Env Nothing Map.empty

evalZ3State :: Z3State a -> IO a
evalZ3State f = evalZ3 $ evalStateT f emptyEnv
      
-- | Convert a list of first-order constraints to a Z3 AST and check their satisfiability.
buildAndSolve :: [Formula] -> Z3State SMTResult
buildAndSolve constraints = do
  makeSorts
  mapM_ saveStringSymbol (Set.toList (Set.unions (map vars constraints)))
  mapM_ (toZ3 >=> assertCnstr) constraints
  toSMTResult <$> check
  where
    makeSorts = do
      is <- mkIntSort
      intSort .= Just is
    saveStringSymbol ident = do
      s <- mkStringSymbol ident
      symbols %= Map.insert ident s
    toSMTResult Sat = Logic.Sat
    toSMTResult Unsat = Logic.Unsat
    toSMTResult _ = error $ "buildAndSolve: Z3 returned Unknown"
          
-- | Convert a first-order constraint to a Z3 AST.
toZ3 :: Formula -> Z3State AST
toZ3 expr = case expr of
  BoolLit True  -> mkTrue
  BoolLit False -> mkFalse
  IntLit i -> mkInt i  
  Var ident -> do
    is <- fromJust <$> use intSort
    symbMb <- uses symbols (Map.lookup ident)
    case symbMb of
      Just s -> mkConst s is
      Nothing -> error $ "toZ3: didn't find " ++ ident
  Unknown ident -> error $ "toZ3: encountered a second-order unknown " ++ ident
  Unary op e -> toZ3 e >>= unOp op
  Binary op e1 e2 -> join (binOp op <$> toZ3 e1 <*> toZ3 e2)
  where
    unOp :: UnOp -> AST -> Z3State AST
    unOp Neg = mkUnaryMinus
    unOp Not = mkNot

    binOp :: BinOp -> AST -> AST -> Z3State AST
    binOp op =
      case op of
        Eq -> mkEq
        Neq -> \ x y -> mkEq x y >>= mkNot
        Gt -> mkGt
        Lt -> mkLt
        Le -> mkLe
        Ge -> mkGe      
        Plus -> list2 mkAdd
        Minus -> list2 mkSub
        And   -> list2 mkAnd
        Or    -> list2 mkOr
        Implies -> mkImplies
    list2 o x y = o [x, y]
        
-- | Is a list of first-order constraints satisfiable?
solveSMTConstraints :: [Formula] -> SMTResult
solveSMTConstraints constraints = unsafePerformIO $ evalZ3State $ buildAndSolve constraints
    