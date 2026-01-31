#!/bin/bash
# Start the Design2GarmentCode GUI on RunPod

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Activate conda environment
source "$(conda info --base)/etc/profile.d/conda.sh" 2>/dev/null || source ~/miniconda3/etc/profile.d/conda.sh
conda activate d2g

# Default port
PORT="${1:-8080}"

echo "Starting Design2GarmentCode GUI on port $PORT..."
echo "Access at: http://0.0.0.0:$PORT"
echo ""

python gui.py --host 0.0.0.0 --port "$PORT"
