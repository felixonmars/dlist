{-# OPTIONS_GHC -Wall #-}
{-# LANGUAGE CPP #-}
#if defined(__GLASGOW_HASKELL__) && __GLASGOW_HASKELL__ >= 708
{-# LANGUAGE OverloadedLists #-} -- For the IsList test
#if __GLASGOW_HASKELL__ == 708
{-# LANGUAGE PatternSynonyms #-} -- For pattern synonym use only in GHC 7.8
#endif
#endif


--------------------------------------------------------------------------------

module Main (main) where

--------------------------------------------------------------------------------

import Prelude hiding (concat, foldr, head, map, replicate, tail)
import qualified Data.List as List
import Text.Show.Functions ()
import Test.QuickCheck

import Data.DList

import OverloadedStrings (testOverloadedStrings)

#if MIN_VERSION_base(4,9,0)
-- base-4.9 introduced Semigroup and NonEmpty.
import Data.Semigroup (Semigroup(..))
import Data.List.NonEmpty (NonEmpty(..))

-- QuickCheck-2.10 dropped the Arbitrary NonEmpty instance, so we import it from
-- quickcheck-instances.
#if MIN_VERSION_QuickCheck(2,10,0)
import Test.QuickCheck.Instances ()
#endif

#endif

--------------------------------------------------------------------------------

eqWith :: Eq b => (a -> b) -> (a -> b) -> a -> Bool
eqWith f g x = f x == g x

eqOn :: Eq b => (a -> Bool) -> (a -> b) -> (a -> b) -> a -> Property
eqOn c f g x = c x ==> f x == g x

--------------------------------------------------------------------------------

prop_model :: [Int] -> Bool
prop_model = eqWith id (toList . fromList)

prop_empty :: Bool
prop_empty = ([] :: [Int]) == (toList empty :: [Int])

prop_singleton :: Int -> Bool
prop_singleton = eqWith (:[]) (toList . singleton)

prop_cons :: Int -> [Int] -> Bool
prop_cons c = eqWith (c:) (toList . cons c . fromList)

prop_snoc :: [Int] -> Int -> Bool
prop_snoc xs c = xs ++ [c] == toList (snoc (fromList xs) c)

prop_append :: [Int] -> [Int] -> Bool
prop_append xs ys = xs ++ ys == toList (fromList xs `append` fromList ys)

prop_concat :: [[Int]] -> Bool
prop_concat = eqWith List.concat (toList . concat . List.map fromList)

-- The condition reduces the size of replications and thus the eval time.
prop_replicate :: Int -> Int -> Property
prop_replicate n =
  eqOn (const (n < 100)) (List.replicate n) (toList . replicate n)

prop_head :: [Int] -> Property
prop_head = eqOn (not . null) List.head (head . fromList)

prop_tail :: [Int] -> Property
prop_tail = eqOn (not . null) List.tail (toList . tail . fromList)

prop_unfoldr :: (Int -> Maybe (Int, Int)) -> Int -> Int -> Property
prop_unfoldr f n =
  eqOn (const (n >= 0)) (take n . List.unfoldr f) (take n . toList . unfoldr f)

prop_foldr :: (Int -> Int -> Int) -> Int -> [Int] -> Bool
prop_foldr f x = eqWith (List.foldr f x) (foldr f x . fromList)

prop_map :: (Int -> Int) -> [Int] -> Bool
prop_map f = eqWith (List.map f) (toList . map f . fromList)

prop_map_fusion :: (Int -> Int) -> (a -> Int) -> [a] -> Bool
prop_map_fusion f g =
  eqWith (List.map f . List.map g) (toList . map f . map g . fromList)

prop_show_read :: [Int] -> Bool
prop_show_read = eqWith id (read . show)

prop_read_show :: [Int] -> Bool
prop_read_show x = eqWith id (show . f . read) $ "fromList " ++ show x
  where
    f :: DList Int -> DList Int
    f = id

#if defined(__GLASGOW_HASKELL__) && __GLASGOW_HASKELL__ >= 708
-- | Test that the IsList instance methods compile and work with simple lists
prop_IsList :: Bool
prop_IsList = test_fromList [1,2,3] && test_toList (fromList [1,2,3])
  where
    test_fromList, test_toList :: DList Int -> Bool
    test_fromList x = x == fromList [1,2,3]
    test_toList [1,2,3] = True
    test_toList _       = False

prop_patterns :: [Int] -> Bool
prop_patterns xs = case fromList xs of
  Nil       -> xs == []
  Cons y ys -> xs == (y:ys)
  _         -> False
#endif

#if MIN_VERSION_base(4,9,0)
prop_Semigroup_append :: [Int] -> [Int] -> Bool
prop_Semigroup_append xs ys = xs <> ys == toList (fromList xs <> fromList ys)

prop_Semigroup_sconcat :: NonEmpty [Int] -> Bool
prop_Semigroup_sconcat xs = sconcat xs == toList (sconcat (fmap fromList xs))

prop_Semigroup_stimes :: Int -> [Int] -> Bool
prop_Semigroup_stimes n xs =
  n < 0 || stimes n xs == toList (stimes n (fromList xs))
#endif

--------------------------------------------------------------------------------

props :: [(String, Property)]
props =
  [ ("model",             property prop_model)
  , ("empty",             property prop_empty)
  , ("singleton",         property prop_singleton)
  , ("cons",              property prop_cons)
  , ("snoc",              property prop_snoc)
  , ("append",            property prop_append)
  , ("concat",            property prop_concat)
  , ("replicate",         property prop_replicate)
  , ("head",              property prop_head)
  , ("tail",              property prop_tail)
  , ("unfoldr",           property prop_unfoldr)
  , ("foldr",             property prop_foldr)
  , ("map",               property prop_map)
  , ("map fusion",        property (prop_map_fusion (+1) (+1)))
  , ("read . show",       property prop_show_read)
  , ("show . read",       property prop_read_show)
#if defined(__GLASGOW_HASKELL__) && __GLASGOW_HASKELL__ >= 708
  , ("IsList",            property prop_IsList)
  , ("patterns",          property prop_patterns)
#endif
#if MIN_VERSION_base(4,9,0)
  , ("Semigroup <>",      property prop_Semigroup_append)
  , ("Semigroup sconcat", property prop_Semigroup_sconcat)
  , ("Semigroup stimes",  property prop_Semigroup_stimes)
#endif
  ]

--------------------------------------------------------------------------------

main :: IO ()
main = do
  testOverloadedStrings
  quickCheck $ conjoin $ List.map (uncurry label) props
