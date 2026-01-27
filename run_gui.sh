#!/bin/bash
#
# Run script for Design2GarmentCode GUI
# Usage: ./run_gui.sh [--port PORT] [--host HOST]
#

set -e

# Default values
PORT="${PORT:-8080}"
HOST="${HOST:-0.0.0.0}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            PORT="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --port PORT    Port to run the GUI on (default: 8080)"
            echo "  --host HOST    Host address (default: 0.0.0.0)"
            echo "  -h, --help     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Conda environment Python path
CONDA_PYTHON="/opt/homebrew/Caskroom/miniconda/base/envs/d2g/bin/python"

# Check if conda environment exists
if [[ ! -f "$CONDA_PYTHON" ]]; then
    echo "ERROR: Conda environment 'd2g' not found at expected location."
    echo "Expected: $CONDA_PYTHON"
    echo ""
    echo "Please run the setup script first:"
    echo "  ./setup_conda_env.sh --default-channels"
    exit 1
fi

# Check if model weights exist
MODEL_WEIGHTS="$SCRIPT_DIR/lmm_utils/Qwen/qwen2vl_lora_mlp/model.pth"
if [[ ! -f "$MODEL_WEIGHTS" ]]; then
    echo "WARNING: Fine-tuned model weights not found at $MODEL_WEIGHTS"
    echo "The GUI may not work correctly without them."
    echo ""
fi

echo "============================================"
echo "  Design2GarmentCode GUI"
echo "============================================"
echo ""
echo "Starting server on http://$HOST:$PORT"
echo "Press Ctrl+C to stop"
echo ""

# Run the GUI
exec "$CONDA_PYTHON" "$SCRIPT_DIR/gui.py" --host "$HOST" --port "$PORT"
