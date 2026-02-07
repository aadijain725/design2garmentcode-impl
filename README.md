
# Design2GarmentCode: Turning Design Concepts to Tangible Garments Through Program Synthesis

[![arXiv](https://img.shields.io/badge/📃-arXiv%20-red.svg)](https://arxiv.org/abs/2412.08603)
[![webpage](https://img.shields.io/badge/🌐-Website%20-blue.svg)](https://style3d.github.io/design2garmentcode/)
[![Youtube](https://img.shields.io/badge/📽️-Video%20-orchid.svg)](https://www.youtube.com/xxx)

<span class="author-block"><a href="">Feng Zhou</a>,&nbsp;</span>
<span class="author-block"><a href="https://walnut-ree.github.io/">Ruiyang Liu</a>,&nbsp;</span>
<span class="author-block"><a href="">Chen Liu</a>,&nbsp;</span>
<span class="author-block"><a href="">Gaofeng He</a>,&nbsp;</span>
<span class="author-block"><a href="https://dirtyharrylyl.github.io/">Yong-Lu Li</a>,&nbsp;</span>
<span class="author-block"><a href="http://www.cad.zju.edu.cn/home/jin/">Xiaogang Jin</a>,&nbsp;</span>
<span class="author-block"><a href="https://wanghmin.github.io/">Huamin Wang</a></span>

<p align="center">
  <img src="https://github.com/Style3D/design2garmentcode-impl/raw/main/assets/img/neural_symbolic-pipeline.png">
</p>
Official implementation for Design2GarmentCode, a motility-agnostic sewing pattern generation framework that leverages fine-tuned Large Multimodal Models to generate parametric pattern-making programs from multi-modal design concepts.


## Installation

### 1. Clone the repository
```bash
git clone https://github.com/aadijain725/design2garmentcode-impl.git
cd design2garmentcode-impl
```

### 2. Create the Conda environment
An `environment.yml` file is provided in the project root with all required Conda and PyPI dependencies (Python 3.9.19, Torch 2.4.0 + CUDA 12.1, etc.).

```bash
conda env create -f environment.yml
conda activate d2g
python -m pip install --upgrade pip          # optional: upgrade pip
```

### 3. (Optional) Enable 3-D simulation
If you need local cloth simulation and 3-D visualization, follow the installation instructions for **GarmentCode Warp Simulator**:
<https://github.com/maria-korosteleva/NvidiaWarp-GarmentCode>

---
### 4. Language-Model API
`Design2GarmentCode` communicates with large multimodal models.
Follow the steps **in the given order**:

#### 1. **Provide API credentials for MMUA**
- **Environment variable (recommended)** -- defaults to *ChatGPT-4o*
     ```bash
     export OPENAI_API_KEY="sk-..."
     ```
- **Edit `system.json`** (project root) -- manually specify `api_key`, `base_url`, and `model` if you prefer a file-based approach.

#### 2. **Set up the parameter projector**:
- Download the base model [Qwen2-VL-2B-Instruct](https://huggingface.co/Qwen/Qwen2-VL-2B-Instruct/tree/main) and place the modal to `lmm_utils/Qwen/Qwen2-VL-2B-Instruct/`.

- Download the fine-tuned weights file from [Google Drive](https://drive.google.com/file/d/1CL7OLUq6fYcwoDuLRkBxtKNxJ0_G73U-/view?usp=sharing), and place it in `lmm_utils/Qwen/qwen2vl_lora_mlp/`.

---

## RunPod Setup (`setup_runpod.sh`)

For cloud GPU deployment (RunPod, Lambda, etc.), use the automated setup script instead of manual installation.

### Prerequisites

- NVIDIA GPU instance with at least **8 GB VRAM** (RTX 3080+ or A40/A100 recommended)
- ~15 GB disk space (models + environment)
- An OpenAI API key

### Quick Start

```bash
# 1. Clone and enter the repo
git clone https://github.com/aadijain725/design2garmentcode-impl.git
cd design2garmentcode-impl

# 2. Run the one-shot setup script
chmod +x setup_runpod.sh
./setup_runpod.sh
```

### What `setup_runpod.sh` Does

The script automates six steps:  

| Step | Action | Details |
|------|--------|---------|
| 1 | **GPU check** | Detects NVIDIA GPU via `nvidia-smi` |
| 2 | **Miniconda install** | Downloads and installs Miniconda if not present |
| 3 | **Conda config** | Accepts ToS, disables auto-activate base |
| 4 | **Python environment** | Creates (or updates) the `d2g` conda env from `environment_runpod.yml` |
| 5 | **Directory setup** | Creates `lmm_utils/Qwen/`, `Logs/`, `outputs/`, `tmp_gui/` |
| 6 | **Model download** | Downloads Qwen2-VL-2B-Instruct (~4 GB) and fine-tuned LoRA weights (~4.5 GB) |

It also installs **Cloudflared** for tunnel access and creates `system.json` from the template if it doesn't exist.

### Flags

```bash
./setup_runpod.sh                # Full setup (environment + models)
./setup_runpod.sh --skip-models  # Skip model downloads (if already present)
```

### Post-Setup Configuration

After the script completes, configure your API key using **one** of these methods:

```bash
# Option A: environment variable (recommended)
export OPENAI_API_KEY="sk-..."

# Option B: edit system.json directly
#   Set the "api_keys" field to your OpenAI key
```

The `system.json` file controls model selection and paths:

```json
{
  "model": {
    "vl_model": "gpt-4o",
    "text_model": "gpt-4o"
  },
  "api_keys": "YOUR_OPENAI_API_KEY_HERE",
  "base_urls": "https://api.openai.com/v1",
  "param_model": "lmm_utils/Qwen/qwen2vl_lora_mlp/model.pth"
}
```

### Verifying the Setup

```bash
conda activate d2g
python -c "import torch; print('CUDA:', torch.cuda.is_available())"
python -c "from lmm_utils.agent import Agent; print('Agent importable')"
```

---

## Running the GUI

The web-based GUI lets you interactively design garments from text, images, or sketches.

### Start the GUI

```bash
# Activate the environment first
conda activate d2g

# Option 1: Direct launch (accessible on local network)
python gui.py --host 0.0.0.0 --port 8080

# Option 2: Convenience script
./start_gui.sh [port]          # defaults to port 8080

# Option 3: With Cloudflare tunnel (public HTTPS URL, ideal for RunPod)
./run_with_tunnel.sh
```

### Accessing the GUI

| Method | URL | When to use |
|--------|-----|-------------|
| **Cloudflare tunnel** | `https://<random>.trycloudflare.com` (printed by `run_with_tunnel.sh`) | RunPod / remote GPU -- no port forwarding needed |
| **RunPod proxy** | `https://<pod-id>-8080.proxy.runpod.net` | RunPod with HTTP port 8080 exposed |
| **Local** | `http://localhost:8080` | Local machine or SSH tunnel |

### Using the GUI

1. Open the URL in your browser.
2. Navigate to the **"PARSE DESIGN"** tab.
3. Enter your design input:
   - **Text**: Type a description (e.g. *"A-line summer dress with puff sleeves"*)
   - **Image**: Click the upload button to attach a photo or sketch
   - **Image + Text**: Upload an image and add a text prompt for combined input
4. Click **Submit** and wait for the 2D sewing pattern to appear on the right.
5. **Modify**: Type `modify: <your instruction>` to iteratively refine the pattern.
6. Switch to the **"3D View"** tab to run cloth simulation and visualize the draped garment.
7. Use the **Download** button to export the pattern as a JSON archive.

### GUI Startup Options

| Flag | Description |
|------|-------------|
| `--host` | Bind address (default `0.0.0.0`) |
| `--port` | Port number (default `8080`) |

### What `run_with_tunnel.sh` Does

1. Checks GPU availability
2. Activates the `d2g` conda environment
3. Kills any stale `gui.py` / `cloudflared` processes
4. Starts `gui.py` in the background and waits for it to be ready
5. Launches a Cloudflare quick-tunnel and prints the public URL
6. Tails live logs with color highlighting

Logs are written to `/tmp/d2g_logs/`:

| Log file | Contents |
|----------|----------|
| `gui.log` | GUI server stdout/stderr |
| `cloudflared.log` | Tunnel output and public URL |
| `gui_detailed.log` | Detailed application-level logs |

Press **Ctrl+C** to gracefully stop all services.

---

## Running from Command Line

For batch processing or scripting, use `run_image_pipeline.py`:

### Basic Usage

```bash
conda activate d2g

# Process an image → pattern + 3D simulation
python run_image_pipeline.py assets/dress_clo_input/Dress_Clo.jpg

# Pattern only (skip 3D simulation, faster)
python run_image_pipeline.py my_design.png --no-sim

# Verbose output
python run_image_pipeline.py sketch.jpg -v
```

### What It Does

| Stage | Model | Output | Time |
|-------|-------|--------|------|
| 1. MMUA | GPT-4o | Design caption list | ~6s |
| 2. DSL-GA | Qwen2-VL (fine-tuned) | 130 YAML parameters | ~25s |
| 3. GarmentCode | Parametric engine | SVG/PNG/PDF patterns | <1s |
| 4. Warp Sim | GPU physics | GLB mesh + renders | ~50s |

### Output Files

```
tmp_gui/downloads/<session_id>/
├── Configured_design/
│   ├── *_pattern.png        # Sewing pattern image
│   ├── *_pattern.svg        # Vector pattern
│   ├── *_print_pattern.pdf  # Printable pattern
│   ├── *_specification.json # Exact measurements
│   └── design_params.yaml   # All 130 parameters
└── Configured_design_3D/
    ├── *_sim.glb            # 3D mesh (viewable in any GLB viewer)
    ├── *_sim.obj            # OBJ format
    ├── *_render_front.png   # Front preview
    └── *_render_back.png    # Back preview
```

### Important Note

The script must initialize `warp` before importing from `/app` due to a module path conflict. This is handled automatically in `run_image_pipeline.py`.

---

## Unified Pipeline CLI (`run_pipeline.py`)

`run_pipeline.py` is a headless CLI for running the full design-to-pattern pipeline without the GUI. It accepts **text**, **images**, or **both** and produces structured output files.

### Basic Usage

```bash
conda activate d2g

# Text-only design
python run_pipeline.py --text "A-line summer dress with short sleeves"

# Single image
python run_pipeline.py --images photo.jpg

# Multiple images
python run_pipeline.py --images front.jpg back.jpg --output ./results

# Image + text (combined multi-modal input)
python run_pipeline.py --images photo.jpg --text "make it sleeveless" --output ./results

# With 3D simulation
python run_pipeline.py --text "pencil skirt" --sim --output ./results

# Fast mode (skip Qwen2-VL loading) + verbose logging
python run_pipeline.py --text "hooded jacket" --no-model-init --verbose
```

### CLI Flags

| Flag | Type | Default | Description |
|------|------|---------|-------------|
| `--images` | paths (one or more) | *none* | Garment image file(s) |
| `--text` | string | *none* | Text design prompt |
| `--output` | path | `./pipeline_output` | Output directory for all results |
| `--sim` | flag | off | Run 3D cloth simulation after pattern generation |
| `--no-model-init` | flag | off | Skip Qwen2-VL model loading (faster startup, uses only GPT-4o) |
| `--verbose` | flag | off | Enable DEBUG-level logging |

At least one of `--images` or `--text` is required.

### Output Files

The pipeline writes three files to the `--output` directory:

| File | Format | Contents |
|------|--------|----------|
| `pipeline_result.json` | JSON | Full pipeline result: inputs, GPT response, design list, elapsed time |
| `caption.json` | JSON | Qwen2-VL caption / parameter prediction (if model was loaded) |
| `design_params.yaml` | YAML | Final design parameters ready for pattern generation |

When `--sim` is used, additional 3D output (pattern JSON, simulation mesh) is saved under the GUI's temp directory and paths are logged.

### Pipeline Routing

The pipeline automatically selects the right processing path based on the inputs provided:

| Input | Route |
|-------|-------|
| Images + Text | `pictures_gpt` / `picture_gpt` -> `text_forusermodel_gpt` -> `caption2yaml(image)` |
| Images only | `pictures_gpt` / `picture_gpt` -> `caption2yaml(image)` |
| Text only | `text_gpt` -> `caption2yaml()` |

### Examples

**Generate from a text description and save results:**
```bash
python run_pipeline.py \
  --text "A knee-length pleated skirt in light fabric" \
  --output ./my_skirt
```

**Generate from an image with 3D simulation:**
```bash
python run_pipeline.py \
  --images assets/test_img/dress_clo.jpg \
  --sim \
  --output ./dress_results
```

**Multi-image input with text refinement:**
```bash
python run_pipeline.py \
  --images front_view.jpg side_view.jpg \
  --text "fitted bodice with flared skirt" \
  --output ./combined_results
```

### Sample Run: CLO 3D Dress with Size M Measurements

This example demonstrates the full pipeline using a CLO 3D rendering of a sleeveless A-line midi dress combined with extracted garment measurements (Size M / EU 38).

**Input files** (in `assets/dress_clo_input/`):
- `Dress_Clo.jpg` — CLO 3D rendering (front, side, back views)
- `Dress_M.png` — Measurement/dimension table with sizes 32–46
- `measurements_size_m.json` — Extracted Size M measurements (OCR from the table)

**Run the pipeline:**
```bash
conda activate d2g

python run_pipeline.py \
  --images assets/dress_clo_input/Dress_Clo.jpg \
  --text "Sleeveless A-line midi dress with round neckline, fitted bodice, flared skirt. Size M measurements: Chest 90.50cm, Waist 76.00cm, Back length to waist 39.50cm, Shoulder to shoulder 39.50cm, Scye depth 23.00cm, Back length 84.00cm, Neck width 18.00cm, Neck drop back 3.00cm, Neck drop front 9.00cm, Zipper length 56.00cm, Bottom hem 647.00cm" \
  --output ./pipeline_output/dress_clo_test \
  --verbose
```

**Expected output** (in `pipeline_output/dress_clo_test/`):

| File | Contents |
|------|----------|
| `pipeline_result.json` | GPT-4o visual analysis, design token list, elapsed time |
| `caption.json` | Qwen2-VL parameter prediction (125 design tokens) |
| `design_params.yaml` | Final parametric garment spec with numeric values |

**Key parameters produced:**
- `sleeve.sleeveless: true` — Sleeveless design
- `collar.f_collar: CircleNeckHalf` — Round neckline
- `meta.bottom: Skirt2` — A-line skirt type
- `meta.connected: true` — One-piece dress
- `skirt.length: 0.604` — Midi length
- `skirt.flare: 2` — A-line flare

The pipeline completed in ~105 seconds (GPT-4o image analysis + Qwen2-VL parameter projection).

---

## Batch Inference
### 1. Text Guided Generation

Use `test_text_batch.py` to process a list of text descriptions from a JSON file.

```bash
python lmm_utils/test_text_batch.py \
  --input assets/test_text/examples.json \
  --output assets/test_text_result \
  --sim
```

- `--input`: Path to your input JSON file containing multiple garment description texts.
- `--output`: Directory where the output `.json` files will be saved.
- `--sim`: Enable or disable physical simulation output.
Supports physical simulation (enabled by default in script).

---

### 2. Image Guided Generation

Use `test_picture_batch.py` to process all image files in a directory.

```bash
python lmm_utils/test_picture_batch.py \
  --input assets/test_img/examples \
  --output assets/test_image_result/examples \
  --sim
```
- `--input`: Folder containing multiple image files.
- `--output`: Output folder where results will be saved.
- `--sim`: Enable or disable physical simulation output.

---

## Simulate 3D Garment
### 1. Generate from a pattern.json
After generating the pattern data, you can simulate the corresponding 3D output directly from the pattern's JSON file with
```bash
python test_garment_sim.py --pattern_spec $INPUT_JSON
```
Or run the simulation directly in the `3D View` GUI tab.

---

## Troubleshooting

### "429 Too Many Requests" errors
OpenAI rate limiting. The system retries automatically. Use a paid OpenAI account with higher limits or wait between requests.

### Models not loading
Ensure ~15 GB free disk space and re-run `./setup_runpod.sh`. Check that `lmm_utils/Qwen/Qwen2-VL-2B-Instruct/config.json` and `lmm_utils/Qwen/qwen2vl_lora_mlp/model.pth` exist.

### GPU not detected
Run `nvidia-smi` to verify drivers. On RunPod, ensure you selected a GPU pod template.

### Conda environment issues
```bash
conda env remove -n d2g
./setup_runpod.sh          # or: conda env create -f environment.yml
```

### GUI not accessible on RunPod
- Ensure port 8080 is exposed in your pod configuration, or use `run_with_tunnel.sh` for a Cloudflare tunnel.
- Check `tail -f /tmp/d2g_logs/gui.log` for errors.

---

### Citation
If you find this work useful, please cite:

```bibtex
@inproceedings{zhou2025design2garmentcode,
  title={Design2GarmentCode: Turning Design Concepts to Tangible Garments Through Program Synthesis},
  author={Zhou, Feng and Liu, Ruiyang and Liu, Chen and He, Gaofeng and Li, Yong-Lu and Jin, Xiaogang and Wang, Huamin},
  booktitle={Proceedings of the Computer Vision and Pattern Recognition Conference},
  pages={23712--23722},
  year={2025}
}
```
