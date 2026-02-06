#!/bin/bash
# Docker entrypoint for Design2GarmentCode
# Handles model verification, config setup, and starts the application

set -e

echo "============================================"
echo "  Design2GarmentCode - Container Startup"
echo "============================================"

# Activate conda environment
source /opt/conda/etc/profile.d/conda.sh
conda activate d2g

# Set OpenGL platform for headless 3D rendering
export PYOPENGL_PLATFORM=osmesa

# Check GPU
if command -v nvidia-smi &> /dev/null; then
    echo "GPU: $(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null || echo 'Not available')"
else
    echo "WARNING: nvidia-smi not found"
fi

# Verify models exist, download if missing
echo ""
echo "Checking models..."

if [ ! -f "/app/lmm_utils/Qwen/Qwen2-VL-2B-Instruct/config.json" ]; then
    echo "Downloading Qwen2-VL-2B-Instruct model..."
    mkdir -p /app/lmm_utils/Qwen/Qwen2-VL-2B-Instruct
    python -c "
from huggingface_hub import snapshot_download
snapshot_download(
    repo_id='Qwen/Qwen2-VL-2B-Instruct',
    local_dir='/app/lmm_utils/Qwen/Qwen2-VL-2B-Instruct'
)
print('Qwen2-VL-2B-Instruct downloaded!')
"
else
    echo "✓ Qwen2-VL-2B-Instruct found"
fi

if [ ! -f "/app/lmm_utils/Qwen/qwen2vl_lora_mlp/model.pth" ]; then
    echo "Downloading fine-tuned weights..."
    mkdir -p /app/lmm_utils/Qwen/qwen2vl_lora_mlp
    
    # Try gdown first, fall back to curl if it fails
    if pip install -q gdown && gdown --id 1CL7OLUq6fYcwoDuLRkBxtKNxJ0_G73U- -O /app/lmm_utils/Qwen/qwen2vl_lora_mlp/model.pth 2>/dev/null; then
        echo "Fine-tuned weights downloaded via gdown!"
    else
        echo "gdown failed, trying curl..."
        curl -L "https://drive.google.com/uc?export=download&id=1CL7OLUq6fYcwoDuLRkBxtKNxJ0_G73U-&confirm=t" -o /app/lmm_utils/Qwen/qwen2vl_lora_mlp/model.pth
        echo "Fine-tuned weights downloaded via curl!"
    fi
else
    echo "✓ Fine-tuned weights found"
fi

# Setup system.json if not exists
if [ ! -f "/app/system.json" ]; then
    echo ""
    echo "Creating system.json from template..."
    cp /app/system.json.template /app/system.json

    # If OPENAI_API_KEY is set, update the config
    if [ -n "$OPENAI_API_KEY" ]; then
        echo "Configuring OpenAI API key from environment..."
        python -c "
import json
with open('/app/system.json', 'r') as f:
    config = json.load(f)
config['api_keys'] = '$OPENAI_API_KEY'
config['base_urls'] = 'https://api.openai.com/v1'
config['model']['vl_model'] = '${OPENAI_MODEL:-gpt-4o}'
config['model']['text_model'] = '${OPENAI_MODEL:-gpt-4o}'
with open('/app/system.json', 'w') as f:
    json.dump(config, f, indent=2)
print('Config updated with API key')
"
    else
        echo "WARNING: OPENAI_API_KEY not set. Edit /app/system.json manually."
    fi
fi

# Create required directories
mkdir -p /app/Logs /app/outputs /app/tmp_gui

echo ""
echo "============================================"
echo "  Starting Application"
echo "============================================"
echo ""

# Execute the command passed to docker run
exec conda run --no-capture-output -n d2g "$@"
