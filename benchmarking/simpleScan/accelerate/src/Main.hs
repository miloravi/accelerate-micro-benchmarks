{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators       #-}

import Criterion
import Criterion.Main
import qualified Data.Array.Accelerate as A
import qualified Data.Array.Accelerate.LLVM.Native as CPU

-- Unfused scan
simpleScanlAcc :: CPU.Acc (A.Array A.DIM1 Int) -> CPU.Acc (A.Vector Int)
simpleScanlAcc _ =
    A.scanl1 (+) (A.use (A.fromList (A.Z A.:. 67108864) [1..67108864]))

-- Generate fused into scan
generateScanAcc :: CPU.Acc (A.Array A.DIM1 Int) -> CPU.Acc (A.Vector Int)
generateScanAcc _ =
    A.scanl1 (+) (A.generate (A.index1 67108864) (\ix -> A.unindex1 ix + 1))

-- Incredibly computationally heavy scan with smaller input size to keep runtime reasonable
computeBoundScanAcc :: CPU.Acc (A.Array A.DIM1 Float) -> CPU.Acc (A.Vector Float)
computeBoundScanAcc _ = A.scanl1 heavy (A.generate (A.index1 67108864) (\ix -> A.fromIntegral (A.unindex1 ix) + 1))
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
imbalancedScanAcc :: CPU.Acc (A.Array A.DIM1 Float) -> CPU.Acc (A.Vector Float)
imbalancedScanAcc _ = A.scanl1 heavy (A.generate (A.index1 67108864) (\ix -> A.fromIntegral (A.unindex1 ix) + 1))
  where 
    heavy x y =
        let s = x + y
            extra = A.cond (A.even (A.truncate s :: A.Exp A.Int32)) (A.sin s) (0 :: A.Exp Float)
        in s + extra * 0

main :: IO ()
main = do
    let runSimple = CPU.runN simpleScanlAcc
    let runGenerateScan = CPU.runN generateScanAcc
    let runComputeBoundScan = CPU.runN computeBoundScanAcc
    let runImbalancedScan = CPU.runN imbalancedScanAcc
    defaultMain -- Empty input is needed to make benchmarks run, as the actual input is generated inside the Accelerate computation
        [   bgroup "Prefix-sum Scan (n = 67M)" 
                [ bench "scanl1" $ nf runSimple (A.fromList (A.Z A.:. 0) []) ]
        ,   bgroup "Generate fused into Scan (n = 67M)"
                [ bench "generate" $ nf runGenerateScan (A.fromList (A.Z A.:. 0) []) ]
        ,   bgroup "Compute-bound scan (n = 67M)"
                [ bench "computeBound" $ nf runComputeBoundScan (A.fromList (A.Z A.:. 0) []) ]
        ,   bgroup "Imbalanced scan (n = 67M)"
                [ bench "imbalanced" $ nf runImbalancedScan (A.fromList (A.Z A.:. 0) []) ]
        ]
    