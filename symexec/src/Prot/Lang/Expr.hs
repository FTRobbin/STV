module Prot.Lang.Expr where
import Prot.Lang.Types
import Data.SBV
import Data.Type.Equality
import Data.Typeable hiding (typeOf)
import Data.Type.Equality
import qualified Data.Data as Data
import qualified Data.Map.Strict as Map
import qualified Data.Parameterized.Context as Ctx
import Data.Parameterized.Some
import Data.Parameterized.NatRepr
import Data.Parameterized.Classes
import Data.Parameterized.TraversableFC as F
import qualified Data.Set as Set


data App (f :: Type -> *) (tp :: Type) where

    UnitLit :: App f TUnit
    IntLit :: !Integer -> App f TInt
    IntAdd :: !(f TInt) -> !(f TInt) -> App f TInt
    IntMul :: !(f TInt) -> !(f TInt) -> App f TInt
    IntNeg :: !(f TInt) -> App f TInt

    BoolLit :: !Bool -> App f TBool
    BoolAnd :: !(f TBool) -> !(f TBool) -> App f TBool
    BoolOr :: !(f TBool) -> !(f TBool) -> App f TBool
    BoolXor :: !(f TBool) -> !(f TBool) -> App f TBool
    BoolNot :: !(f TBool) -> App f TBool

    IntLe :: !(f TInt) -> !(f TInt) -> App f TBool
    IntLt :: !(f TInt) -> !(f TInt) -> App f TBool
    IntGt :: !(f TInt) -> !(f TInt) -> App f TBool
    IntEq :: !(f TInt) -> !(f TInt) -> App f TBool
    IntNeq :: !(f TInt) -> !(f TInt) -> App f TBool

    MkTuple :: !(CtxRepr ctx) -> !(Ctx.Assignment f ctx) -> App f (TTuple ctx)
    TupleGet :: !(f (TTuple ctx)) -> !(Ctx.Index ctx tp) -> !(TypeRepr tp) -> App f tp
    TupleSet :: !(f (TTuple ctx)) -> !(Ctx.Index ctx tp) -> !(f tp) -> App f (TTuple ctx)
    TupleEq ::  !(f (TTuple ctx)) -> !(f (TTuple ctx)) -> App f TBool
    

    NatLit :: !(NatRepr w) -> App f (TNat w)

    ListBuild :: !(TypeRepr tp) -> !(NatRepr w) -> (forall w'. (w' <= w) => NatRepr w' -> (f tp)) -> App f (TList w tp)
    ListLen :: !(f (TList w tp)) -> App f TInt
    ListGetIndex :: (w' <= w) => !(f (TList w tp)) -> !(f (TNat w')) -> App f tp
    ListSetIndex :: (w' <= w) => !(f (TList w tp)) -> !(f (TNat w')) -> !(f tp) -> App f (TList w tp)


    

data Expr tp = Expr !(App Expr tp) | AtomExpr !(Atom tp)

instance SynEq Expr where
    synEq (Expr e1) (Expr e2) = synEq e1 e2
    synEq (AtomExpr (Atom x tp1)) (AtomExpr (Atom y tp2)) = 
        case testEquality tp1 tp2 of
          Just Refl -> x ==y
          Nothing -> False
    synEq _ _ = False

class IsExpr a where

instance IsExpr (Expr TInt) where

instance IsExpr (Expr TBool) where

instance IsExpr (Expr (TTuple ctx)) where


instance TypeOf Expr where

    typeOf (AtomExpr (Atom _ t)) = t
    typeOf (Expr (UnitLit)) = knownRepr
    typeOf (Expr (IntLit _)) = knownRepr
    typeOf (Expr (IntAdd _ _)) = knownRepr
    typeOf (Expr (IntMul _ _)) = knownRepr
    typeOf (Expr (IntNeg _)) = knownRepr
    typeOf (Expr (BoolLit _)) = knownRepr
    typeOf (Expr (BoolNot _)) = knownRepr
    typeOf (Expr (BoolAnd _ _)) = knownRepr
    typeOf (Expr (BoolOr _ _)) = knownRepr
    typeOf (Expr (BoolXor _ _)) = knownRepr
    typeOf (Expr (IntLe _ _)) = knownRepr
    typeOf (Expr (IntLt _ _)) = knownRepr
    typeOf (Expr (IntGt _ _)) = knownRepr
    typeOf (Expr (IntEq _ _)) = knownRepr
    typeOf (Expr (IntNeq _ _)) = knownRepr
    typeOf (Expr (MkTuple cr asgn)) = TTupleRepr cr
    typeOf (Expr (TupleGet cr ind tp)) = tp
    typeOf (Expr (TupleSet t _ _)) = typeOf t
    typeOf (Expr (TupleEq _ _)) = knownRepr
    typeOf (Expr (NatLit w)) = TNatRepr w

    typeOf c@(Expr (ListBuild l w f)) = TListRepr w l
    typeOf (Expr (ListLen _)) = knownRepr
    typeOf (Expr (ListGetIndex l _)) = listType l
    typeOf (Expr (ListSetIndex l _ _)) = typeOf l


listType :: Expr (TList w tp) -> TypeRepr tp
listType (Expr (ListBuild l _ _ )) =  l
listType (Expr (TupleGet _ _ (TListRepr _ t))) = t
listType (Expr (ListGetIndex l _)) = case listType l of
                                       TListRepr _ t -> t
listType (AtomExpr (Atom _ (TListRepr _ t))) = t
listType (Expr (ListSetIndex l _ _)) = listType l


instance GetCtx Expr where
    getCtx (Expr (MkTuple cr asgn)) = cr
    getCtx (Expr (TupleSet t _ _)) = getCtx t
    getCtx (AtomExpr (Atom _ tr)) = getCtx tr
    getCtx _ = error "unimp1"

instance GetCtx TypeRepr where
    getCtx (TTupleRepr cr) = cr

instance (GetCtx f) => GetCtx (App f) where
    getCtx (MkTuple cr asgn) = cr
    getCtx (TupleSet t _ _) = getCtx t
    getCtx _ = error "unimp2"


instance ShowF Expr where

instance Show (Expr tp) where
    show = ppExpr

data Atom tp = Atom { atomName :: String, atomTypeRepr :: TypeRepr tp }

mkAtom :: String -> TypeRepr tp -> Expr tp
mkAtom s tr = AtomExpr $ Atom s tr

data SomeExp = forall tp. SomeExp (TypeRepr tp) (Expr tp)

instance Show SomeExp where
    show (SomeExp t e) = (ppExpr e) ++ ": " ++ (show t)

instance Eq SomeExp where
    (==) (SomeExp t1 e1) (SomeExp t2 e2) =
        case testEquality t1 t2 of
          Just Refl -> synEq e1 e2
          Nothing -> False


ppSomeExp :: SomeExp -> String
ppSomeExp (SomeExp _ e) = ppExpr e

unitExp :: Expr TUnit
unitExp = Expr (UnitLit)


mkSome :: Expr tp -> SomeExp
mkSome e = SomeExp (typeOf e) e

unSome :: SomeExp -> (forall tp. TypeRepr tp -> Expr tp -> a) -> a
unSome e k =
    case e of
      (SomeExp tp e) -> k tp e

ppBinop :: Expr tp1 -> Expr tp2 -> String -> String
ppBinop x y s = (ppExpr x) ++ s ++ (ppExpr y)

ppExpr :: Expr tp -> String
ppExpr (AtomExpr (Atom x _)) = x
ppExpr (Expr (UnitLit)) = "()"
ppExpr (Expr (IntLit i)) = show i
ppExpr (Expr (IntAdd e1 e2)) = ppBinop e1 e2 " + "
ppExpr (Expr (IntMul e1 e2)) = ppBinop e1 e2 " * "
ppExpr (Expr (IntNeg e1)) = "-" ++ (ppExpr e1) 

ppExpr (Expr (BoolLit e1)) = show e1
ppExpr (Expr (BoolAnd e1 e2)) = ppBinop e1 e2 " /\\ "
ppExpr (Expr (BoolOr e1 e2)) = ppBinop e1 e2 " \\/ "
ppExpr (Expr (BoolXor e1 e2)) = ppBinop e1 e2 " <+> "
ppExpr (Expr (BoolNot e1 )) = "not " ++ (ppExpr e1) 

ppExpr (Expr (IntLe e1 e2)) = ppBinop e1 e2 " <= "
ppExpr (Expr (IntLt e1 e2)) = ppBinop e1 e2 " < "
ppExpr (Expr (IntGt e1 e2)) = ppBinop e1 e2 " > "
ppExpr (Expr (IntEq e1 e2)) = ppBinop e1 e2 " == "
ppExpr (Expr (IntNeq e1 e2)) = ppBinop e1 e2 " != "

ppExpr (Expr (MkTuple cr asgn)) = show asgn
ppExpr (Expr (TupleGet ag ind tp)) = (ppExpr ag) ++ "[" ++ (show ind) ++ "]"
ppExpr (Expr (TupleSet ag ind val)) = (ppExpr ag) ++ "{" ++ (show ind) ++ " -> " ++ (ppExpr val) ++ "}"

ppExpr (Expr (TupleEq e1 e2)) = ppBinop e1 e2 " == "

ppExpr (Expr (NatLit w)) = show w
ppExpr (Expr (ListBuild l w f)) = "listBuild"
ppExpr (Expr (ListLen l)) = "len " ++ (show l) 
ppExpr (Expr (ListGetIndex l i)) = (show l) ++ "[" ++ (show i) ++ "]"
ppExpr (Expr (ListSetIndex l i v)) = (show l) ++ "[" ++ (show i) ++ "] := " ++ (show v)
--- utility functions

exprsToCtx :: [SomeExp] -> (forall ctx. CtxRepr ctx -> Ctx.Assignment Expr ctx -> a) -> a
exprsToCtx es =
    go Ctx.empty Ctx.empty es
        where go :: CtxRepr ctx -> Ctx.Assignment Expr ctx -> [SomeExp] -> (forall ctx'. CtxRepr ctx' -> Ctx.Assignment Expr ctx' -> a) -> a
              go ctx asgn [] k = k ctx asgn
              go ctx asgn ((SomeExp tr e):vs) k = go (ctx `Ctx.extend` tr) (asgn `Ctx.extend` e) vs k

class MkTuple a b where
    mkTuple :: a -> b

instance MkTuple (Expr a, Expr b) (Expr (TTuple (Ctx.EmptyCtx Ctx.::> a Ctx.::> b))) where 
    mkTuple (a,b) =
        exprsToCtx [mkSome a,mkSome b] $ \ctx asgn ->
            case (testEquality ctx (Ctx.empty `Ctx.extend` (typeOf a) `Ctx.extend` (typeOf b))) of
              Just Refl -> Expr (MkTuple ctx asgn)
              Nothing -> error "absurd"

instance MkTuple [SomeExp] SomeExp where
    mkTuple es = exprsToCtx es $ \ctx asgn ->
        SomeExp (TTupleRepr ctx) (Expr (MkTuple ctx asgn))

mkTupleRepr :: [Some TypeRepr] -> Some TypeRepr
mkTupleRepr ts =
    go (reverse ts) Ctx.empty
        where go :: [Some TypeRepr] -> CtxRepr ctx -> Some TypeRepr
              go [] ctx = Some (TTupleRepr ctx)
              go ((Some tr):ts) ctx = go ts (ctx `Ctx.extend` tr)

class UnfoldTuple a b where
    unfoldTuple :: a -> b

instance (KnownRepr TypeRepr a, KnownRepr TypeRepr b) => UnfoldTuple (Expr (TTuple (Ctx.EmptyCtx Ctx.::> a Ctx.::> b))) (Expr a, Expr b) where
    unfoldTuple tup =
        let ctx = getCtx tup in
        case (Ctx.intIndex (fromIntegral 0) (Ctx.size ctx), Ctx.intIndex (fromIntegral 1) (Ctx.size ctx)) of
          (Just (Some id0), Just (Some id1)) ->
              let tpr0 = ctx Ctx.! id0 in
              let tpr1 = ctx Ctx.! id1 in
              case (testEquality tpr0 (knownRepr :: TypeRepr a), testEquality tpr1 (knownRepr :: TypeRepr b)) of
                (Just Refl, Just Refl) -> 
                  (Expr (TupleGet tup id0 tpr0), Expr (TupleGet tup id1 tpr1))
                _ -> error "absurd"
          _ -> error "absurd"


getIth :: SomeExp -> Int -> SomeExp
getIth (SomeExp (TTupleRepr ctx) e) i 
 | Just (Some idx) <- Ctx.intIndex (fromIntegral i) (Ctx.size ctx) =
     let tpr = ctx Ctx.! idx in
         SomeExp tpr (Expr (TupleGet e idx tpr))
getIth _ _ = error "bad getIth"


setIth :: SomeExp -> Int -> SomeExp -> SomeExp
setIth (SomeExp (TTupleRepr ctx) e) i (SomeExp stp s) 
 | Just (Some idx) <- Ctx.intIndex (fromIntegral i) (Ctx.size ctx) =
     let tpr = ctx Ctx.! idx in
     case (testEquality tpr stp) of
       Just Refl ->
           SomeExp (TTupleRepr ctx) (Expr (TupleSet e idx s))
       Nothing -> error "type error in set"
setIth _ _ _ = error "bad setIth"

getTupleElems :: SomeExp -> [SomeExp]
getTupleElems e@(SomeExp (TTupleRepr ctx) _) =
    let s = Ctx.sizeInt (Ctx.size ctx) in
    map (getIth e) [0..(s-1)]

getTupleElems _ = error "bad getTupleElems"

---
-- instances

intLit :: Integer -> Expr TInt
intLit = fromInteger

natLit :: NatRepr i -> Expr (TNat i)
natLit i = Expr (NatLit i)

instance Num (Expr TInt) where
    e1 + e2 = Expr (IntAdd e1 e2)
    e1 * e2 = Expr (IntMul e1 e2)
    signum e = error "signum unimp"
    abs e = error "abs unimp"
    fromInteger i = Expr (IntLit i)
    negate e = Expr (IntNeg e)

(|<|) :: Expr TInt -> Expr TInt -> Expr TBool
e1 |<| e2 = Expr (IntLt e1 e2)

(|>|) :: Expr TInt -> Expr TInt -> Expr TBool
e1 |>| e2 = Expr (IntGt e1 e2)

(|<=|) :: Expr TInt -> Expr TInt -> Expr TBool
e1 |<=| e2 = Expr (IntLe e1 e2)

class ExprEq a where
    (|==|) :: a -> a -> Expr TBool
    (|!=|) :: a -> a -> Expr TBool
    a |!=| b =
        bnot (a |==| b)

instance ExprEq (Expr TInt) where
    e |==| e2 = Expr (IntEq e e2)



instance ExprEq (Expr (TTuple ctx)) where
    e |==| e2 = Expr (TupleEq e e2)


instance Boolean (Expr TBool) where
    true = Expr (BoolLit True)
    false = Expr (BoolLit False)
    bnot e = Expr (BoolNot e)
    (&&&) e1 e2 = Expr (BoolAnd e1 e2)
    (|||) e1 e2 = Expr (BoolOr e1 e2)

class SynEq (f :: k -> *) where
    synEq :: f a -> f b -> Bool

data ExprTup f tp = ExprTup (f tp) (f tp)

instance (SynEq f, GetCtx f) => SynEq (App f) where
   synEq (UnitLit) (UnitLit) = True
   synEq (IntLit i) (IntLit i2) = i == i2
   synEq  (IntAdd e1 e2) (IntAdd e1' e2') = (synEq e1 e1') && (synEq e2 e2')
   synEq  (IntMul e1 e2) (IntMul e1' e2') = (synEq e1 e1') && (synEq e2 e2')
   synEq  (IntNeg e1 ) (IntNeg e1' ) = (synEq e1 e1') 

   synEq  (BoolLit b) (BoolLit b') = b == b'
   synEq  (BoolAnd e1 e2) (BoolAnd e1' e2') = (synEq e1 e1') && (synEq e2 e2')
   synEq  (BoolOr e1 e2) (BoolOr e1' e2') = (synEq e1 e1') && (synEq e2 e2')
   synEq  (BoolXor e1 e2) (BoolXor e1' e2') = (synEq e1 e1') && (synEq e2 e2')
   synEq  (BoolNot e1 ) (BoolNot e1' ) = (synEq e1 e1') 

   synEq  (IntLe e1 e2) (IntLe e1' e2') = (synEq e1 e1') && (synEq e2 e2')
   synEq  (IntLt e1 e2) (IntLt e1' e2') = (synEq e1 e1') && (synEq e2 e2')
   synEq  (IntGt e1 e2) (IntGt e1' e2') = (synEq e1 e1') && (synEq e2 e2')
   synEq  (IntEq e1 e2) (IntEq e1' e2') = (synEq e1 e1') && (synEq e2 e2')
   synEq  (IntNeq e1 e2) (IntNeq e1' e2') = (synEq e1 e1') && (synEq e2 e2')

   synEq  (MkTuple repr asgn) (MkTuple repr1 asgn1) =
       case testEquality repr repr1 of
          Just Refl -> 
              let z = Ctx.zipWith (\x y -> ExprTup x y) asgn asgn1
                  bools = F.toListFC (\(ExprTup x y) -> synEq x y) z in
              bAnd bools
          Nothing -> False
   synEq (TupleGet e ind tr) (TupleGet e' ind' tr') =
       case (testEquality tr tr', testEquality (getCtx e) (getCtx e')) of
          (Just Refl, Just Refl) -> (synEq e e') && (ind == ind')
          _ -> False
    
   synEq x@(TupleSet e ind tup) y@(TupleSet e' ind' tup') =
       case (testEquality (getCtx x) (getCtx y)) of
          Just Refl -> (synEq e e') && (Ctx.indexVal ind == Ctx.indexVal ind') && (synEq tup tup')
          Nothing -> False

   synEq  _ _ = False


--- expr utility functions
 --

-- perform substitutions according to map. guarantees result expr is free of names in substitutions.
--
runFor :: Int -> (a -> a) -> a -> a
runFor 0 f a = a
runFor i f a = runFor (i - 1) f (f a)

exprSub :: Map.Map String SomeExp -> Expr tp -> Expr tp
exprSub emap e = go emap e
    where go :: Map.Map String SomeExp -> Expr tp -> Expr tp
          go emap (AtomExpr (Atom x tp)) =
              case (Map.lookup x emap) of
                Just (SomeExp tp2 e) ->
                    case (testEquality tp tp2) of
                      Just Refl -> e
                      Nothing -> 
                          error $ "type error in substitution of " ++ ppExpr e ++ " for " ++ x ++ ": got " ++ (show tp2) ++ " but expected " ++ (show tp)
                Nothing -> (AtomExpr (Atom x tp))
          go emap (Expr (UnitLit)) = Expr (UnitLit)
          go emap (Expr (IntLit i)) = Expr (IntLit i)
          go emap (Expr (IntAdd e1 e2)) = Expr (IntAdd (go emap e1) (go emap e2))
          go emap (Expr (IntMul e1 e2)) = Expr (IntMul (go emap e1) (go emap e2))
          go emap (Expr (IntNeg e1)) = Expr (IntNeg (go emap e1))

          go emap (Expr (BoolLit b)) = Expr (BoolLit b)
          go emap (Expr (BoolAnd e1 e2)) = Expr (BoolAnd (go emap e1) (go emap e2))
          go emap (Expr (BoolOr e1 e2)) = Expr (BoolOr (go emap e1) (go emap e2))
          go emap (Expr (BoolXor e1 e2)) = Expr (BoolXor (go emap e1) (go emap e2))
          go emap (Expr (BoolNot e1 )) = Expr (BoolNot (go emap e1))
    
          go emap (Expr (IntLe e1 e2)) = Expr (IntLe (go emap e1) (go emap e2))
          go emap (Expr (IntLt e1 e2)) = Expr (IntLt (go emap e1) (go emap e2))
          go emap (Expr (IntGt e1 e2)) = Expr (IntGt (go emap e1) (go emap e2))
          go emap (Expr (IntEq e1 e2)) = Expr (IntEq (go emap e1) (go emap e2))
          go emap (Expr (IntNeq e1 e2)) = Expr (IntNeq (go emap e1) (go emap e2))

          go emap (Expr (MkTuple cr asgn)) = Expr (MkTuple cr (F.fmapFC (go emap) asgn))
          go emap (Expr (TupleGet tup ind etp)) = Expr (TupleGet (go emap tup) ind etp)
          go emap (Expr (TupleSet tup ind e)) = Expr (TupleSet (go emap tup) ind (go emap e))
        

          go emap (Expr (TupleEq x y)) = Expr (TupleEq (go emap x) (go emap y))

          go emap (Expr (NatLit i)) = Expr (NatLit i)
          go emap (Expr (ListBuild l w f)) = Expr (ListBuild l w (\w' -> go emap (f w'))) 
          go emap (Expr (ListLen l)) = Expr (ListLen (go emap l))
          go emap (Expr (ListGetIndex f i)) = Expr (ListGetIndex (go emap f) (go emap i))
          go emap (Expr (ListSetIndex l i v)) = Expr (ListSetIndex (go emap l) (go emap i) (go emap v))

someExprSub :: Map.Map String SomeExp -> SomeExp -> SomeExp
someExprSub emap e1 = 
    case e1 of
      (SomeExp tp e) ->
          SomeExp tp (exprSub emap e)

class FreeVar a where
    freeVars :: a -> Set.Set String

instance FreeVar (Expr tp) where

    freeVars (AtomExpr (Atom x tp)) = Set.singleton x 
    freeVars (Expr (UnitLit)) = Set.empty
    freeVars (Expr (IntLit _)) = Set.empty
    freeVars (Expr (IntAdd e1 e2)) = (freeVars e1) `Set.union` (freeVars e2)
    freeVars (Expr (IntMul e1 e2)) = (freeVars e1) `Set.union` (freeVars e2)
    freeVars (Expr (IntNeg e1 )) = (freeVars e1) 

    freeVars (Expr (BoolLit _)) = Set.empty
    freeVars (Expr (BoolAnd e1 e2)) = (freeVars e1) `Set.union` (freeVars e2)
    freeVars (Expr (BoolOr e1 e2)) = (freeVars e1) `Set.union` (freeVars e2)
    freeVars (Expr (BoolXor e1 e2)) = (freeVars e1) `Set.union` (freeVars e2)
    freeVars (Expr (BoolNot e1 )) = (freeVars e1) 

    freeVars (Expr (IntLe e1 e2)) = (freeVars e1) `Set.union` (freeVars e2)
    freeVars (Expr (IntLt e1 e2)) = (freeVars e1) `Set.union` (freeVars e2)
    freeVars (Expr (IntGt e1 e2)) = (freeVars e1) `Set.union` (freeVars e2)
    freeVars (Expr (IntEq e1 e2)) = (freeVars e1) `Set.union` (freeVars e2)
    freeVars (Expr (IntNeq e1 e2)) = (freeVars e1) `Set.union` (freeVars e2)

    freeVars (Expr (MkTuple _ asgn)) = Set.unions $ toListFC freeVars asgn
    freeVars (Expr (TupleGet tup _ _)) = freeVars tup
    freeVars (Expr (TupleSet tup _ e)) = (freeVars tup) `Set.union` (freeVars e)

    freeVars (Expr (TupleEq x y)) = (freeVars x) `Set.union` (freeVars y)
    
    freeVars (Expr (NatLit _)) = Set.empty
    freeVars (Expr (ListBuild _ w f)) =
        Set.unions $ natForEach (knownNat :: NatRepr 0) w (\w' -> freeVars $ f w')
    freeVars (Expr (ListLen l)) = freeVars l
    freeVars (Expr (ListGetIndex f i)) = (freeVars f) `Set.union` (freeVars i)
    freeVars (Expr (ListSetIndex l i v)) = (freeVars l) `Set.union` (freeVars i) `Set.union` (freeVars v)

instance FreeVar SomeExp where
    freeVars (SomeExp tp e) = freeVars e

instance (FreeVar a) => (FreeVar [a]) where
    freeVars as = Set.unions $ map freeVars as

class ArbitraryExpr (tp :: Type) where
    arbitraryExpr :: Expr tp

instance ArbitraryExpr TInt where
    arbitraryExpr = 0

instance ArbitraryExpr TBool where
    arbitraryExpr = false

instance ArbitraryExpr TUnit where
    arbitraryExpr = unitExp

instance ArbitraryExpr (TTuple ctx) where
    arbitraryExpr = error "unimp arbitary"



