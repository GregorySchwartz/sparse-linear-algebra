{-# language GADTs, TypeFamilies #-}
-----------------------------------------------------------------------------
-- |
-- Module      :  Numeric.LinearAlgebra.Sparse.Accelerate
-- Copyright   :  (c) Marco Zocca 2017
-- License     :  BSD3 (see the file LICENSE)
--
-- Maintainer  :  zocca marco gmail
-- Stability   :  experimental
-- Portability :  portable
--
-- `accelerate` instances for sparse linear algebra
--
-----------------------------------------------------------------------------
module Numeric.LinearAlgebra.Sparse.Accelerate where

import Foreign.Storable (Storable(..))
import Control.Monad.Primitive
import Data.Ord (comparing)

import qualified Data.Array.Accelerate as A
import Data.Array.Accelerate
          (Acc, Array, Vector, Segments, DIM1, DIM2, Exp, Any(Any), All(All), Z(Z), (:.)((:.)))
import Data.Array.Accelerate.IO -- (fromVectors, toVectors)

import Data.Array.Accelerate.Array.Sugar
import Data.Vector.Algorithms.Merge (sort, sortBy)
-- import Data.Vector.Algorithms.Common

import qualified Data.Vector as V
import qualified Data.Vector.Mutable as VM
-- import qualified Data.Vector.Generic as VG
import qualified Data.Vector.Storable as VS


import Data.Array.Accelerate.Interpreter (run)

import Data.Array.Accelerate.Sparse.SMatrix
import Data.Array.Accelerate.Sparse.SVector
import Data.Array.Accelerate.Sparse.COOElem



-- * SpGEMM : matrix-matrix product



-- | Sort an accelerate array via vector-algorithms
sortA :: (Vectors (EltRepr e) ~ VS.Vector e
         , Storable e
         , Ord e
         , Elt e
         , Shape t
         , PrimMonad m) => t -> Array t e -> m (Array t e)
sortA dim v = do
  let vm = toVectors v
  vm' <- sortVS vm
  return $ fromVectors dim vm'

-- sortA' v = do
--   let dim = A.shape v
--   let vm = toVectors v
--   vm' <- sortVS vm
--   return $ fromVectors dim vm'

-- sortA' v = do
--   let v_acc = A.use v
--       dim = A.shape v_acc
--       vm = toVectors v
--   vm' <- sortVS vm
--   -- return $ fromVectors dim vm'
--   return vm'


-- | Sort a storable vector
sortVS :: (Storable a, PrimMonad m, Ord a) =>
     VS.Vector a -> m (VS.Vector a)
sortVS v = do
  vm <- VS.thaw v
  sort vm
  VS.freeze vm

sortWith :: (Ord b, PrimMonad m) => (a -> b) -> V.Vector a -> m (V.Vector a)
sortWith by v = do
  vm <- V.thaw v
  sortBy (comparing by) vm
  V.freeze vm






-- Sparse-matrix vector multiplication
-- -----------------------------------

-- type SparseVector e = Vector (A.Int32, e)
-- type SparseMatrix e = (Segments A.Int32, SparseVector e)


-- smvm :: A.Num a => Acc (SparseMatrix a) -> Acc (Vector a) -> Acc (Vector a)
-- smvm smat vec
--   = let (segd, svec)    = A.unlift smat
--         (inds, vals)    = A.unzip svec

--         -- vecVals         = A.gather (A.map A.fromIntegral inds) vec
--         vecVals         = A.backpermute
--                              (A.shape inds)
--                              (\i -> A.index1 $ A.fromIntegral $ inds A.! i)
--                              vec
--         products        = A.zipWith (*) vecVals vals
--     in
--     A.foldSeg (+) 0 products segd



-- sv0 :: A.Array DIM1 (Int, Int)
-- sv0 = A.fromList (Z :. 5) $ zip [0,1,3,4,6] [4 ..]

sv1 :: A.Array DIM1 (COOElem Int Double)
sv1 = A.fromList (Z :. 3) [a, b, c] where
  a = CooE (0, 1, pi)
  b = CooE (0, 0, 2.3)
  c = CooE (1, 1, 1.23)
