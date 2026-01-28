# Setup and Running Guide

This document describes how to set up the Design2GarmentCode environment and run the GUI and batch tools. It covers **custom scripts** added in this repository (`setup_conda_env.sh`, `run_gui.sh`) that are not part of the upstream Style3D implementation.

---

## Prerequisites

- **Conda** (Miniconda or Anaconda). Install from: https://docs.conda.io/en/latest/miniconda.html  
- **Git** (to clone the repo).  
- **(Optional)** CUDA-capable GPU for faster inference; CPU is supported.

---

## 1. Clone and Enter the Project

```bash
git clone https://github.com/aadijain725/design2garmentcode-impl.git
cd design2garmentcode-impl
```

---

## 2. Environment Setup: `setup_conda_env.sh`

The custom **`setup_conda_env.sh`** script automates Conda environment creation, optional model downloads, and basic checks. Use it instead of manual `conda env create` when possible.

### Basic usage

```bash
./setup_conda_env.sh
```

This will:

- Create the `d2g` Conda environment from `environment.yml`.
- Use Tsinghua mirrors for Conda packages (faster in some regions).
- Upgrade pip in the new environment.
- Optionally download the **Qwen2-VL-2B-Instruct** base model into `lmm_utils/Qwen/Qwen2-VL-2B-Instruct/` (if the download helper exists).

### Options

| Option | Description |
|--------|-------------|
| `--default-channels` | Use `conda-forge` and `defaults` instead of Tsinghua mirrors. Use if Tsinghua is unreachable or slow. |
| `--skip-model-download` | Do **not** download the Qwen2-VL base model. Use when you want to set up the env first and download models later. |
| `--download-lora` | Download the fine-tuned LoRA weights from Google Drive into `lmm_utils/Qwen/qwen2vl_lora_mlp/model.pth`. |
| `--skip-pip-upgrade` | Skip `pip install --upgrade pip`. |
| `--force` | Remove an existing `d2g` environment and recreate it from scratch. |
| `-h`, `--help` | Show usage and options. |

### Examples

```bash
# Standard setup (Tsinghua mirrors, with base model download)
./setup_conda_env.sh

# Use default Conda channels (e.g. if Tsinghua fails)
./setup_conda_env.sh --default-channels

# Skip base model download; install env only
./setup_conda_env.sh --skip-model-download

# Also download LoRA weights from Google Drive
./setup_conda_env.sh --download-lora

# Recreate env from scratch
./setup_conda_env.sh --force
```

### After setup

Activate the environment and run commands as needed:

```bash
conda activate d2g
```

See the main [README](../README.md) for API keys (`OPENAI_API_KEY` / `system.json`), base model placement, and LoRA weights.

---

## 3. Running the GUI: `run_gui.sh` vs `python gui.py`

You can start the Design2GarmentCode GUI in two ways.

### Option A: `run_gui.sh` (custom script)

**`run_gui.sh`** is a convenience script that:

- Uses the `d2g` Conda environment **without** requiring you to `conda activate` first.
- Runs `gui.py` with configurable `--host` and `--port`.
- Checks that the `d2g` env and (optionally) LoRA weights exist, and prints clear errors if not.

**Requirements:** The script expects the `d2g` environment at a **fixed path** (Homebrew Miniconda on macOS):

```
/opt/homebrew/Caskroom/miniconda/base/envs/d2g/bin/python
```

If your Conda installation is different (e.g. Anaconda, Linux, or another prefix), either:

- **Edit** `run_gui.sh` and set `CONDA_PYTHON` to your `d2g` Python path, or  
- Use **Option B** below (`conda activate` + `python gui.py`).

#### Usage

```bash
./run_gui.sh [OPTIONS]
```

| Option | Description |
|--------|-------------|
| `--port PORT` | Port for the GUI server (default: `8080`). |
| `--host HOST` | Host address (default: `0.0.0.0`). |
| `-h`, `--help` | Show usage. |

#### Examples

```bash
# Default: http://0.0.0.0:8080
./run_gui.sh

# Custom port
./run_gui.sh --port 9000

# Custom host and port
./run_gui.sh --host 127.0.0.1 --port 8080
```

Then open **http://localhost:8080** (or the host/port you used) in your browser.

### Option B: `python gui.py` (manual)

If you prefer to run the GUI yourself:

```bash
conda activate d2g
python gui.py [--host HOST] [--port PORT]
```

Defaults are `--host 0.0.0.0` and `--port 8080`. See `python gui.py --help` for details.

---

## 4. Quick Reference

| Task | Command |
|------|---------|
| Setup environment | `./setup_conda_env.sh` or `./setup_conda_env.sh --default-channels` |
| Run GUI (script) | `./run_gui.sh` or `./run_gui.sh --port 9000` |
| Run GUI (manual) | `conda activate d2g && python gui.py` |
| Batch text | `conda activate d2g && python lmm_utils/test_text_batch.py --input ... --output ... --sim` |
| Batch image | `conda activate d2g && python lmm_utils/test_picture_batch.py --input ... --output ... --sim` |
| 3D sim from JSON | `conda activate d2g && python test_garment_sim.py --pattern_spec <path-to-pattern.json>` |

---

## 5. Troubleshooting

### `setup_conda_env.sh`

- **"conda not found"**  
  Install Miniconda/Anaconda and ensure `conda` is on your `PATH` (e.g. run `conda init` and restart the shell).

- **"Conda env 'd2g' already exists"**  
  Use `conda activate d2g` to use it, or `./setup_conda_env.sh --force` to remove and recreate.

- **Tsinghua mirrors fail**  
  Use `./setup_conda_env.sh --default-channels`.

- **Base model / LoRA download fails**  
  The script prints manual instructions. Download from the URLs it shows and place files as indicated.

### `run_gui.sh`

- **"Conda environment 'd2g' not found at expected location"**  
  The script looks for `d2g` at the Homebrew Miniconda path. Either move your env there, or edit `CONDA_PYTHON` in `run_gui.sh`, or use `conda activate d2g && python gui.py` instead.

- **"Fine-tuned model weights not found"**  
  LoRA weights are optional but recommended. Download via `./setup_conda_env.sh --download-lora` or manually, and place as `lmm_utils/Qwen/qwen2vl_lora_mlp/model.pth`.

### GUI / API

- **API or model errors**  
  Configure `OPENAI_API_KEY` or `system.json` as in the main [README](../README.md). Ensure base model and LoRA paths match what the code expects.

---

## See Also

- [README](../README.md) – Installation, API setup, batch inference, 3D simulation, citation.
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) – Code locations and pipeline overview.
- [PIPELINE_OVERVIEW.md](PIPELINE_OVERVIEW.md) – High-level pipeline description.
