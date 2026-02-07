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

# Restore repo files that may be hidden by volume mounts
echo ""
echo "Restoring repo files..."
if [ -d "/app/.repo_backup" ]; then
    # Restore the qwen2vl Python file (hidden by volume mount)
    mkdir -p /app/lmm_utils/Qwen/qwen2vl_lora_mlp
    cp -n /app/.repo_backup/qwen2vl_modify_modeling_qwen2_vl.py /app/lmm_utils/Qwen/qwen2vl_lora_mlp/ 2>/dev/null || true
    echo "✓ Repo files restored"
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
    echo "Downloading fine-tuned weights from HuggingFace..."
    mkdir -p /app/lmm_utils/Qwen/qwen2vl_lora_mlp
    
    # Download from HuggingFace (reliable, no rate limits)
    curl -L "https://huggingface.co/Aadijain725/design2garmentcode-lora/resolve/main/model.pth" \
        -o /app/lmm_utils/Qwen/qwen2vl_lora_mlp/model.pth
    
    if [ -f "/app/lmm_utils/Qwen/qwen2vl_lora_mlp/model.pth" ]; then
        echo "✓ Fine-tuned weights downloaded!"
    else
        echo "WARNING: Failed to download fine-tuned weights. App may not work correctly."
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
echo "  Container Ready"
echo "============================================"
echo ""
echo "To start the GUI manually:"
echo "  python gui.py --host 0.0.0.0 --port 8080"
echo ""

# Execute the command passed to docker run
exec conda run --no-capture-output -n d2g "$@"
