module Prot.Examples.RPS where
import Prot.Lang.Expr
import Prot.Lang.Command
import Data.SBV
import Prot.Lang.Lang
import Prot.Lang.Types
import Data.Type.Equality
import qualified Data.Map.Strict as Map
import Prot.MPS.MPS
import Data.Parameterized.Ctx
import Data.Parameterized.Context as Ctx

pongParty :: Party TInt
pongParty = Party unitExp react
    where
        react :: Expr TUnit -> Expr TInt -> Dist (Expr TUnit, Expr TInt)
        react _ msg = do
            let d = unifInt 0 10
            x <- dSamp d []
            return (unitExp, msg + x)

pingParty :: Party TInt
pingParty = Party unitExp react
    where
        react :: Expr TUnit -> Expr TInt -> Dist (Expr TUnit, Expr TInt)
        react _ msg =
            dIte (msg |<| 4)
                (return (unitExp, msg + 2))
                (return (unitExp, msg * 9))


pingPongInitMsg = mkSome $ (0 :: Expr TInt)
pingPongScript = ["ping", "pong", "ping", "pong"]

pingPong :: Dist (Expr TInt)
pingPong = do
    (_, m) <- runMPS (Map.fromList [("ping", pingParty), ("pong", pongParty)]) 0 ["ping", "pong", "ping", "pong"]
    return m

--
{-

type family Encode (t :: *) = (e :: Type) | e -> t

class Encodable a where
    encodedTypeRepr :: TypeRepr (Encode a)
    encode :: a -> Expr (Encode a)

data MsgTag = TPlay | TOpen | TOk | TResult | TOutput | TErr | TOpened 
mkSymbolicEnumeration ''MsgTag

data Msg = Play Bool | Open | Ok | Result Bool | Output Bool | Err | Opened Bool

type instance Encode Msg = TTuple (EmptyCtx ::> (TEnum MsgTag) ::> TBool)

encodeMsg :: MsgTag -> Bool -> Expr (Encode Msg)
encodeMsg a b = unSome (mkTuple [mkSome $ enumLit a, mkSome $ Expr (BoolLit b)]) $ \tr e ->
                    case testEquality tr (encodedTypeRepr :: TypeRepr (Encode Msg)) of
                      Just Refl -> e
                      Nothing -> error "absurd"

instance Encodable Msg where
    encodedTypeRepr = TTupleRepr (Ctx.empty Ctx.%> (TEnumRepr (TypeableType :: TypeableType MsgTag)) Ctx.%> TBoolRepr)
    encode (Play b) = encodeMsg TPlay b
    encode Open = encodeMsg TOpen False
    encode Ok = encodeMsg TOk False
    encode (Result b) = encodeMsg TResult b
    encode (Output b) = encodeMsg TOutput b
    encode Err = encodeMsg TErr False
    encode (Opened b) = encodeMsg TOpened b





rpsIdeal :: Prog
rpsIdeal = bRet (false :: Expr TBool)

-}
