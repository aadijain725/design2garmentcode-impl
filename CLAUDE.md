# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Design2GarmentCode is a neural-symbolic framework that converts multi-modal design concepts (text, images, sketches) into parametric sewing patterns. It combines Large Multimodal Models (LMMs) with a parametric garment generation system.

## Build & Setup Commands

```bash
# Create conda environment
conda env create -f environment.yml
conda activate d2g

# Set API key (required)
export OPENAI_API_KEY="sk-..."

# Download fine-tuned model weights (~4.5GB)
pip install gdown
gdown --id 1CL7OLUq6fYcwoDuLRkBxtKNxJ0_G73U- -O lmm_utils/Qwen/qwen2vl_lora_mlp/model.pth
```

For RunPod: `./setup_runpod.sh`
For Docker: `docker-compose up -d`

## Running the Application

```bash
# Start GUI (web interface on port 8080)
python gui.py --host 0.0.0.0 --port 8080

# Or use convenience script
./start_gui.sh [port]
```

## Testing

No pytest framework - tests are standalone CLI scripts:

```bash
# Text-to-garment batch processing
python lmm_utils/test_text_batch.py --input assets/test_text/examples.json --output assets/test_text_result --sim false

# Image-to-garment batch processing
python lmm_utils/test_picture_batch.py --input assets/test_img/examples --output assets/test_image_result/examples --sim false

# Garment code conversion
python test_garmentcode.py --files design_yamls --body neutral --output ./Logs

# 3D simulation
python test_garment_sim.py --pattern_spec <path_to_pattern.json>
```

## Architecture

```
User Input (Text/Image) → GUI (gui.py) → Agent (lmm_utils/agent.py)
                                              ↓
                         MMUA (core.py) → GPT-4o API → Design Description
                                              ↓
                         Predictor (predict_garmentcode_picture.py) → Qwen2-VL
                                              ↓
                         YAML Parameters → MetaGarment → pygarment → 2D Pattern → 3D Simulation
```

### Key Modules

| Directory | Responsibility |
|-----------|----------------|
| `gui/` | NiceGUI web interface; `callbacks.py` handles state and interactions |
| `lmm_utils/` | AI orchestration; `agent.py` is main API, `core.py` handles LLM calls, `predict_garmentcode_picture.py` runs Qwen2-VL |
| `pygarment/` | Pattern generation library; panels, edges, connectors, mesh generation |
| `assets/garment_programs/` | Parametric garment definitions; `meta_garment.py` orchestrates assembly |
| `assets/bodies/` | Body parameterization; `body_params.py` defines measurements |
| `data_utils/` | Batch processing utilities |

### Key Files

- **Entry point**: `gui.py`
- **AI Agent**: `lmm_utils/agent.py` - `modify_design()`, `picture_design()`, `text_design()`
- **LLM Interface**: `lmm_utils/core.py` - `MMUA` class
- **Pattern Predictor**: `lmm_utils/predict_garmentcode_picture.py` - `Predictor` class
- **Garment Assembly**: `assets/garment_programs/meta_garment.py` - `MetaGarment` class

## Configuration

- `system.json` - API credentials, model paths, output directories
- `environment.yml` / `environment_runpod.yml` - Conda dependencies
- `assets/Sim_props/default_sim_props.yaml` - Simulation settings

## Models

- **GPT-4o**: Main LLM for design understanding (via OpenAI API)
- **Qwen2-VL-2B-Instruct**: Fine-tuned vision-language model for parameter projection (local, in `lmm_utils/Qwen/`)
