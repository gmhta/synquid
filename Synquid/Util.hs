-- | Helper functions
module Synquid.Util where

import qualified Data.Set as Set
import Data.Set (Set)
import qualified Data.Map as Map
import Data.Map (Map)

mapBoth f (a, b) = (f a, f b)

-- | 'restrictDomain' @keys m@ : map @m@ restricted on the set of keys @keys@
restrictDomain :: Ord k => Set k -> Map k a -> Map k a
restrictDomain keys m = fst $ partitionDomain keys m

-- | 'removeDomain' @keys m@ : map @m@ with the set of keys @keys@ removed from its domain
removeDomain :: Ord k => Set k -> Map k a -> Map k a
removeDomain keys m = snd $ partitionDomain keys m

-- | 'partitionDomain' @keys m@ : map @m@ partitioned into two maps, restricted to @keys@ and the rest
partitionDomain :: Ord k => Set k -> Map k a -> (Map k a, Map k a)
partitionDomain keys m = Map.partitionWithKey (\k _ -> k `Set.member` keys) m

-- | 'constMap' @keys val@ : map that maps each of @keys@ to @val@
constMap :: Ord k => Set k -> a -> Map k a
constMap keys val = Set.fold (\k m -> Map.insert k val m) Map.empty keys

-- | Analogue of 'concatMap' for sets.
setConcatMap :: (Ord a, Ord b) => (a -> Set b) -> Set a -> Set b
setConcatMap f s = Set.foldr Set.union Set.empty (Set.map f s)

-- | All subsets of a set.
subsets :: Ord k => Set k -> Set (Set k)
subsets s = let ss = if Set.null s 
                        then Set.empty
                        else setConcatMap subsets $ Set.map (flip Set.delete s) s
  in Set.insert s ss
  
-- | 'isParwiseDisjoint' @ss@: are all sets in @ss@ pairwise disjoint?  
isParwiseDisjoint :: Ord k => [Set k] -> Bool
isParwiseDisjoint [] = True
isParwiseDisjoint [s] = True
isParwiseDisjoint (s:ss) = all (isDisjoint s) ss && isParwiseDisjoint ss
  where isDisjoint s1 s2 = Set.null $ s1 `Set.intersection` s2 

-- | 'isPartition' @ss s@: are sets in @ss@ disjoint and together cover @s@?
isPartition :: Ord k => [Set k] -> Set k -> Bool
isPartition ss s = Set.unions ss == s && isParwiseDisjoint ss