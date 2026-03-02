#!/bin/bash

# Check if already sourced
[[ -n "${CFAL_COMMON_SOURCED:-}" ]] && return 0
CFAL_COMMON_SOURCED=1

PACKAGES=(
  accelerate-llvm-new-pipeline
  accelerate-llvm-decoupled
  accelerate-llvm-interleaved
)

# Name of the accelerate-llvm variant that will be displayed in results
declare -A PKG_NAMES=(
  [accelerate-llvm-new-pipeline]="Default"
  [accelerate-llvm-decoupled]="Decoupled"
  [accelerate-llvm-interleaved]="Interleaved"  
)

declare -A PKG_COLORS=(
  [accelerate-llvm-new-pipeline]="#984ea3"
  [accelerate-llvm-decoupled]="#377eb8"
  [accelerate-llvm-interleaved]="#4daf4a"
)

declare -A PKG_POINTTYPE=(
  [accelerate-llvm-new-pipeline]="5"
  [accelerate-llvm-decoupled]="2"
  [accelerate-llvm-interleaved]="4"
)

CRITERION_FLAGS=""

# Thread counts to benchmark
# THREAD_COUNTS=(1 4 8 12 16 20 24 28 32)
THREAD_COUNTS=(6)

parse_flags() {
    TIMER_FALLBACK=""
    DEBUG=""
    RESUME=false
    REPLOT=false
    
    for arg in "$@"; do
        if [[ "$arg" == "--timer-fallback" ]]; then
            TIMER_FALLBACK="ghc-options:
  accelerate: -DTRACY_TIMER_FALLBACK"
        fi
        if [[ "$arg" == "--debug" && -z "$DEBUG" ]]; then
            DEBUG="flags:
  accelerate:
    debug: true"
        fi
        if [[ "$arg" == "--tracy" ]]; then
            DEBUG="flags:
  accelerate:
    debug: true
    tracy: true"
        fi
        if [[ "$arg" == "--resume" ]]; then
            RESUME=true
        fi
        if [[ "$arg" == "--replot" ]]; then
            REPLOT=true
        fi
    done
}

# generate a temporary stack.yaml that pins the current
# accelerate repository and a selected llvm backend branch.
# the generated file is written to ./temp-stack.yaml and removed
# after each bench invocation.
create_temp_stack_yaml() {
    local pkg="$1"           # branch directory under acc-branches
    local extra_packages="$2"
    local extra_deps="$3"
    local extra_flags="$4"

    parse_flags "$@"

    cat > temp-stack.yaml <<EOF
# use the same resolver as the repository's own stack.yaml
snapshot:
  url: https://raw.githubusercontent.com/commercialhaskell/stackage-snapshots/master/lts/24/32.yaml

$extra_flags

packages:
- .
- ../acc-branches/accelerate            # core accelerate library
- ../acc-branches/$pkg/accelerate-llvm
- ../acc-branches/$pkg/accelerate-llvm-native
$extra_packages

extra-deps:
- monadLib-3.10.3@sha256:026ba169762e63f0fe5f5c78829808f522a28730043bc3ad9b7c146baedf709f,637
- github: tomsmeding/llvm-pretty
  commit: a253a7fc1c62f4825ffce6b2507eebc5dadff32c
- MIP-0.2.0.0
- OptDir-0.0.4
- bytestring-encoding-0.1.2.0
- acme-missiles-0.3
- git: https://github.com/commercialhaskell/stack.git
  commit: e7b331f14bcffb8367cd58fbfc8b40ec7642100a
$extra_deps

$TIMER_FALLBACK

$DEBUG
EOF
}

bench() {
    local bench_name="$1"
    local extra_packages="$2"
    local extra_deps="$3"
    local extra_flags="$4"
    local criterion_flags="$5"

    parse_flags "$@"

    mkdir -p results

    # Plot not yet working
    # if [ "$REPLOT" = true ]; then
    #   # Remove old plots
    #   rm -f results/benchmark_*.svg
    #   plot_all
    #   return 0
    # fi

    if [ "$RESUME" = false ]; then
      # Remove old results files
      rm -f results/results-*.csv
      rm -f results/benchmark_*.csv
      rm -f results/benchmark_*.svg
    fi

    if [ "$RESUME" = true ]; then
      # Check if results/results-*.csv files exist
      results_files=$(ls results/results-*.csv 2>/dev/null)
      # Check if results/benchmark_*.csv files exist
      benchmark_files=$(ls results/benchmark_*.csv 2>/dev/null)
      if [ -z "$results_files" ] && [ -n "$benchmark_files" ]; then
        echo "Skipping benchmark $bench_name, results already exist."
        return 0
      fi
    fi


    for pkg in "${PACKAGES[@]}"; do
      name="${PKG_NAMES[$pkg]}"
      
      echo "Benching $name"

      # Create temp stack.yaml for this backend variant
      create_temp_stack_yaml "$pkg" "$extra_packages" "$extra_deps" "$extra_flags" "$@" > temp-stack.yaml

      # Change this to size mayhaps instead of threadss
      for threads in "${THREAD_COUNTS[@]}"; do
        if [ "$RESUME" = true ] && [ -f "results/results-$name-$threads.csv" ]; then
          echo "Skipping $name with $threads threads, already exists"
          continue
        fi

        echo "Benching with $threads threads"
        
        # Create temp file for results
        temp_result_file=$(mktemp "/tmp/results-$name-$threads.XXXXXX.csv")
        result_file="results/results-$name-$threads.csv"

        # Set thread count and run benchmark, change this cmd to use size or smth
        export ACCELERATE_LLVM_NATIVE_THREADS=$threads
        # use "stack bench" because our package defines a benchmark stanza,
    # not an executable. bench_name should be the name of the benchmark
    # target ("micro-benchmarks").
    # run all benchmarks in the project using the temporary config
    # (we don't need to specify a target because there is only one
    # package in this repository)
    if STACK_YAML=temp-stack.yaml stack bench \
            --benchmark-arguments="--csv $temp_result_file $criterion_flags $CRITERION_FLAGS"; then
          mv "$temp_result_file" "$result_file"
        else
          rm -f "$temp_result_file"
          echo "Benchmark failed for $name with $threads threads"
          continue
        fi

        # Add thread count column to CSV
        if [ -f "$result_file" ]; then

          while IFS= read -r line; do
            line=$(echo "$line" | tr -d '\n\r')
            # Skip header line
            if [[ $line == "Name,Mean,MeanLB,MeanUB,Stddev,StddevLB,StddevUB"* ]]; then
                continue
            fi
            
            # Skip empty lines
            [[ -z "$line" ]] && continue
            
            # Extract benchmark name (first field)
            if [[ $line =~ ^\"([^\"]*)\", ]]; then
                # In case the name is in quotes
                benchmark_name="${BASH_REMATCH[1]}"
            elif [[ $line =~ ^([^,]*), ]]; then
                # In case the name is without quotes, stop at ','
                benchmark_name="${BASH_REMATCH[1]}"
            else
                echo "Error: Unable to parse benchmark name from line: $line" >&2
                exit 1
            fi
            
            file_name=$(echo "$benchmark_name" | sed 's/\//_/g' | sed 's/ /_/g')
            output_file="results/benchmark_${file_name}.csv"
            
            # Create header if this is the first time writing to this file
            if [ ! -f "$output_file" ]; then
                echo "Name,Mean,MeanLB,MeanUB,Stddev,StddevLB,StddevUB,scheduler,threads" > "$output_file"
            fi
            
            # Add the data line with package name and thread count
            printf "%s,%s,%s\n" "$line" "$name" "$threads" >> "$output_file"
        done < "$result_file"
      fi
      done

      rm temp-stack.yaml
    done

    # Clean up results files
    rm -f results/results-*-*.csv

    echo "Benchmarks results saved in results folder"

    unset ACCELERATE_LLVM_NATIVE_THREADS

    # Make pretty plots for all results
    # plot_all
}

# Not yet implemented
# plot_all() {
#   echo "Generating plots..."
#   for csv_file in results/benchmark_*.csv; do
#     if [ -f "$csv_file" ]; then
#       plot "$csv_file"
#     fi
#   done
#   echo "Plots saved in results folder"
# }

# plot() {
#   local csv_file="$1"

#   # Check if file exists
#   if [ ! -f "$csv_file" ]; then
#       echo "Error: File '$csv_file' not found!"
#       exit 1
#   fi

#   basename=$(basename "$csv_file" .csv)
#   path=$(dirname "$csv_file")
#   output_file="${path}/${basename}.svg"

#   # Extract title information from filename
#   title=$(echo "$basename" | sed 's/_/ /g' | sed 's/benchmark //')

#   # Create temporary data files for each scheduler
#   declare -a data_files
#   declare -a plot_commands

#   for pkg in "${PACKAGES[@]}"; do
#     name="${PKG_NAMES[$pkg]}"
#     color="${PKG_COLORS[$pkg]}"
#     pointtype="${PKG_POINTTYPE[$pkg]}"

#     data_file=$(mktemp)
#     data_files+=("$data_file")

#     awk -v FPAT='[^,]*|("([^"]|"")*")' -v OFS=',' -v sched="$name" \
#         'NR>1 && NF>=9 && $8==sched { print $9, $2, $5 }' "$csv_file" > "$data_file"

#     plot_commands+=("'$data_file' using 1:2:3 with errorbars linecolor rgb '$color' linewidth 2 pointtype $pointtype pointsize 1.2 title \"$name\"")
#     plot_commands+=("'$data_file' using 1:2 with linespoints linecolor rgb '$color' linewidth 2 pointtype $pointtype pointsize 1.2 notitle")

#   done

#   gnuplot_script=$(mktemp)

#   cat > "$gnuplot_script" << EOF
#   set terminal svg size 1200,800 enhanced font 'Arial,12'
#   set output '$output_file'

#   set title "$title Performance Comparison" font 'Arial,14'
#   set xlabel "Number of Threads"
#   set ylabel "Mean Execution Time (seconds)"

#   set grid
#   set key top right

#   set lmargin 10
#   set rmargin 3
#   set tmargin 3
#   set bmargin 5

#   set xrange [${THREAD_COUNTS[0]}:${THREAD_COUNTS[-1]}]
#   set yrange [0:*]
#   set xtics ($(IFS=', '; echo "${THREAD_COUNTS[*]}"))

#   set datafile sep ','
#   # Plot using temporary data files
#   plot $(IFS=', \\'; echo "${plot_commands[*]}")


# EOF

#   # Run gnuplot
#   if command -v gnuplot >/dev/null 2>&1; then
#       gnuplot "$gnuplot_script"
#   else
#       echo "Error: gnuplot not found. Please install gnuplot first."
#       echo "On Ubuntu/Debian: sudo apt install gnuplot"
#       exit 1
#   fi

#     rm "$gnuplot_script" "${data_files[@]}"
# }