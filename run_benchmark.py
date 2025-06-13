#!/usr/bin/env python3
import subprocess
import sys

def run_benchmark(test_num, mode):
    try:
        # Run the benchmark script with test1 and gpu mode
        result = subprocess.run(['./benchmark_single.sh', test_num, mode], 
                              check=True,
                              text=True,
                              capture_output=True)
        
        # Print the output
        print(result.stdout)
        
    except subprocess.CalledProcessError as e:
        print(f"Error running benchmark: {e}")
        print(f"Error output: {e.stderr}")
        sys.exit(1)

if __name__ == "__main__":
    for i in range(10):
        print(f"Running benchmark {i+1} of 10")
        run_benchmark("6", 'cpu') 
        run_benchmark("7", 'cpu') 