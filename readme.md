Setting up the benchmarks (Not needed when using the .zip file):

From my github (https://github.com/miloravi/accelerate-llvm) clone these branches in this repository as such:
- acc-branches
    | - accelerate
    | - accelerate-llvm-new-pipeline (from branch accelerate-llvm/new-pipeline)
    | - accelerate-llvm-decoupled (from branch accelerate-llvm/Decoupled-scan)
    | - accelerate-llvm-interleaved (from branch accelerate-llvm/Decoupled-half-sized-scan)
- benchmarking

______________________
Running the benchmarks:
Change "THREAD_COUNTS" in accelerate_conf.sh to match your hardware

Run following commands from the benchmarking directory:
chmod +x bench_accelerate.sh
./bench_accelerate.sh