{-# LANGUAGE FlexibleContexts, TypeFamilies #-}
{-# language ScopedTypeVariables, FlexibleInstances #-}
-----------------------------------------------------------------------------
-- |
-- Copyright   :  (C) 2016 Marco Zocca
-- License     :  GPL-3 (see LICENSE)
-- Maintainer  :  zocca.marco gmail
-- Stability   :  provisional
-- Portability :  portable
--
-----------------------------------------------------------------------------
module LibSpec where

import Data.Sparse.Common
import Numeric.LinearAlgebra.Sparse
-- import Numeric.LinearAlgebra.Class

-- import Control.Applicative (liftA2)
import Control.Monad (replicateM)
-- import Control.Monad.Primitive
-- import Data.Foldable (foldrM)

import Data.Complex
import Data.Either (either, isRight)

import Data.VectorSpace hiding (magnitude)

import Control.Monad.State.Strict (execState)

-- import qualified System.Random.MWC as MWC
-- import qualified System.Random.MWC.Distributions as MWC
       
import Test.Hspec
import Test.Hspec.QuickCheck
import Test.QuickCheck




main :: IO ()
main = hspec spec

-- niter = 5

spec :: Spec
spec = do
  describe "Numeric.LinearAlgebra.Sparse : Library" $ do
    prop "Subtraction is cancellative" $ \(x :: SpVector Double) ->
      norm2Sq (x ^-^ x) `shouldBe` zero
    it "<.> : inner product (Real)" $
      tv0 <.> tv0 `shouldBe` 61
    it "<.> : inner product (Complex)" $
      tvc2 <.> tvc3 `shouldBe` 2 :+ (-2)  
    it "transposeSM : sparse matrix transpose" $
      transposeSM m1 `shouldBe` m1t
    it "(#>) : matrix-vector product (Real)" $
      nearZero ( norm2Sq ((aa0 #> x0true) ^-^ b0 )) `shouldBe` True
    it "(<#) : vector-matrix product (Real)" $
      nearZero ( norm2Sq ((x0true <# aa0) ^-^ aa0tx0 ))`shouldBe` True  
    it "(##) : matrix-matrix product (Real, square)" $ 
      (m1 ## m2) `shouldBe` m1m2
    it "(##) : matrix-matrix product (Real, rectangular)" $ do
      (m1' ## m2') `shouldBe` m1m2'
      (m2' ## m1') `shouldBe` m2m1'
    it "(##) : matrix-matrix product (Complex)" $
      (aa3c ## aa3c) `shouldBe` aa3cx 
    it "eye : identity matrix" $
      infoSM (eye 10) `shouldBe` SMInfo 10 0.1
    it "insertCol : insert a column in a SpMatrix" $
      insertCol (eye 3) (fromListDenseSV 3 [2,2,2]) 0 `shouldBe` fromListSM (3,3) [(0,0,2),(1,0,2),(1,1,1),(2,0,2),(2,2,1)]
    it "insertRow : insert a row in a SpMatrix" $
      insertRow (eye 3) (fromListDenseSV 3 [2,2,2]) 1 `shouldBe` fromListSM (3,3) [(0,0,1), (1,0,2), (1,1,2), (1,2,2), (2,2,1)]
    it "extractCol -> insertCol : identity" $
      insertCol (eye 3) (extractCol (eye 3) 1) 1 `shouldBe` eye 3
    it "extractRow -> insertRow : identity" $
      insertRow (eye 3) (extractRow (eye 3) 1) 1 `shouldBe` eye 3      
    it "countSubdiagonalNZ : # of nonzero elements below the diagonal" $
      countSubdiagonalNZSM m3 `shouldBe` 1
    it "permutPairsSM : permutation matrices are orthogonal" $ do
      let pm0 = permutPairsSM 3 [(0,2), (1,2)] :: SpMatrix Double
      pm0 #~#^ pm0 `shouldBe` eye 3
      pm0 #~^# pm0 `shouldBe` eye 3
    it "isLowerTriSM : checks whether matrix is lower triangular" $
      isLowerTriSM tm8' && isUpperTriSM tm8 `shouldBe` True
    it "modifyInspectN : early termination by iteration count" $
      execState (modifyInspectN 2 (nearZero . diffSqL) (/2)) (1 :: Double) `shouldBe` 1/8
    it "modifyInspectN : termination by value convergence" $
      nearZero (execState (modifyInspectN (2^16) (nearZero . head) (/2)) (1 :: Double)) `shouldBe` True
    -- prop "aa2 is positive semidefinite" $ \(v :: SpVector Double) ->
    --   prop_psd aa2 v
  describe "QuickCheck properties:" $ do
    -- prop "prop_matSPD_vec : (m #^# m) is symmetric positive definite" $
    --   \(PropMatSPDVec (m :: SpMatrix Double) v) -> prop_spd m v
    prop "prop_dot : (v <.> v) ~= 1 if ||v|| == 1" $
      \(v :: SpVector Double) -> prop_dot v
    prop "prop_matMat1 : (A ## B)^T == (B^T ## A^T)" $
      \p@(PropMatMat (_ :: SpMatrix Double) _) -> prop_matMat1 p
    prop "prop_matMat2 : M^T ##^ M == M #^# M^T" $
      \p@(PropMat (_ :: SpMatrix Double)) -> prop_matMat2 p
    -- prop "prop_QR : Q R = A, Q is orthogonal, R is upper triangular" $
    --   \p@(PropMatI (_ :: SpMatrix Double)) -> prop_QR p
    -- prop "prop_Cholesky" $ \p@(PropMat_SPD (_ :: SpMatrix Double)) -> prop_Cholesky p
    -- prop "prop_linSolve GMRES" $ prop_linSolve GMRES_
    
  describe "Numeric.LinearAlgebra.Sparse : Iterative linear solvers (Real)" $ do
    -- it "TFQMR (2 x 2 dense)" $
    it "GMRES (2 x 2 dense)" $
      checkLinSolveR GMRES_ aa0 b0 x0true `shouldBe` True
    it "GMRES (3 x 3 sparse, symmetric pos.def.)" $
      checkLinSolveR GMRES_ aa2 b2 x2 `shouldBe` True
    it "GMRES (4 x 4 sparse)" $
      checkLinSolveR GMRES_ aa1 b1 x1 `shouldBe` True
    it "BCG (2 x 2 dense)" $
      checkLinSolveR BCG_ aa0 b0 x0true `shouldBe` True
    it "BCG (3 x 3 sparse, symmetric pos.def.)" $
      checkLinSolveR BCG_ aa2 b2 x2 `shouldBe` True
    -- it "BiCGSTAB (2 x 2 dense)" $ 
    --   nearZero (normSq (linSolve BICGSTAB_ aa0 b0 ^-^ x0true)) `shouldBe` True
    it "BiCGSTAB (3 x 3 sparse, symmetric pos.def.)" $ 
      checkLinSolveR BICGSTAB_ aa2 b2 x2 `shouldBe` True
    it "CGS (2 x 2 dense)" $ 
      checkLinSolveR CGS_ aa0 b0 x0true `shouldBe` True
    it "CGS (3 x 3 sparse, SPD)" $ 
      checkLinSolveR CGS_ aa2 b2 x2 `shouldBe` True
  describe "Numeric.LinearAlgebra.Sparse : Direct linear solvers (Real)" $ 
    it "luSolve (4 x 4 sparse)" $ 
      checkLuSolve aa1 b1 `shouldBe` True         
  describe "Numeric.LinearAlgebra.Sparse : QR factorization (Real)" $ do    
    it "qr (4 x 4 sparse)" $
      checkQr tm4 `shouldBe` True
    it "qr (3 x 3 dense)" $ 
      checkQr tm2 `shouldBe` True
    it "qr (10 x 10 sparse)" $
      checkQr tm7 `shouldBe` True
  describe "Numeric.LinearAlgebra.Sparse : QR factorization (Complex)" $ do
    it "qr (2 x 2 dense)" $
      checkQr aa3cx `shouldBe` True
  describe "Numeric.LinearAlgebra.Sparse : LU factorization (Real)" $ do
    it "lu (4 x 4 dense)" $
      checkLu tm6 `shouldBe` True
    it "lu (10 x 10 sparse)" $
      checkLu tm7 `shouldBe` True
  describe "Numeric.LinearAlgebra.Sparse : Cholesky factorization (Real, symmetric pos.def.)" $ 
    it "chol (5 x 5 sparse)" $
      checkChol tm7 `shouldBe` True
  describe "Numeric.LinearAlgebra.Sparse : Arnoldi iteration, early breakdown detection (Real)" $ do      
    it "arnoldi (4 x 4 dense)" $
      checkArnoldi tm6 4 `shouldBe` True
    it "arnoldi (5 x 5 sparse)" $
      checkArnoldi tm7 5 `shouldBe` True    


{- linear systems -}

checkLinSolve method aa b x x0r =
  either
    (error . show)
    (\xhat -> nearZero (norm2Sq (x ^-^ xhat)))
    (linSolve0 method aa b x0r)

checkLinSolveR
  :: LinSolveMethod ->
     SpMatrix Double ->       -- ^ operator
     SpVector Double ->       -- ^ r.h.s
     SpVector Double ->       -- ^ candidate solution
     Bool
checkLinSolveR method aa b x = checkLinSolve method aa b x x0r where
  x0r = mkSpVR n $ replicate n 0.1
  n = ncols aa

checkLinSolveC
  :: LinSolveMethod
     -> SpMatrix (Complex Double)
     -> SpVector (Complex Double)
     -> SpVector (Complex Double)
     -> Bool
checkLinSolveC method aa b x = checkLinSolve method aa b x x0r where
  x0r = mkSpVC n $ replicate n (0.1 :+ 0.1)
  n = ncols aa






{- Givens rotation-}
checkGivens1 :: (Elt a, MatrixRing (SpMatrix a), Epsilon a, Floating a) =>
     SpMatrix a -> IxRow -> IxCol -> (a, Bool)
checkGivens1 tm i j = (rij, nearZero rij) where
  g = givens tm i j
  r = g ## tm
  rij = r @@ (i, j)


{- QR-}

checkQr :: (Elt a, MatrixRing (SpMatrix a), Epsilon (MatrixNorm (SpMatrix a)), Epsilon a, Floating a) =>
     SpMatrix a -> Bool
checkQr a = c1 && c2 && c3 where
  (q, r) = qr a
  c1 = nearZero $ normFrobenius ((q #~# r) ^-^ a)
  c2 = isOrthogonalSM q
  c3 = isUpperTriSM r



{- LU -}
checkLu :: (Elt a, MatrixRing (SpMatrix a), VectorSpace (SpVector a), Epsilon (MatrixNorm (SpMatrix a)), Epsilon a) =>
     SpMatrix a -> Bool
checkLu a = c1 && c2 where
  (l, u) = lu a
  c1 = nearZero (normFrobenius ((l #~# u) ^-^ a))
  c2 = isUpperTriSM u && isLowerTriSM l



{- Cholesky -}

checkChol :: (Elt a, MatrixRing (SpMatrix a), Epsilon (MatrixNorm (SpMatrix a)), Epsilon a, Floating a) =>
     SpMatrix a -> Bool
checkChol a = c1 && c2 where
  l = chol a
  c1 = nearZero $ normFrobenius ((l ##^ l) ^-^ a)
  c2 = isLowerTriSM l


{- direct linear solver -}

checkLuSolve :: (Scalar (SpVector t) ~ t, MatrixType (SpVector t) ~ SpMatrix t,
      Elt t, Normed (SpVector t), LinearVectorSpace (SpVector t),
      Epsilon (Magnitude (SpVector t)), Epsilon t) =>
     SpMatrix t -> SpVector t -> Bool
checkLuSolve amat rhs = nearZero (norm2Sq ( (lmat #> (umat #> xlu)) ^-^ rhs ))
  where
     (lmat, umat) = lu amat
     xlu = luSolve lmat umat rhs
      
  
{- Arnoldi iteration -}
-- checkArnoldi :: (Epsilon a, Floating a, Eq a) => SpMatrix a -> Int -> Bool
checkArnoldi aa kn = nearZero (normFrobenius $ lhs ^-^ rhs) where
  b = onesSV (nrows aa)
  (q, h) = arnoldi aa b kn
  (m, n) = dim q
  q' = extractSubmatrix q (0, m - 1) (0, n - 2) -- q' = all but one column of q
  rhs = q #~# h
  lhs = aa #~# q'












-- * Arbitrary newtypes and instances for QuickCheck

-- | helpers
sized2 :: (Int -> Int -> Gen a) -> Gen a
sized2 f = sized $ \i -> sized $ \j -> f i j

sized3 :: (Int -> Int -> Int -> Gen a) -> Gen a
sized3 f = sized $ \i -> sized $ \j -> sized $ \k -> f i j k


whenFail1 :: Testable prop => (t -> IO ()) -> (t -> prop) -> t -> Property
whenFail1 io p x = whenFail (io x) (property $ p x)




-- | Generate a (m * n) random sparse matrix having d elements
genSpM0 :: Arbitrary a => Int -> Int -> Int -> Gen (SpMatrix a)
genSpM0 m n d = do
      -- let d = floor (sqrt $ fromIntegral (m * n)) :: Int
      i_ <- vectorOf d $ choose (0, m-1)
      j_ <- vectorOf d $ choose (0, n-1)      
      x_ <- vector d
      return $ fromListSM (m,n) $ zip3 i_ j_ x_

-- | Generate a random (m * n) sparse matrix having sqrt(m * n) elements
genSpM :: Arbitrary a => Int -> Int -> Gen (SpMatrix a)      
genSpM m n = genSpM0 m n $ floor (sqrt $ fromIntegral (m * n))




-- | Generate a (m * n) random DENSE matrix
genSpMDense :: (Arbitrary a, Num a) => Int -> Int -> Gen (SpMatrix a)
genSpMDense m n = do
  xs <- vector (m*n)
  let ii = concatMap (replicate n) [0..m-1]
      jj = concat $ replicate m [0..n-1]
  return $ fromListSM (m,n) $ zip3 ii jj xs

-- | SpMatrix with constant diagonal
genSpMConstDiagonal ::
  (Arbitrary a, Ord a, Num a) => (a -> Bool) -> Int -> Gen (SpMatrix a)
genSpMConstDiagonal f n = do
  x <- arbitrary `suchThat` f
  return $ mkDiagonal n (replicate n x)

genSpMDiagonal :: Arbitrary a => ([a] -> Bool) -> Int -> Gen (SpMatrix a)
genSpMDiagonal f n = do
  xs <- vector n `suchThat` f
  return $ mkDiagonal n xs




-- | Generate an arbitrary square sparse matrix with unit diagonal
genSpMI :: (Num a, Arbitrary a) => Int -> Gen (SpMatrix a)
genSpMI m = do
  mm <- genSpM m m
  let ii = eye m
  return $ mm ^+^ ii


-- genSpM_SPD :: (Arbitrary a, Ord a, Num a) => Int -> Gen (SpMatrix a)
-- genSpM_SPD n = do
--   shift <- choose (1, n-2)
--   xdiag <- arbitrary `suchThat` (> 0)
--   x <- arbitrary `suchThat` (< 0) 
--   let diag = replicate n xdiag
--       sd = replicate (n - shift) x
--       mm1 = mkSubDiagonal n shift sd
--       mm2 = mkSubDiagonal n (negate shift) sd
--       mm0 = mkSubDiagonal n 0 diag      
--   return $ mm1 ^+^ (mm2 ^+^ mm0)



-- | Generate a random Householder reflection matrix
genReflMatDense :: Int -> Gen (SpMatrix Double)
genReflMatDense n = do
  v <- normalize2 <$> (genSpVDense n :: Gen (SpVector Double))
  return $ hhRefl v



-- | Generate a random sparse vector
genSpV0 :: Arbitrary a => Int -> Int -> Gen (SpVector a)
genSpV0 d n = do
  i_ <- vectorOf d  $ choose (0, n -1)
  v_ <- vector d
  return $ fromListSV n (zip i_ v_)

genSpV :: Arbitrary a => Int -> Gen (SpVector a)
genSpV n = genSpV0 (floor (sqrt $ fromIntegral n) :: Int) n


-- | Generate a random dense vector
genSpVDense :: Arbitrary a => Int -> Gen (SpVector a)
genSpVDense n = do
  v <- vector n
  return $ fromListDenseSV n v





-- | An Arbitrary SpVector such that at least one entry is nonzero
instance Arbitrary (SpVector Double) where
  arbitrary = sized genSpV `suchThat` any isNz 


-- | An arbitrary square SpMatrix
newtype PropMat0 a = PropMat0 (SpMatrix a) deriving (Eq, Show)
instance Arbitrary (PropMat0 Double) where
   arbitrary = sized (\n -> PropMat0 <$> genSpM n n) 

      
-- | An arbitrary SpMatrix
newtype PropMat a = PropMat { unPropMat :: SpMatrix a} deriving (Eq, Show)
instance Arbitrary (PropMat Double) where
  arbitrary = sized2 (\m n -> PropMat <$> genSpM m n) `suchThat` ((> 2) . nrows . unPropMat)

-- nzDim :: SpMatrix a -> Bool
-- nzDim mm = let (m, n) = dim mm in m > 2 && n > 2

-- sizedCon :: (a -> Bool) -> (Int -> Gen a) -> Gen a
-- sizedCon f genf = sized genf `suchThat` f




-- | An arbitrary DENSE SpMatrix
newtype PropMatDense a = PropMatDense {unPropMatDense :: SpMatrix a} deriving (Eq, Show)
instance Arbitrary (PropMatDense Double) where
  arbitrary = sized2 (\m n -> PropMatDense <$> genSpM m n) `suchThat` ((> 2) . nrows . unPropMatDense)



-- | An arbitrary SpMatrix with identity diagonal 
newtype PropMatI a = PropMatI {unPropMatI :: SpMatrix a} deriving (Eq)
instance Show a => Show (PropMatI a) where show = show . unPropMatI
instance Arbitrary (PropMatI Double) where
  arbitrary = sized (\m -> PropMatI <$> genSpMI m) `suchThat` ((> 2) . nrows . unPropMatI)


-- | A symmetric, positive-definite matrix with identity diagonal
newtype PropMat_SPD a = PropMat_SPD {unPropMat_SPD :: SpMatrix a} deriving (Show)
-- instance Arbitrary (PropMat_SPD Double) where
--   arbitrary = sized genf `suchThat` ((> 3) . nrows . unPropMat_SPD) where
--    genf n = PropMat_SPD <$> genSpM_SPD n






-- | A pair of arbitrary SpMatrix, having compliant dimensions
data PropMatMat a = PropMatMat (SpMatrix a) (SpMatrix a) deriving (Eq, Show)
instance Arbitrary (PropMatMat Double) where
  arbitrary = sized3 genf where
    genf m n o = do
      mat1 <- genSpM m n
      mat2 <- genSpM n o
      return $ PropMatMat mat1 mat2



-- | A square matrix and vector of compatible size
data PropMatVec a = PropMatVec (SpMatrix a) (SpVector a) deriving (Eq, Show)
instance Arbitrary (PropMatVec Double) where
  arbitrary = sized genf `suchThat` \(PropMatVec _ v) -> dim v > 2 where
    genf n = do
      mm <- genSpM n n
      v <- genSpV n
      return $ PropMatVec mm v



-- -- | A symmetric positive definite matrix and vector of compatible size
-- data PropMatSPDVec a = PropMatSPDVec (SpMatrix a) (SpVector a) deriving (Eq, Show)
-- instance Arbitrary (PropMatSPDVec Double) where
--   arbitrary = do
--     PropMatVec m v <- arbitrary -- :: Gen (PropMatVec Double)
--     return $ PropMatSPDVec (m #^# m) v


    











-- | QuickCheck properties

-- | Dot product of a normalized vector with itself is ~= 1
prop_dot :: (Normed v, Epsilon (Scalar v)) => v -> Bool
prop_dot v = let v' = normalize2 v in nearOne (v' <.> v')

-- | Positive semidefinite matrix. 
prop_spd :: (LinearVectorSpace v, InnerSpace v, Ord (Scalar v), Num (Scalar v)) =>
     MatrixType v -> v -> Bool
prop_spd mm v = (v <.> (mm #> v)) >= 0

-- prop_spd' :: PropMatSPDVec Double -> Bool
-- prop_spd' (PropMatSPDVec m v) = prop_spd m v



-- | (A B)^T == (B^T A^T)
prop_matMat1 :: (MatrixRing (SpMatrix t), Eq t) => PropMatMat t -> Bool
prop_matMat1 (PropMatMat a b) =
  transpose (a ## b) == (transpose b ##^ a)

-- | Implementation of transpose, (##), (##^) and (#^#) is consistent
prop_matMat2 :: (MatrixRing (SpMatrix t), Eq t) => PropMat t -> Bool
prop_matMat2 (PropMat m) = transpose m ##^ m == m #^# transpose m

-- | Cholesky factorization of a random SPD matrix 
prop_Cholesky :: (Elt a, MatrixRing (SpMatrix a), Epsilon (MatrixNorm (SpMatrix a)), Epsilon a, Floating a) => PropMat_SPD a -> Bool
prop_Cholesky (PropMat_SPD m) = checkChol m


-- | QR decomposition
prop_QR :: (Elt a, MatrixRing (SpMatrix a),
      Epsilon (MatrixNorm (SpMatrix a)), Epsilon a, Floating a) =>
     PropMatI a -> Bool
prop_QR (PropMatI m) = checkQr m


-- | check a random linear system
prop_linSolve :: LinSolveMethod -> PropMatVec Double -> Bool
prop_linSolve method (PropMatVec aa x) = do
  let
    aai = aa ^+^ eye (nrows aa) -- for invertibility
    b = aai #> x
  checkLinSolveR method aai b x

-- -- test data




{-

example 0 : 2x2 linear system

[1 2] [2] = [8]
[3 4] [3]   [18]

[1 3] [2] = [11]
[2 4] [3]   [16]


-}


aa0 :: SpMatrix Double
aa0 = fromListDenseSM 2 [1,3,2,4]

-- b0, x0 : r.h.s and initial solution resp.
b0, x0, x0true, aa0tx0 :: SpVector Double
b0 = mkSpVR 2 [8,18]
x0 = mkSpVR 2 [0.3,1.4]


-- x0true : true solution
x0true = mkSpVR 2 [2,3]

aa0tx0 = mkSpVR 2 [11,16]







{- 4x4 system -}

aa1 :: SpMatrix Double
aa1 = sparsifySM $ fromListDenseSM 4 [1,0,0,0,2,5,0,10,3,6,8,11,4,7,9,12]

x1, b1 :: SpVector Double
x1 = mkSpVR 4 [1,2,3,4]

b1 = mkSpVR 4 [30,56,60,101]



{- 3x3 system -}
aa2 :: SpMatrix Double
aa2 = sparsifySM $ fromListDenseSM 3 [2, -1, 0, -1, 2, -1, 0, -1, 2]
x2, b2 :: SpVector Double
x2 = mkSpVR 3 [3,2,3]

b2 = mkSpVR 3 [4,-2,4]


aa22 = fromListDenseSM 2 [2,1,1,2] :: SpMatrix Double





{- 2x2 Complex system -}

aa0c :: SpMatrix (Complex Double)
aa0c = fromListDenseSM 2 [ 3 :+ 1, (-3) :+ 2, (-2) :+ (-1), 1 :+ (-2)]

b0c = mkSpVC 2 [3 :+ (-4), (-1) :+ 0.5]

x1c = mkSpVC 2 [2 :+ 2, 2 :+ 3]
b1c = mkSpVC 2 [4 :+ (-2), (-10) :+ 1]

aa2c :: SpMatrix (Complex Double)
aa2c = fromListDenseSM 2 [3, -3, -2, 1]








-- matlab : aa = [1, 2-j; 2+j, 1-j]
aa3c, aa3cx :: SpMatrix (Complex Double)
aa3c = fromListDenseSM 2 [1, 2 :+ 1, 2 :+ (-1), 1 :+ (-1)]

-- matlab : aaxaa = aa * aa
aa3cx = fromListDenseSM 2 [6, 5, 3 :+ (-4), 5:+ (-2)]







{-
matMat

[1, 2] [5, 6] = [19, 22]
[3, 4] [7, 8]   [43, 50]
-}

m1, m2, m1m2, m1', m2', m1m2', m2m1' :: SpMatrix Double
m1 = fromListDenseSM 2 [1,3,2,4]
m2 = fromListDenseSM 2 [5, 7, 6, 8]     
m1m2 = fromListDenseSM 2 [19, 43, 22, 50]

m1' = fromListSM (2,3) [(0,0,2), (1,0,3), (1,2,4), (1,2,1)]
m2' = fromListSM (3,2) [(0,0,5), (0,1,3), (2,1,4)]
m1m2' = fromListDenseSM 2 [10,15,6,13] 
m2m1' = fromListSM (3,3) [(0,0,19),(2,0,12),(0,2,3),(2,2,4)]

-- transposeSM
m1t :: SpMatrix Double
m1t = fromListDenseSM 2 [1,2,3,4]


--

{-
countSubdiagonalNZ
-}
m3 :: SpMatrix Double
m3 = fromListSM (3,3) [(0,2,3),(2,0,4),(1,1,3)] 






{- eigenvalues -}
aa3 :: SpMatrix Double
aa3 = fromListDenseSM 3 [1,1,3,2,2,2,3,1,1]

b3 = mkSpVR 3 [1,1,1] :: SpVector Double



-- aa4 : eigenvalues 1 (mult.=2) and -1
aa4 :: SpMatrix Double
aa4 = fromListDenseSM 3 [3,2,-2,2,2,-1,6,5,-4] 

aa4c :: SpMatrix (Complex Double)
aa4c = toC <$> aa4

b4 = fromListDenseSV 3 [-3,-3,-3] :: SpVector Double






tm0, tm1, tm2, tm3, tm4, tm5, tm6 :: SpMatrix Double
tm0 = fromListSM (2,2) [(0,0,pi), (1,0,sqrt 2), (0,1, exp 1), (1,1,sqrt 5)]

tv0, tv1 :: SpVector Double
tv0 = mkSpVR 2 [5, 6]

tv1 = fromListSV 2 [(0,1)] 

-- wikipedia test matrix for Givens rotation

tm1 = sparsifySM $ fromListDenseSM 3 [6,5,0,5,1,4,0,4,3]

-- wp test matrix for QR decomposition via Givens rotation

tm2 = fromListDenseSM 3 [12, 6, -4, -51, 167, 24, 4, -68, -41]

tm3 = transposeSM $ fromListDenseSM 3 [1 .. 9]



--

tm4 = sparsifySM $ fromListDenseSM 4 [1,0,0,0,2,5,0,10,3,6,8,11,4,7,9,12]


tm5 = fromListDenseSM 3 [2, -4, -4, -1, 6, -2, -2, 3, 8] 


tm6 = fromListDenseSM 4 [1,3,4,2,2,5,2,10,3,6,8,11,4,7,9,12] 

tm7 :: SpMatrix Double
tm7 = a ^+^ b ^+^ c where
  n = 5
  a = mkSubDiagonal n 1 $ replicate n (-1)
  b = mkSubDiagonal n 0 $ replicate n 2
  c = mkSubDiagonal n (-1) $ replicate n (-1)




tm8 :: SpMatrix Double
tm8 = fromListSM (2,2) [(0,0,1), (0,1,1), (1,1,1)]

tm8' :: SpMatrix Double
tm8' = fromListSM (2,2) [(0,0,1), (1,0,1), (1,1,1)]



tm9 :: SpMatrix Double
tm9 = fromListSM (4, 3) [(0,0,pi), (1,1, 3), (2,2,4), (3,2, 1), (3,1, 5)]





-- tvc0 <.> tvc1 = 5 
tvc0, tvc1, tvc2, tvc3 :: SpVector (Complex Double)
tvc0 = fromListSV 2 [(0,0), (1,2 :+ 1)]
tvc1 = fromListSV 2 [(0,0), (1, 2 :+ (-1))] 


-- dot([1+i, 2-i], [3-2i, 1+i]) = 2 - 2i
tvc2 = fromListDenseSV 2 [1 :+ 1,  2 :+ (-1)]
tvc3 = fromListDenseSV 2 [3 :+ (-2), 1 :+ 1 ]






-- l0 = [1,2,4,5,8]
-- l1 = [2,3,6]
-- l2 = [7]

-- v0,v1 :: V.Vector Int
-- v0 = V.fromList [0,1,2,5,6]
-- v1 = V.fromList [0,3,4,6]

-- -- e1, e2 :: V.Vector (Int, Double)
-- -- e1 = V.indexed $ V.fromList [1,0,0]
-- -- e2 = V.indexed $ V.fromList [0,1,0]

-- e1, e2:: CsrVector Double
-- e1 = fromListCV 4 [(0, 1)] 
-- e2 = fromListCV 4 [(1, 1)]
-- e3 = fromListCV 4 [(0, 1 :+ 2)] :: CsrVector (Complex Double)

-- e1c = V.indexed $ V.fromList [1,0,0] :: V.Vector (Int, Complex Double)

-- m0,m1,m2,m3 :: CsrMatrix Double
-- m0 = toCSR 2 2 $ V.fromList [(0,0, pi), (1,0,3), (1,1,2)]
-- m1 = toCSR 4 4 $ V.fromList [(0,0,1), (0,2,5), (1,0,2), (1,1,3), (2,0,4), (2,3,1), (3,2,2)]
-- m2 = toCSR 4 4 $ V.fromList [(0,0,1), (0,2,5), (2,0,4), (2,3,1), (3,2,2)]
-- m3 = toCSR 4 4 $ V.fromList [(1,0,5), (1,1,8), (2,2,3), (3,1,6)]







-- --


-- -- run N iterations 

-- -- runNBiC :: Int -> SpMatrix Double -> SpVector Double -> BICGSTAB
-- runNBiC n aa b = map _xBicgstab $ runAppendN' (bicgstabStep aa x0) n bicgsInit where
--    x0 = mkSpVectorD nd $ replicate nd 0.9
--    nd = dim r0
--    r0 = b ^-^ (aa #> x0)    
--    p0 = r0
--    bicgsInit = BICGSTAB x0 r0 p0

-- -- runNCGS :: Int -> SpMatrix Double -> SpVector Double -> CGS
-- runNCGS n aa b = map _x $ runAppendN' (cgsStep aa x0) n cgsInit where
--   x0 = mkSpVectorD nd $ replicate nd 0.1
--   nd = dim r0
--   r0 = b ^-^ (aa #> x0)    -- residual of initial guess solution
--   p0 = r0
--   u0 = r0
--   cgsInit = CGS x0 r0 p0 u0



-- solveRandomN ndim nsp niter = do
--   aa0 <- randSpMat ndim (nsp ^ 2)
--   let aa = aa0 ^+^ eye ndim
--   xtrue <- randSpVec ndim nsp
--   let b = aa #> xtrue
--       xhatB = head $ runNBiC niter aa b
--       xhatC = head $ runNCGS niter aa b
--   -- printDenseSM aa    
--   return (normSq (xhatB ^-^ xtrue), normSq (xhatC ^-^ xtrue))



{-
random linear system

-}



-- -- dense
-- solveRandom n = do
--   aa0 <- randMat n
--   let aa = aa0 ^+^ eye n
--   xtrue <- randVec n
--   -- x0 <- randVec n
--   let b = aa #> xtrue
--       dx = aa <\> b ^-^ xtrue
--   return $ normSq dx
--   -- let xhatB = _xBicgstab (bicgstab aa b x0 x0)
--   --     xhatC = _x (cgs aa b x0 x0)
--   -- return (aa, x, x0, b, xhatB, xhatC)

-- -- sparse
-- solveSpRandom :: Int -> Int -> IO Double
-- solveSpRandom n nsp = do
--   aa0 <- randSpMat n nsp
--   let aa = aa0 ^+^ eye n
--   xtrue <- randSpVec n nsp
--   let b = (aa ^+^ eye n) #> xtrue
--       dx = aa <\> b ^-^ xtrue
--   return $ normSq dx




-- solveRandomBanded n bw mu sig = do
--   let ndiags = 2*bw
--   bands <- replicateM (ndiags + 1) (randArray n mu sig)
--   xtrue <- randVec n
--   b <- randVec n
--   let
--     diags = [-bw .. bw - 1]

-- randDiagMat :: PrimMonad m =>
--      Rows -> Double -> Double -> Int -> m (SpMatrix Double)
-- randDiagMat n mu sig i = do
--   x <- randArray n mu sig
--   return $ mkSubDiagonal n i x
