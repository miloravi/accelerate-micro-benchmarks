Setting up the benchmarks (Not needed when using the .zip file):

From my github (https://github.com/miloravi/accelerate-llvm) clone these branches in this repository as such:
- acc-branches
    | - accelerate
    | - accelerate-llvm-new-pipeline (from branch accelerate-llvm/new-pipeline)
    | - accelerate-llvm-decoupled (from branch accelerate-llvm/Decoupled-scan)
    | - accelerate-llvm-interleaved (from branch accelerate-llvm/Decoupled-half-sized-scan)
    | - accelerate-llvm-interleaved-half-sized (from branch accelerate-llvm/Decoupled-half-sized-scan)
- benchmarking

For the branch "accelerate-llvm-interleaved", the tile size on line 127 should be changed from 1024 -> 1024 * 2
This can be done in the codegen file 
- cd "acc-branches/accelerate-llvm-interleaved/accelerate-llvm-native/src/Data/Array/Accelerate/LLVM/Native/CodeGen.hs"
______________________
Running the benchmarks:
Change "THREAD_COUNTS" in accelerate_conf.sh to match your hardware

Run following commands from the benchmarking directory:
chmod +x bench_accelerate.sh
./bench_accelerate.sh