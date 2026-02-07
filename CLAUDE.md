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

---

## Workflow Orchestration

### 1. Plan Mode Default
- Enter plan mode for ANY non-trivial task (3+ steps or architectural decisions)
- If something goes sideways, STOP and re-plan immediately — don't keep pushing
- Use plan mode for verification steps, not just building
- Write detailed specs upfront to reduce ambiguity

### 2. Subagent Strategy
- Use subagents liberally to keep main context window clean
- Offload research, exploration, and parallel analysis to subagents
- For complex problems, throw more compute at it via subagents
- One task per subagent for focused execution

### 3. Self-Improvement Loop
- After ANY correction from the user: update `tasks/lessons.md` with the pattern
- Write rules for yourself that prevent the same mistake
- Ruthlessly iterate on these lessons until mistake rate drops
- Review lessons at session start for relevant project

### 4. Verification Before Done
- Never mark a task complete without proving it works
- Diff behavior between main and your changes when relevant
- Ask yourself: "Would a staff engineer approve this?"
- Run tests, check logs, demonstrate correctness

### 5. Demand Elegance (Balanced)
- For non-trivial changes: pause and ask "is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution"
- Skip this for simple, obvious fixes — don't over-engineer
- Challenge your own work before presenting it

### 6. Autonomous Bug Fixing
- When given a bug report: just fix it. Don't ask for hand-holding
- Point at logs, errors, failing tests — then resolve them
- Zero context switching required from the user
- Go fix failing CI tests without being told how

## Task Management

- **Plan First**: Write plan to `tasks/todo.md` with checkable items
- **Verify Plan**: Check in before starting implementation
- **Track Progress**: Mark items complete as you go
- **Explain Changes**: High-level summary at each step
- **Document Results**: Add review section to `tasks/todo.md`
- **Capture Lessons**: Update `tasks/lessons.md` after corrections

## Core Principles

- **Simplicity First**: Make every change as simple as possible. Impact minimal code.
- **No Laziness**: Find root causes. No temporary fixes. Senior developer standards.
- **Minimal Impact**: Changes should only touch what's necessary. Avoid introducing bugs.
