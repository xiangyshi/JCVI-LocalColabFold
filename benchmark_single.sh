#!/bin/bash

# Check if correct number of arguments provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <test_number> <mode>"
    echo "Example: $0 5 gpu"
    echo "Mode must be either 'gpu' or 'cpu'"
    exit 1
fi

# -------- Configuration --------
TEST_NUM="$1"
MODE=$(echo "$2" | tr '[:upper:]' '[:lower:]')  # Convert to lowercase
INPUT_DIR="test_inputs"
RESULTS_ROOT="results_benchmark"
CSV_FILE="benchmark.csv"
FASTA_FILE="$INPUT_DIR/test${TEST_NUM}.fasta"

# Validate mode
if [[ "$MODE" != "gpu" && "$MODE" != "cpu" ]]; then
    echo "Error: Mode must be either 'gpu' or 'cpu'"
    exit 1
fi

# Validate test file exists
if [ ! -f "$FASTA_FILE" ]; then
    echo "Error: Test file $FASTA_FILE does not exist"
    exit 1
fi

# ColabFold parameters (same as original script)
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

# -------- Main Execution --------
init_csv

# Clean up previous results
rm -rf "$RESULTS_ROOT"/*

# Set output directory
OUTDIR="$RESULTS_ROOT/test${TEST_NUM}_${MODE}"

# Switch GPU mode using toggle script
if [[ "$MODE" == "gpu" ]]; then
    source toggle_gpu.sh on > /dev/null 2>&1
    MODE_UPPER="GPU"
else
    source toggle_gpu.sh off > /dev/null 2>&1
    MODE_UPPER="CPU"
fi

print_msg "34" "=== Running test${TEST_NUM} in ${MODE_UPPER} mode ==="

# Run the prediction
mkdir -p "$OUTDIR"
start=$(date +%s)
colabfold_batch "$FASTA_FILE" "$OUTDIR" "${COLABFOLD_PARAMS[@]}"
exit_code=$?
end=$(date +%s)
duration=$((end - start))

# Log results
echo "$start,$FASTA_FILE,$MODE_UPPER,$(protein_length "$FASTA_FILE"),$duration,$exit_code,$OUTDIR" >> "$CSV_FILE"

# User feedback
if [[ $exit_code -eq 0 ]]; then
    print_msg "32" "[$MODE_UPPER] test${TEST_NUM}.fasta completed in $duration s"
else
    print_msg "31" "[$MODE_UPPER] test${TEST_NUM}.fasta failed (exit $exit_code) in $duration s"
fi 