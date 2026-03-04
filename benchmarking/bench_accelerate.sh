#!/bin/bash

# Can add more benchmarks here
(cd "simpleScan/accelerate" && bash bench.sh "$@") || { echo "Failed to bench simpleScan"; exit 1; }