#!/bin/bash

# Can add more benchmarks here
(cd "benchmarks" && bash bench.sh "$@") || { echo "Failed to bench MG"; exit 1; }