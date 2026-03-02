@ -1,18 +0,0 @@
{-# LANGUAGE BangPatterns #-}

import Criterion
import Criterion.Main
import qualified Accelerate as A
import qualified Accelerate.LLVM.Native as CPU

-- Simple example function to benchmark
fib :: Int -> Int
fib 0 = 0
fib 1 = 1
fib n = fib (n-1) + fib (n-2)

main :: IO ()
main = defaultMain
  [ bgroup "fibonacci"
      [ bench "fib 10" $ whnf fib 10
      , bench "fib 15" $ whnf fib 15
      , bench "fib 20" $ whnf fib 20
      ]
  ]