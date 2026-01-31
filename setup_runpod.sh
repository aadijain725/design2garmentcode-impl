#!/bin/bash
# RunPod Setup Script for Design2GarmentCode
# This script sets up the environment and downloads required models

set -e

echo "========================================"
echo "Design2GarmentCode RunPod Setup"
echo "========================================"

# Check if running with GPU
if ! command -v nvidia-smi &> /dev/null; then
    echo "WARNING: nvidia-smi not found. GPU may not be available."
else
    echo "GPU detected:"
    nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Install miniconda if not present
if ! command -v conda &> /dev/null; then
    echo ""
    echo "Installing Miniconda..."
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
    bash /tmp/miniconda.sh -b -p $HOME/miniconda3
    rm /tmp/miniconda.sh
    export PATH="$HOME/miniconda3/bin:$PATH"
    conda init bash
    source ~/.bashrc
    echo "Miniconda installed successfully!"
fi

# Create conda environment
echo ""
echo "Creating conda environment 'd2g'..."
if conda env list | grep -q "^d2g "; then
    echo "Environment 'd2g' already exists. Updating..."
    conda env update -f environment_runpod.yml
else
    conda env create -f environment_runpod.yml
fi

# Activate environment
source "$(conda info --base)/etc/profile.d/conda.sh"
conda activate d2g

# Create necessary directories
echo ""
echo "Creating directories..."
mkdir -p lmm_utils/Qwen/Qwen2-VL-2B-Instruct
mkdir -p lmm_utils/Qwen/qwen2vl_lora_mlp
mkdir -p Logs
mkdir -p outputs

# Download Qwen2-VL-2B-Instruct model
echo ""
echo "Downloading Qwen2-VL-2B-Instruct model..."
if [ ! -f "lmm_utils/Qwen/Qwen2-VL-2B-Instruct/config.json" ]; then
    python -c "
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id='Qwen/Qwen2-VL-2B-Instruct',
    local_dir='lmm_utils/Qwen/Qwen2-VL-2B-Instruct',
    local_dir_use_symlinks=False
)
print('Qwen2-VL-2B-Instruct downloaded successfully!')
"
else
    echo "Qwen2-VL-2B-Instruct already downloaded."
fi

# Download fine-tuned weights
echo ""
echo "Downloading fine-tuned weights..."
if [ ! -f "lmm_utils/Qwen/qwen2vl_lora_mlp/model.pth" ]; then
    # Google Drive file ID: 1CL7OLUq6fYcwoDuLRkBxtKNxJ0_G73U-
    pip install -q gdown
    gdown --id 1CL7OLUq6fYcwoDuLRkBxtKNxJ0_G73U- -O lmm_utils/Qwen/qwen2vl_lora_mlp/model.pth
    echo "Fine-tuned weights downloaded successfully!"
else
    echo "Fine-tuned weights already downloaded."
fi

# Check for OpenAI API key
echo ""
if [ -z "$OPENAI_API_KEY" ]; then
    echo "WARNING: OPENAI_API_KEY environment variable is not set."
    echo "You can set it with: export OPENAI_API_KEY='your-api-key'"
    echo "Or edit system.json to add your API key."
else
    echo "OpenAI API key detected in environment."
fi

echo ""
echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "To start the GUI, run:"
echo "  conda activate d2g"
echo "  python gui.py --host 0.0.0.0 --port 8080"
echo ""
echo "Then access the GUI at: http://localhost:8080"
echo "(On RunPod, use your pod's public URL with port 8080)"
echo ""
