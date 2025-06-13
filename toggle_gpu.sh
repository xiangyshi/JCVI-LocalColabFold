#!/bin/bash

# LocalColabFold GPU Toggle Script
# Usage: source toggle_gpu.sh [command]
# Commands: toggle, on, off, status

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check current GPU status
check_gpu_status() {
    if [[ "${JAX_PLATFORMS}" == "cpu" ]]; then
        # JAX forced to CPU mode
        echo "GPU_DISABLED"
    elif [[ -z "${CUDA_VISIBLE_DEVICES+x}" ]] && [[ -z "${JAX_PLATFORMS+x}" ]]; then
        # No GPU restrictions set
        echo "GPU_ENABLED"
    elif [[ "${CUDA_VISIBLE_DEVICES}" == "" ]]; then
        # CUDA devices hidden
        echo "GPU_DISABLED" 
    else
        # Specific GPU configuration
        echo "GPU_SELECTIVE"
    fi
}

# Function to show current status
show_status() {
    local status=$(check_gpu_status)
    echo -e "\n${BLUE}=== LocalColabFold GPU Status ===${NC}"
    
    case $status in
        "GPU_ENABLED")
            echo -e "Current mode: ${GREEN}GPU ENABLED${NC} (all GPUs available)"
            echo "JAX_PLATFORMS is unset, CUDA_VISIBLE_DEVICES is unset"
            ;;
        "GPU_DISABLED")
            if [[ "${JAX_PLATFORMS}" == "cpu" ]]; then
                echo -e "Current mode: ${RED}CPU ONLY${NC} (JAX forced to CPU)"
                echo "JAX_PLATFORMS=\"cpu\""
            else
                echo -e "Current mode: ${RED}CPU ONLY${NC} (CUDA devices hidden)"
                echo "CUDA_VISIBLE_DEVICES=\"\""
            fi
            ;;
        "GPU_SELECTIVE")
            echo -e "Current mode: ${YELLOW}SELECTIVE GPU${NC} (specific GPUs: ${CUDA_VISIBLE_DEVICES})"
            echo "CUDA_VISIBLE_DEVICES=\"${CUDA_VISIBLE_DEVICES}\""
            ;;
    esac
    echo ""
}

# Function to enable GPU
enable_gpu() {
    unset CUDA_VISIBLE_DEVICES
    unset JAX_PLATFORMS
    echo -e "${GREEN}✓ GPU mode ENABLED${NC}"
    echo "ColabFold will use GPU acceleration"
}

# Function to disable GPU (force CPU)
disable_gpu() {
    export JAX_PLATFORMS="cpu"
    export CUDA_VISIBLE_DEVICES=""
    echo -e "${RED}✓ GPU mode DISABLED${NC}"
    echo "ColabFold will run on CPU only (JAX_PLATFORMS=cpu)"
}

# Function to toggle GPU state
toggle_gpu() {
    local status=$(check_gpu_status)
    
    case $status in
        "GPU_ENABLED"|"GPU_SELECTIVE")
            disable_gpu
            ;;
        "GPU_DISABLED")
            enable_gpu
            ;;
    esac
}

# Function to set specific GPU(s)
set_gpu() {
    local gpu_ids="$1"
    if [[ -z "$gpu_ids" ]]; then
        echo -e "${RED}Error: Please specify GPU ID(s)${NC}"
        echo "Example: set_gpu 0 or set_gpu 0,1"
        return 1
    fi
    
    unset JAX_PLATFORMS  # Allow JAX to use GPU
    export CUDA_VISIBLE_DEVICES="$gpu_ids"
    echo -e "${YELLOW}✓ GPU mode set to specific GPUs: ${gpu_ids}${NC}"
    echo "ColabFold will use GPU(s): $gpu_ids"
}

# Function to run ColabFold with current settings
run_colabfold() {
    if [[ $# -lt 2 ]]; then
        echo -e "${RED}Error: Please provide input and output directory${NC}"
        echo "Usage: run_colabfold input.fasta output_dir [additional_flags]"
        return 1
    fi
    
    local input="$1"
    local output="$2"
    shift 2
    local additional_flags="$@"
    
    echo -e "${BLUE}Running ColabFold with current GPU settings...${NC}"
    show_status
    
    colabfold_batch "$input" "$output" $additional_flags
}

# Main script logic
case "${1:-toggle}" in
    "toggle"|"t")
        toggle_gpu
        show_status
        ;;
    "on"|"enable"|"gpu")
        enable_gpu
        show_status
        ;;
    "off"|"disable"|"cpu")
        disable_gpu
        show_status
        ;;
    "status"|"s")
        show_status
        ;;
    "set")
        set_gpu "$2"
        show_status
        ;;
    "run")
        shift
        run_colabfold "$@"
        ;;
    "help"|"h"|"-h"|"--help")
        echo -e "${BLUE}LocalColabFold GPU Toggle Script${NC}"
        echo ""
        echo "Usage: source toggle_gpu.sh [command] [options]"
        echo ""
        echo "Commands:"
        echo "  toggle, t         Toggle between GPU and CPU mode"
        echo "  on, enable, gpu   Enable GPU mode (default)"
        echo "  off, disable, cpu Disable GPU (CPU only)"
        echo "  set <gpu_ids>     Use specific GPU(s) (e.g., '0' or '0,1')"
        echo "  status, s         Show current GPU status"
        echo "  run <input> <output> [flags]  Run ColabFold with current settings"
        echo "  help, h           Show this help message"
        echo ""
        echo "Examples:"
        echo "  source toggle_gpu.sh toggle    # Toggle GPU mode"
        echo "  source toggle_gpu.sh off       # Force CPU mode"
        echo "  source toggle_gpu.sh set 0     # Use only GPU 0"
        echo "  source toggle_gpu.sh run input.fasta results/ --amber"
        echo ""
        echo "Note: Use 'source' to run this script so environment variables persist"
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Use 'source toggle_gpu.sh help' for usage information"
        ;;
esac 