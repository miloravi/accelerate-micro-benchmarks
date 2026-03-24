{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators       #-}

import Criterion
import Criterion.Main
import qualified Data.Array.Accelerate as A
import qualified Data.Array.Accelerate.LLVM.Native as CPU

-- Unfused fold
simpleFoldAcc :: CPU.Acc (A.Array A.DIM1 Int) -> CPU.Acc (A.Scalar Int)
simpleFoldAcc _ =
    A.fold (+) 0 (A.use (A.fromList (A.Z A.:. 67108864) [1..67108864]))

-- Generate fused into fold
generateFoldAcc :: CPU.Acc (A.Array A.DIM1 Int) -> CPU.Acc (A.Scalar Int)
generateFoldAcc _ =
    A.fold (+) 0 (A.generate (A.index1 67108864) (\ix -> A.unindex1 ix + 1))

-- Incredibly computationally heavy scan with smaller input size to keep runtime reasonable
computeBoundFoldAcc :: CPU.Acc (A.Array A.DIM1 Float) -> CPU.Acc (A.Scalar Float)
computeBoundFoldAcc _ =
    A.fold heavy 0 (A.generate (A.index1 67108864)
        (\ix -> A.fromIntegral (A.unindex1 ix) + 1))
  where
    heavy x y =
        let s = x + y
        in  A.sin s
            + A.cos s
            + A.sin (s * 1.1)
            + A.cos (s * 1.2)
            + A.sin (s * 1.3)
            + A.cos (s * 1.4)
            + A.sin (s * 1.5)
            + A.cos (s * 1.6)
            + A.sin (s * 1.7)
            + A.cos (s * 1.8)

-- Imbalanced computational scan by performing redundant work only on even sums
imbalancedFoldAcc :: CPU.Acc (A.Array A.DIM1 Float) -> CPU.Acc (A.Scalar Float)
imbalancedFoldAcc _ =
    A.fold heavy 0 (A.generate (A.index1 67108864)
        (\ix -> A.fromIntegral (A.unindex1 ix) + 1))
  where 
    heavy x y =
        let s = x + y
            extra = A.cond (A.even (A.truncate s :: A.Exp A.Int32))
                            (A.sin s)
                            (0 :: A.Exp Float)
        in s + extra * 0

main :: IO ()
main = do
    let runSimple = CPU.runN simpleFoldAcc
    let runGenerateFold = CPU.runN generateFoldAcc
    let runComputeBoundFold = CPU.runN computeBoundFoldAcc
    let runImbalancedFold = CPU.runN imbalancedFoldAcc
    defaultMain -- Empty input is needed to make benchmarks run, as the actual input is generated inside the Accelerate computation
        [   bgroup "Prefix-sum Scan (n = 67M)" 
                [ bench "scanl1" $ nf runSimple (A.fromList (A.Z A.:. 0) []) ]
        ,   bgroup "Generate fused into Scan (n = 67M)"
                [ bench "generate" $ nf runGenerateFold (A.fromList (A.Z A.:. 0) []) ]
        ,   bgroup "Compute-bound scan (n = 67M)"
                [ bench "computeBound" $ nf runComputeBoundFold (A.fromList (A.Z A.:. 0) []) ]
        ,   bgroup "Imbalanced scan (n = 67M)"
                [ bench "imbalanced" $ nf runImbalancedFold (A.fromList (A.Z A.:. 0) []) ]
        ]
    