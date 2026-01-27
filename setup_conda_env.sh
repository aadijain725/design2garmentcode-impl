#!/usr/bin/env bash
#
# Setup script for Design2GarmentCode conda environment.
# See README.md for full documentation.
#
# Usage:
#   ./setup_conda_env.sh [OPTIONS]
#
# Options:
#   --default-channels     Use conda-forge and defaults instead of Tsinghua mirrors
#   --skip-model-download  Do not download Qwen2-VL-2B-Instruct base model
#   --download-lora        Download fine-tuned LoRA weights from Google Drive
#   --skip-pip-upgrade     Do not run pip install --upgrade pip
#   --force                Remove existing 'd2g' env and recreate
#

set -e

# --- project root (directory containing this script) ---
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
cd "$PROJECT_ROOT"

# --- defaults ---
USE_DEFAULT_CHANNELS=false
SKIP_MODEL_DOWNLOAD=false
DOWNLOAD_LORA=false
SKIP_PIP_UPGRADE=false
FORCE=false

# --- parse args ---
while [[ $# -gt 0 ]]; do
  case $1 in
    --default-channels)   USE_DEFAULT_CHANNELS=true; shift ;;
    --skip-model-download) SKIP_MODEL_DOWNLOAD=true; shift ;;
    --download-lora)      DOWNLOAD_LORA=true; shift ;;
    --skip-pip-upgrade)   SKIP_PIP_UPGRADE=true; shift ;;
    --force)              FORCE=true; shift ;;
    -h|--help)
      echo "Usage: $0 [OPTIONS]"
      echo "  --default-channels     Use conda-forge and defaults (if Tsinghua mirrors fail)"
      echo "  --skip-model-download  Do not download Qwen2-VL-2B-Instruct base model"
      echo "  --download-lora        Download LoRA weights from Google Drive"
      echo "  --skip-pip-upgrade     Do not run pip install --upgrade pip"
      echo "  --force                Remove existing 'd2g' env and recreate"
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

ENV_NAME="d2g"
ENV_YML="$PROJECT_ROOT/environment.yml"

echo "[setup] Project root: $PROJECT_ROOT"
echo ""

# --- 1. Check conda ---
if ! command -v conda &>/dev/null; then
  echo "ERROR: 'conda' not found. Install Miniconda or Anaconda first."
  echo "  https://docs.conda.io/en/latest/miniconda.html"
  exit 1
fi

# --- 2. Handle existing env ---
if conda env list 2>/dev/null | grep -qE "^${ENV_NAME}[[:space:]]"; then
  if [[ "$FORCE" == true ]]; then
    echo "[setup] Removing existing env '${ENV_NAME}' (--force)"
    conda env remove -n "$ENV_NAME" -y
  else
    echo "ERROR: Conda env '${ENV_NAME}' already exists."
    echo "  Use: conda activate ${ENV_NAME}"
    echo "  Or remove and recreate: conda env remove -n ${ENV_NAME} -y && $0"
    echo "  Or run with: $0 --force"
    exit 1
  fi
fi

# --- 3. Create env from environment.yml ---
if [[ "$USE_DEFAULT_CHANNELS" == true ]]; then
  echo "[setup] Using default conda channels (conda-forge, defaults)"
  TMP_YML="$(mktemp)"
  sed -e 's|https://mirrors.tuna.tsinghua.edu.cn/anaconda/cloud/conda-forge|conda-forge|' \
      -e 's|https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main|defaults|' \
      "$ENV_YML" > "$TMP_YML"
  trap "rm -f '$TMP_YML'" EXIT
  conda env create -f "$TMP_YML"
else
  echo "[setup] Creating conda env from environment.yml (Tsinghua mirrors)"
  conda env create -f "$ENV_YML"
fi

echo ""

# --- 4. Upgrade pip (optional) ---
if [[ "$SKIP_PIP_UPGRADE" != true ]]; then
  echo "[setup] Upgrading pip in ${ENV_NAME}"
  conda run -n "$ENV_NAME" python -m pip install --upgrade pip
  echo ""
fi

# --- 5. Download Qwen2-VL-2B-Instruct base model (optional) ---
if [[ "$SKIP_MODEL_DOWNLOAD" != true ]]; then
  DOWNLOAD_SCRIPT="$PROJECT_ROOT/lmm_utils/Qwen/download_qwen2vl_2b_instruct.py"
  if [[ -f "$DOWNLOAD_SCRIPT" ]]; then
    echo "[setup] Downloading Qwen2-VL-2B-Instruct to lmm_utils/Qwen/Qwen2-VL-2B-Instruct/"
    echo "        (Re-run this script or the download script to resume if interrupted.)"
    if conda run -n "$ENV_NAME" python "$DOWNLOAD_SCRIPT"; then
      echo "[setup] Base model download finished."
    else
      echo "[setup] WARN: Base model download failed or was interrupted. You can re-run:"
      echo "        conda activate ${ENV_NAME} && python lmm_utils/Qwen/download_qwen2vl_2b_instruct.py"
    fi
  else
    echo "[setup] WARN: $DOWNLOAD_SCRIPT not found; skipping base model download."
    echo "        Manually download from https://huggingface.co/Qwen/Qwen2-VL-2B-Instruct and place in lmm_utils/Qwen/Qwen2-VL-2B-Instruct/"
  fi
  echo ""
else
  echo "[setup] Skipping base model download (--skip-model-download)."
  echo "        To install later: conda activate ${ENV_NAME} && python lmm_utils/Qwen/download_qwen2vl_2b_instruct.py"
  echo ""
fi

# --- 6. Download LoRA weights (optional) ---
LORA_DIR="$PROJECT_ROOT/lmm_utils/Qwen/qwen2vl_lora_mlp"
LORA_FILE="$LORA_DIR/model.pth"
GDRIVE_ID="1CL7OLUq6fYcwoDuLRkBxtKNxJ0_G73U-"

if [[ "$DOWNLOAD_LORA" == true ]]; then
  mkdir -p "$LORA_DIR"
  echo "[setup] Downloading fine-tuned LoRA weights to $LORA_FILE"
  conda run -n "$ENV_NAME" python -m pip install -q gdown 2>/dev/null || true
  if conda run -n "$ENV_NAME" python -m gdown "$GDRIVE_ID" -O "$LORA_FILE" 2>/dev/null; then
    echo "[setup] LoRA weights downloaded."
  elif command -v gdown &>/dev/null && gdown "$GDRIVE_ID" -O "$LORA_FILE"; then
    echo "[setup] LoRA weights downloaded (via system gdown)."
  else
    echo "[setup] WARN: gdown failed. Download manually from:"
    echo "        https://drive.google.com/file/d/${GDRIVE_ID}/view?usp=sharing"
    echo "        and save as $LORA_FILE"
  fi
  echo ""
else
  if [[ ! -f "$LORA_FILE" ]]; then
    echo "[setup] LoRA weights not found at $LORA_FILE"
    echo "        Download from: https://drive.google.com/file/d/${GDRIVE_ID}/view?usp=sharing"
    echo "        and place as $LORA_FILE"
    echo "        Or run this script with: --download-lora"
    echo ""
  fi
fi

# --- 7. API key / system.json reminder ---
if [[ -z "${OPENAI_API_KEY:-}" ]]; then
  echo "[setup] Reminder: to use the language model, set your OpenAI (or MMUA) API key:"
  echo "        export OPENAI_API_KEY=\"sk-...\""
  echo "        Or edit api_keys / base_urls / model in system.json"
  echo ""
fi

# --- 8. Quick sanity check ---
echo "[setup] Verifying env: import torch, transformers"
conda run -n "$ENV_NAME" python -c "
import torch
import transformers
print('  torch:', torch.__version__)
print('  transformers:', transformers.__version__)
print('  OK')
"
echo ""

# --- 9. Next steps ---
echo "=== Setup complete ==="
echo ""
echo "Activate the environment and run:"
echo "  conda activate ${ENV_NAME}"
echo ""
echo "GUI:"
echo "  python gui.py"
echo ""
echo "Batch inference:"
echo "  python lmm_utils/test_text_batch.py --input assets/test_text/examples.json --output assets/test_text_result --sim"
echo "  python lmm_utils/test_picture_batch.py --input assets/test_img/examples --output assets/test_image_result/examples --sim"
echo ""
echo "3D simulation from pattern JSON:"
echo "  python test_garment_sim.py --pattern_spec <path-to-pattern.json>"
echo ""
