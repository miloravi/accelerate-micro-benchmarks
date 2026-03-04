{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE FlexibleContexts    #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeOperators       #-}

import Criterion
import Criterion.Main
import qualified Data.Array.Accelerate as A
import qualified Data.Array.Accelerate.LLVM.Native as CPU

-- import qualified Control.Concurrent
-- import qualified Prelude

simpleScanlAcc :: CPU.Acc (A.Array A.DIM1 Int) -> CPU.Acc (A.Vector Int)
simpleScanlAcc _ =
  A.scanl1 (+) (A.use (A.fromList (A.Z A.:. 32) [1..1024]))



main :: IO ()
main = do
  let run = CPU.runN simpleScanlAcc
  defaultMain
    [ bgroup "simpleScan" 
        [ bench "scanl1" $ nf run (A.fromList (A.Z A.:. 0) []) ] -- Empty input is needed to make benchmarks run
    ]