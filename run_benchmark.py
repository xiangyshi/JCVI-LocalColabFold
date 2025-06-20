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
    for i in range(1, 8):
        run_benchmark(f"{i}", 'gpu') 