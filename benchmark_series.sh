#!/bin/bash

# Benchmark multiple FASTA files in test_inputs/ using ColabFold
# Runs each file twice (GPU and CPU) and logs timing data to benchmark.csv

# -------- Configuration --------
INPUT_DIR="test_inputs"                # Directory containing FASTA files
RESULTS_ROOT="results_benchmark"      # Root directory to store outputs
CSV_FILE="benchmark.csv"               # CSV log file

# ColabFold parameters (edit as needed)
COLABFOLD_PARAMS=(
  "--msa-mode" "mmseqs2_uniref_env"
  "--pair-mode" "unpaired_paired"
  "--model-type" "auto"
  "--num-recycle" "3"
  "--num-models" "1"
  "--pair-strategy" "greedy"
  "--num-seeds" "1"
  "--relax-max-iterations" "200"
  "--stop-at-score" "100"
)

# -------- Helper Functions --------
print_msg() { # color message
  local color="$1"; shift
  printf "\033[${color}m%s\033[0m\n" "$*"
}

init_csv() {
  if [[ ! -f "$CSV_FILE" ]]; then
    echo "timestamp,file,mode,aa_length,duration_seconds,exit_code,output_dir" > "$CSV_FILE"
    print_msg "32" "✓ Created CSV header: $CSV_FILE"
  fi
}

protein_length() {
  local fasta="$1"
  grep -v '^>' "$fasta" | tr -d '\n ' | wc -c
}

run_single() {
  local mode="$1"  # GPU or CPU
  local fasta="$2"
  local outdir="$3"

  # Switch GPU mode using toggle script
  if [[ "$mode" == "GPU" ]]; then
    source toggle_gpu.sh on > /dev/null 2>&1
  else
    source toggle_gpu.sh off > /dev/null 2>&1
  fi

  mkdir -p "$outdir"
  local start=$(date +%s)
  colabfold_batch "$fasta" "$outdir" "${COLABFOLD_PARAMS[@]}"
  local exit_code=$?
  local end=$(date +%s)
  local duration=$((end - start))
  echo "$start,$fasta,$mode,$(protein_length "$fasta"),$duration,$exit_code,$outdir" >> "$CSV_FILE"

  # User feedback
  if [[ $exit_code -eq 0 ]]; then
    print_msg "32" "[$mode] $(basename "$fasta") completed in $duration s"
  else
    print_msg "31" "[$mode] $(basename "$fasta") failed (exit $exit_code) in $duration s"
  fi
}

# -------- Main Execution --------
init_csv

print_msg "36" "Starting benchmark on directory: $INPUT_DIR"

for fasta in "$INPUT_DIR"/*.fasta; do
  if [[ ! -f "$fasta" ]]; then
    print_msg "33" "No FASTA files found in $INPUT_DIR, skipping."
    break
  fi
  base=$(basename "$fasta" .fasta)
  print_msg "34" "\n=== Processing $base ==="

  run_single "GPU" "$fasta" "$RESULTS_ROOT/${base}_gpu"
  run_single "CPU" "$fasta" "$RESULTS_ROOT/${base}_cpu"

done

print_msg "32" "\nBenchmark complete. Results saved to $CSV_FILE" 