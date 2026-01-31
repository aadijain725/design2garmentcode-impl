#!/bin/bash
# RunPod Setup Script for Design2GarmentCode
# This script sets up the environment and downloads required models
# Usage: ./setup_runpod.sh [--skip-models]

set -e

SKIP_MODELS=0
for arg in "$@"; do
    case $arg in
        --skip-models) SKIP_MODELS=1 ;;
    esac
done

echo "========================================"
echo "Design2GarmentCode RunPod Setup"
echo "========================================"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Check if running with GPU
echo "[1/6] Checking GPU..."
if command -v nvidia-smi &> /dev/null; then
    GPU_INFO=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo "Unknown")
    echo "  ✓ GPU: $GPU_INFO"
else
    echo "  ⚠ WARNING: nvidia-smi not found. GPU may not be available."
fi

# Install miniconda if not present
echo ""
echo "[2/6] Setting up Miniconda..."
if ! command -v conda &> /dev/null; then
    echo "  Installing Miniconda..."
    wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh
    bash /tmp/miniconda.sh -b -p $HOME/miniconda3
    rm /tmp/miniconda.sh
    export PATH="$HOME/miniconda3/bin:$PATH"

    # Initialize conda
    $HOME/miniconda3/bin/conda init bash 2>/dev/null || true
    source $HOME/miniconda3/etc/profile.d/conda.sh

    echo "  ✓ Miniconda installed"
else
    echo "  ✓ Miniconda already installed"
    # Ensure conda is in path
    if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
        source "$HOME/miniconda3/etc/profile.d/conda.sh"
    elif [ -f "/opt/conda/etc/profile.d/conda.sh" ]; then
        source "/opt/conda/etc/profile.d/conda.sh"
    elif [ -f "/root/miniconda3/etc/profile.d/conda.sh" ]; then
        source "/root/miniconda3/etc/profile.d/conda.sh"
    fi
fi

# Accept conda TOS (required for newer conda versions)
echo ""
echo "[3/6] Configuring Conda..."
conda config --set auto_activate_base false 2>/dev/null || true
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main 2>/dev/null || true
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r 2>/dev/null || true
echo "  ✓ Conda configured"

# Create/update conda environment
echo ""
echo "[4/6] Setting up Python environment..."
if conda env list | grep -q "^d2g "; then
    echo "  Environment 'd2g' exists. Updating..."
    conda env update -f environment_runpod.yml --prune 2>&1 | tail -5
else
    echo "  Creating environment 'd2g'..."
    conda env create -f environment_runpod.yml 2>&1 | tail -10
fi
echo "  ✓ Environment ready"

# Activate environment
conda activate d2g

# Create necessary directories
echo ""
echo "[5/6] Creating directories..."
mkdir -p lmm_utils/Qwen/Qwen2-VL-2B-Instruct
mkdir -p lmm_utils/Qwen/qwen2vl_lora_mlp
mkdir -p Logs outputs tmp_gui
echo "  ✓ Directories created"

# Download models
echo ""
echo "[6/6] Setting up models..."
if [ "$SKIP_MODELS" = "1" ]; then
    echo "  Skipping model download (--skip-models flag)"
else
    # Download Qwen2-VL-2B-Instruct model
    if [ ! -f "lmm_utils/Qwen/Qwen2-VL-2B-Instruct/config.json" ]; then
        echo "  Downloading Qwen2-VL-2B-Instruct (~4GB)..."
        python -c "
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id='Qwen/Qwen2-VL-2B-Instruct',
    local_dir='lmm_utils/Qwen/Qwen2-VL-2B-Instruct'
)
print('  ✓ Qwen2-VL-2B-Instruct downloaded')
"
    else
        echo "  ✓ Qwen2-VL-2B-Instruct already present"
    fi

    # Download fine-tuned weights
    if [ ! -f "lmm_utils/Qwen/qwen2vl_lora_mlp/model.pth" ]; then
        echo "  Downloading fine-tuned weights (~4.5GB)..."
        pip install -q gdown
        gdown --id 1CL7OLUq6fYcwoDuLRkBxtKNxJ0_G73U- -O lmm_utils/Qwen/qwen2vl_lora_mlp/model.pth
        echo "  ✓ Fine-tuned weights downloaded"
    else
        echo "  ✓ Fine-tuned weights already present"
    fi
fi

# Setup system.json
if [ ! -f "system.json" ]; then
    echo ""
    echo "Creating system.json from template..."
    cp system.json.template system.json
    echo "  ✓ system.json created"
    echo ""
    echo "  ⚠ IMPORTANT: Edit system.json to add your OpenAI API key!"
fi

# Install cloudflared if not present
if ! command -v cloudflared &> /dev/null; then
    echo ""
    echo "Installing Cloudflare tunnel..."
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O /usr/local/bin/cloudflared 2>/dev/null || \
    wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -O $HOME/cloudflared
    chmod +x /usr/local/bin/cloudflared 2>/dev/null || chmod +x $HOME/cloudflared
    echo "  ✓ Cloudflared installed"
fi

echo ""
echo "========================================"
echo "  Setup Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo ""
echo "1. Configure your OpenAI API key:"
echo "   Edit system.json and set 'api_keys' to your key"
echo "   Or: export OPENAI_API_KEY='sk-...'"
echo ""
echo "2. Start the GUI:"
echo "   ./run_with_tunnel.sh"
echo ""
echo "   Or manually:"
echo "   conda activate d2g"
echo "   python gui.py --host 0.0.0.0 --port 8080"
echo ""
