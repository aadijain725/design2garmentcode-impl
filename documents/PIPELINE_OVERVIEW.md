# Design2GarmentCode Pipeline Overview

## What This System Does
Converts design concepts (text descriptions, images, or sketches) into sewing pattern files (JSON) and optionally 3D garment simulations.

---

## Pipeline Flow: Inputs → Stages → Outputs

### **INPUTS** (3 types supported)

1. **Text Description** 
   - Example: "I want to go to the beach"
   - File: `lmm_utils/test_text_batch.py` (batch) or GUI (single)

2. **Image** 
   - Photo/sketch of a garment
   - File: `lmm_utils/test_picture_batch.py` (batch) or GUI (single)

3. **Design Parameter List** (already extracted)
   - List of parameter strings like `["meta__upper__Shirt", "sleeve__length__long"]`
   - Used for modifications

---

## **PIPELINE STAGES**

### **Stage 1: Design Recognition** 
**What it does:** Extracts garment design parameters from input

**Key Files:**
- `lmm_utils/core.py` - Contains `MMUA` class with methods:
  - `text_gpt()` - Processes text input
  - `picture_gpt()` - Processes image input
  - `text_forusermodel_gpt()` - Modifies existing design based on text

**How it works:**
- Uses GPT-4o (or configured LLM) to analyze input
- Returns a list of parameter strings (e.g., `["meta__upper__Shirt", "sleeve__length__long"]`)
- These parameters map to 400+ design options (necklines, sleeves, skirts, etc.)

**Output:** List of parameter strings (called `caption` or `design_list`)

---

### **Stage 2: Parameter Projection** (Optional but important)
**What it does:** Refines numeric parameters using a vision model

**Key Files:**
- `lmm_utils/predict_garmentcode_picture.py` - Contains `Predictor` class
- `lmm_utils/fintuned_qwen2vl_model.py` - Fine-tuned Qwen2-VL-2B model
- `lmm_utils/projector.py` - Converts model output to YAML values

**How it works:**
- If an image was provided, uses fine-tuned Qwen2-VL-2B-Instruct model
- Takes the parameter list + image
- Predicts continuous numeric values (e.g., exact sleeve width, neckline depth)
- These values refine the discrete choices from Stage 1

**Output:** Refined parameter list with numeric values

---

### **Stage 3: Parameter List → YAML**
**What it does:** Converts parameter strings into structured YAML design file

**Key Files:**
- `lmm_utils/predict_garmentcode_picture.py` - Method `caption2yaml()`
- `lmm_utils/projector.py` - Helper functions
- `assets/design_params/default_text_value.yaml` - Template with default values
- `assets/design_params/default_template.yaml` - Template structure

**How it works:**
- Takes parameter list (e.g., `["meta__upper__Shirt", "sleeve__length__long"]`)
- Parses each parameter (splits by `__` to navigate nested structure)
- Fills in YAML template with selected values
- Handles special cases (dress lengths, body measurements, etc.)

**Output:** YAML file (e.g., `now_root.yaml`) with complete design specification

---

### **Stage 4: YAML → Sewing Pattern JSON**
**What it does:** Generates actual sewing pattern from YAML design parameters

**Key Files:**
- `lmm_utils/sim_utils.py` - Function `garmentyaml_folder2json_folder()`
- `assets/garment_programs/` - Contains garment construction code:
  - `meta_garment.py` - Main garment assembly
  - `bodice.py`, `sleeves.py`, `pants.py`, `skirt_levels.py`, etc. - Individual components
- `assets/bodies/` - Body measurement files (e.g., `mean_all.yaml`)

**How it works:**
- Loads YAML design file
- Loads body measurements
- Executes garment program code (in `assets/garment_programs/`)
- Generates 2D sewing pattern pieces
- Saves as JSON specification file (e.g., `now_root_specification.json`)

**Output:** JSON file with sewing pattern specification + pattern image (PNG)

---

### **Stage 5: 3D Simulation** (Optional)
**What it does:** Simulates how the garment drapes on a 3D body

**Key Files:**
- `test_garment_sim.py` - Main simulation script
- `pygarment/meshgen/` - Mesh generation and simulation code
- `assets/Sim_props/` - Simulation configuration files

**How it works:**
- Takes pattern JSON file
- Generates 3D mesh from pattern pieces
- Runs physics simulation (cloth draping)
- Renders front/back views

**Output:** 3D rendered images (PNG files)

---

## **OUTPUTS**

### Main Output Files:
1. **`*_specification.json`** - Sewing pattern specification (main output)
2. **`*_pattern.png`** - Visual representation of 2D pattern pieces
3. **`*.yaml`** - Design parameters (for reference/modification)
4. **`caption.json`** - Original parameter list extracted
5. **`gpt_respond.txt`** - LLM response text
6. **`sim_garment_front.png`** / **`sim_garment_back.png`** - 3D simulation (if enabled)

---

## **MODIFICATION POINTS** (Where to Make Changes)

### 1. **Change LLM Model/API**
   - **File:** `lmm_utils/core.py`
   - **Location:** `MMUA.__init__()` method (lines 1712-1739)
   - **What to change:** `api_key`, `base_url`, `model` parameters
   - **Config file:** `system.json` (lines 12-13)

### 2. **Add New Design Parameters**
   - **Files:**
     - `lmm_utils/core.py` - Add to `origin_messages` system prompt (lines 14-1697)
     - `assets/design_params/default_text_value.yaml` - Add parameter values
     - `assets/design_params/default_template.yaml` - Add parameter structure
   - **Note:** This is complex - requires updating the "text space" in the LLM prompt

### 3. **Modify Parameter Projection Model**
   - **File:** `lmm_utils/predict_garmentcode_picture.py`
   - **Location:** `Predictor.__init__()` (line 25) and `predict()` method (line 59)
   - **What to change:** Model path, mask_list (which parameters to predict)

### 4. **Change Body Measurements**
   - **File:** `assets/bodies/mean_all.yaml` (or other body files)
   - **Usage:** Referenced in `lmm_utils/sim_utils.py` (line 39)

### 5. **Modify Garment Construction Logic**
   - **Files:** `assets/garment_programs/*.py`
   - **Key file:** `meta_garment.py` - Main assembly logic
   - **Note:** These are complex geometric programs - requires understanding garment construction

### 6. **Change Simulation Settings**
   - **File:** `assets/Sim_props/default_sim_props.yaml`
   - **Usage:** Loaded in `test_garment_sim.py` (line 40)

### 7. **Modify Output Format/Location**
   - **Files:**
     - `lmm_utils/helper.py` - Function `category2yaml2json()` (lines 11-153)
     - `lmm_utils/predict_garmentcode_picture.py` - Method `caption_json()` (line 463)
   - **What to change:** File paths, output folder structure

---

## **KEY COMMANDS**

### Run GUI (Interactive):
```bash
python gui.py
# Opens web interface at http://localhost:8080
```

### Batch Text Processing:
```bash
python lmm_utils/test_text_batch.py \
  --input assets/test_text/examples.json \
  --output assets/test_text_result \
  --sim
```
**Expected outputs:** `assets/test_text_result/examples/{index}/{index}.json` + pattern images

### Batch Image Processing:
```bash
python lmm_utils/test_picture_batch.py \
  --input assets/test_img/examples \
  --output assets/test_image_result/examples \
  --sim
```
**Expected outputs:** `assets/test_image_result/examples/{filename}/{filename}.json` + pattern images

### Run 3D Simulation (from existing pattern):
```bash
python test_garment_sim.py --pattern_spec path/to/pattern_specification.json
```
**Expected outputs:** `Logs/{garment_name}/` with simulation results

---

## **DATA FLOW DIAGRAM**

```
INPUT (Text/Image)
    ↓
[Stage 1] MMUA.text_gpt() / MMUA.picture_gpt()
    ↓
Parameter List (e.g., ["meta__upper__Shirt", ...])
    ↓
[Stage 2] Predictor.predict() [if image provided]
    ↓
Refined Parameter List with Numeric Values
    ↓
[Stage 3] Predictor.caption2yaml()
    ↓
YAML Design File (now_root.yaml)
    ↓
[Stage 4] garmentyaml_folder2json_folder()
    ↓
Pattern JSON (now_root_specification.json) + Pattern PNG
    ↓
[Stage 5] test_garment_sim.py [optional]
    ↓
3D Simulation Images (sim_garment_front.png, sim_garment_back.png)
```

---

## **IMPORTANT CONFIGURATION FILES**

1. **`system.json`** - Main configuration
   - API keys, model paths, output directories
   
2. **`assets/design_params/default_text_value.yaml`** - Default parameter values
   
3. **`assets/design_params/default_template.yaml`** - Parameter structure template
   
4. **`assets/bodies/mean_all.yaml`** - Default body measurements
   
5. **`assets/Sim_props/default_sim_props.yaml`** - Simulation settings

---

## **TROUBLESHOOTING CHECKLIST**

If something isn't working:

1. **Check API keys** in `system.json` or environment variable `OPENAI_API_KEY`
2. **Verify model files exist:**
   - `lmm_utils/Qwen/Qwen2-VL-2B-Instruct/` (base model)
   - `lmm_utils/Qwen/qwen2vl_lora_mlp/model.pth` (fine-tuned weights)
3. **Check output directories** - Make sure `Logs/` and `user_data/` are writable
4. **Verify input format:**
   - Text: JSON array of strings for batch, single string for GUI
   - Image: Standard image formats (JPG, PNG, etc.)

---

## **NEXT STEPS TO EXPLORE**

1. **Inspect parameter extraction:**
   - Look at `lmm_utils/core.py` lines 2184-2260 (`text_gpt` method)
   - See how LLM response is parsed into parameter list

2. **Understand YAML structure:**
   - Open `assets/design_params/default_template.yaml`
   - See how parameters map to nested dictionary structure

3. **Examine pattern generation:**
   - Look at `assets/garment_programs/meta_garment.py`
   - See how YAML parameters drive geometric construction

4. **Test a simple modification:**
   - Change default body in `lmm_utils/sim_utils.py` line 37
   - Run a test to see how output changes
