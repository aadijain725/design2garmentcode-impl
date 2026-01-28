#!/bin/bash
# ==============================================
# Design2GarmentCode Container Entrypoint
# ==============================================
set -e

echo "============================================"
echo "  Design2GarmentCode Container Starting"
echo "============================================"
echo ""

# ==============================================
# Check Model Mode
# ==============================================
echo "Model Mode: ${MODEL_MODE:-local}"

if [ "${MODEL_MODE}" = "api" ]; then
    echo "Running in API mode - using external model API"

    if [ -z "$QWEN_API_URL" ]; then
        echo "WARNING: QWEN_API_URL not set. API mode may not work correctly."
    else
        echo "API URL: $QWEN_API_URL"
    fi

    if [ -z "$QWEN_API_KEY" ]; then
        echo "WARNING: QWEN_API_KEY not set. API authentication may fail."
    fi
else
    echo "Running in LOCAL mode - using local model files"

    # Check if base model exists
    MODEL_DIR="${MODEL_PATH:-/app/lmm_utils/Qwen}"
    BASE_MODEL="$MODEL_DIR/Qwen2-VL-2B-Instruct"
    LORA_WEIGHTS="$MODEL_DIR/qwen2vl_lora_mlp/model.pth"

    if [ ! -d "$BASE_MODEL" ] || [ -z "$(ls -A $BASE_MODEL 2>/dev/null)" ]; then
        echo ""
        echo "ERROR: Base model not found at $BASE_MODEL"
        echo ""
        echo "Please mount the model directory:"
        echo "  docker run -v /path/to/lmm_utils/Qwen:/app/lmm_utils/Qwen ..."
        echo ""
        echo "Or switch to API mode:"
        echo "  docker run -e MODEL_MODE=api -e QWEN_API_URL=... ..."
        echo ""
        exit 1
    fi
    echo "Base model found: $BASE_MODEL"

    if [ ! -f "$LORA_WEIGHTS" ]; then
        echo ""
        echo "WARNING: LoRA weights not found at $LORA_WEIGHTS"
        echo "The model may not work correctly without fine-tuned weights."
        echo ""
    else
        echo "LoRA weights found: $LORA_WEIGHTS"
    fi
fi

# ==============================================
# Check OpenAI API Key (optional)
# ==============================================
if [ -z "$OPENAI_API_KEY" ]; then
    echo ""
    echo "NOTE: OPENAI_API_KEY not set."
    echo "Text-based design features may be limited."
else
    echo "OpenAI API key: configured"
fi

# ==============================================
# Check GPU availability
# ==============================================
echo ""
if command -v nvidia-smi &> /dev/null; then
    echo "GPU Status:"
    nvidia-smi --query-gpu=name,memory.total,memory.free --format=csv,noheader 2>/dev/null || echo "  Unable to query GPU"
else
    echo "GPU: Not available (running on CPU)"
fi

# ==============================================
# Start the application
# ==============================================
echo ""
echo "============================================"
echo "Starting GUI server on ${HOST:-0.0.0.0}:${PORT:-8080}"
echo "============================================"
echo ""

exec python gui.py --host "${HOST:-0.0.0.0}" --port "${PORT:-8080}"
