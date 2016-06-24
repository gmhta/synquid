{-# LANGUAGE StandaloneDeriving, TemplateHaskell #-}
module ConferenceImpl where

import Prelude hiding (String, elem, print)

import qualified Prelude
import Data.Map (Map, (!))
import qualified Data.Map as M
import qualified Data.Text as T

import Control.Lens

import ConferenceVerification


type String = Prelude.String

type User = String

type PaperId = Int

data Tagged a = Tagged a

data Database = Database {
  _chair :: User,
  _phase :: Phase,
  _papers :: Map PaperId PaperRecord
}
 deriving (Show)

data World = World {
  _db :: Database,
  _sessionUser :: User,
  _effects :: Map User [String]
}
 deriving (Show)

data PaperRecord = PaperRecord {
  _papid :: PaperId,
  _title :: String,
  _authors :: [String],
  _conflicts :: [String],
  _status :: Status,
  _session :: String
}
 deriving (Show)

deriving instance Show Phase
deriving instance Show Status
deriving instance Show a => Show (List a)

makeLenses ''Database
makeLenses ''World
makeLenses ''PaperRecord


data PaperRow = PaperRow Int T.Text (Maybe T.Text) (Maybe T.Text) deriving (Show)
data UserRow = UserRow Int T.Text deriving (Show)
data AuthorRow = AuthorRow Int Int deriving (Show)
data ConflictRow = ConflictRow Int Int deriving (Show)

selectJoin table1 table2 cross = concatMap (\x -> concatMap (cross x) table2) table1

mkPapers prows urows arows crows =
    M.fromList $ map (\(PaperRow id title status session) ->
                        (id, PaperRecord {
                            _papid = id,
                            _title = T.unpack title,
                            _authors = authors id,
                            _conflicts = conflicts id,
                            _status = case fmap T.unpack status of
                                        Just "Accepted" -> Accepted
                                        Just "Rejected" -> Rejected
                                        _ -> NoDecision
                            ,
                            _session = case session of
                                         Just ss -> T.unpack ss
                                         Nothing -> ""
                        })) prows
    where
        authors papid = selectJoin arows urows (\(AuthorRow papid' usid') (UserRow usid name) ->
          if (papid == papid' && usid == usid') then [T.unpack name] else [])
        --concatMap (\(AuthorRow papid' usid') ->
        --    concatMap (\(UserRow usid name) -> if (papid == papid' && usid == usid') then [T.unpack name] else []) urows) arows
        conflicts papid = concatMap (\(ConflictRow papid' usid') ->
            concatMap (\(UserRow usid name) -> if (papid == papid' && usid == usid') then [T.unpack name] else []) urows) crows


{- Actual impls! -}


{- Boolean stuff -}

eq :: (Eq a, Ord a) => a -> a -> Bool
eq x y = x == y

and :: Bool -> Bool -> Bool
and p q = p && q

not :: Bool -> Bool
not = Prelude.not

{- Tagged "Monad" -}

bind ::
     (Eq a, Ord a, Eq b, Ord b) =>
       Tagged a -> (a -> Tagged b) -> Tagged b
bind (Tagged a) f = f a

return :: (Eq a, Ord a) => a -> Tagged a
return a = Tagged a

if_ ::
    (Eq a, Ord a) => Tagged Bool -> Tagged a -> Tagged a -> Tagged a
if_ (Tagged cond) t e = if cond then t else e

lift1 ::
      (Eq a, Ord a, Eq b, Ord b) => (a -> b) -> Tagged a -> Tagged b
lift1 f (Tagged a) = Tagged $ f a

lift2 ::
      (Eq a, Ord a, Eq b, Ord b, Eq c, Ord c) =>
        (a -> b -> c) -> Tagged a -> Tagged b -> Tagged c
lift2 f (Tagged a) (Tagged b) = Tagged $ f a b

{- List -}

elem :: (Eq a, Ord a) => a -> List a -> Bool
elem x Nil = False
elem x (Cons y xs) = (x == y) || elem x xs

toList [] = Nil
toList (x:xs) = Cons x (toList xs)

lfoldl f w Nil = w
lfoldl f w (Cons x xs) = lfoldl f (f w x) xs

{- String -}

emptyString :: String
emptyString = ""

strcat :: String -> String -> String
strcat s1 s2 = s1 ++ s2

toString :: (Show a) => a -> String
toString x = show x

{- Database access -}

getChair :: World -> Tagged User
getChair w = Tagged $ w ^. db ^. chair

getCurrentPhase :: World -> Tagged Phase
getCurrentPhase w = Tagged $ w ^. db ^. phase

getPaperAuthors :: World -> PaperId -> Tagged (List User)
getPaperAuthors w papid = Tagged $ toList $ (w ^. db ^. papers) ! papid ^. authors

getPaperConflicts :: World -> PaperId -> Tagged (List User)
getPaperConflicts = undefined  {- TODO -}

getPaperSession :: World -> PaperId -> Tagged String
getPaperSession w papid = Tagged $ (w ^. db ^. papers) ! papid ^. session

getPaperStatus :: World -> PaperId -> Tagged Status
getPaperStatus w papid = Tagged $ (w ^. db ^. papers) ! papid ^. status

getPaperTitle :: World -> PaperId -> Tagged String
getPaperTitle w papid = Tagged $ (w ^. db ^. papers) ! papid ^. title

getSessionUser :: World -> Tagged User
getSessionUser w = Tagged $ w ^. sessionUser


{- Output -}

print :: World -> Tagged User -> Tagged String -> World
print w (Tagged u) (Tagged s) = over (effects) (M.insertWith (++) u [s]) w

printAll :: World -> Tagged (List User) -> Tagged String -> World
printAll w (Tagged us) s = lfoldl (\w u -> print w (Tagged u) s) w us
