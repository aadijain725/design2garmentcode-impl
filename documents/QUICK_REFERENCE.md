# Quick Reference: Function Names & File Locations

## Entry Points (Where to Start)

| Task | File | Function/Method | Line |
|------|------|----------------|------|
| GUI (Interactive) | `gui.py` | `index()` | 12 |
| Batch Text Processing | `lmm_utils/test_text_batch.py` | `main()` | 15 |
| Batch Image Processing | `lmm_utils/test_picture_batch.py` | (similar structure) | - |
| 3D Simulation | `test_garment_sim.py` | `main()` | 36 |

---

## Core Pipeline Functions

### Stage 1: Design Recognition (Text/Image → Parameter List)

| Input Type | File | Class | Method | Line |
|------------|------|-------|--------|------|
| Text | `lmm_utils/core.py` | `MMUA` | `text_gpt()` | 2184 |
| Image | `lmm_utils/core.py` | `MMUA` | `picture_gpt()` | 2079 |
| Modify Design | `lmm_utils/core.py` | `MMUA` | `text_forusermodel_gpt()` | 1901 |
| Stress Analysis | `lmm_utils/core.py` | `MMUA` | `picture_caption_gpt_red()` | 1977 |

**Agent Wrapper (Higher Level):**
| Task | File | Class | Method | Line |
|------|------|-------|--------|------|
| Text Design | `lmm_utils/agent.py` | `Agent` | `text_design()` | 114 |
| Image Design | `lmm_utils/agent.py` | `Agent` | `picture_design()` | 94 |
| Image + Text | `lmm_utils/agent.py` | `Agent` | `picture_text_design()` | 58 |
| Modify Design | `lmm_utils/agent.py` | `Agent` | `modify_design()` | 13 |
| Stress Analysis | `lmm_utils/agent.py` | `Agent` | `stress_design()` | 36 |

---

### Stage 2: Parameter Projection (Image → Numeric Values)

| Task | File | Class | Method | Line |
|------|------|-------|--------|------|
| Predict Parameters | `lmm_utils/predict_garmentcode_picture.py` | `Predictor` | `predict()` | 59 |
| Convert Vector to YAML | `lmm_utils/projector.py` | (function) | `vec_2_pattern_yaml()` | 729 |

---

### Stage 3: Parameter List → YAML

| Task | File | Class | Method | Line |
|------|------|-------|--------|------|
| Convert Caption to YAML | `lmm_utils/predict_garmentcode_picture.py` | `Predictor` | `caption2yaml()` | 104 |
| Fill Default Values | `lmm_utils/projector.py` | (function) | `input_caption2random_default_cption()` | (imported) |

---

### Stage 4: YAML → Pattern JSON

| Task | File | Function/Class | Method | Line |
|------|------|---------------|--------|------|
| YAML to JSON | `lmm_utils/sim_utils.py` | (function) | `garmentyaml_folder2json_folder()` | 16 |
| Complete Pipeline | `lmm_utils/helper.py` | (function) | `category2yaml2json()` | 11 |
| Generate Pattern | `lmm_utils/predict_garmentcode_picture.py` | `Predictor` | `caption_json()` | 463 |

**Garment Construction (Low Level):**
| Component | File | Class/Function |
|-----------|------|---------------|
| Main Assembly | `assets/garment_programs/meta_garment.py` | `MetaGarment` |
| Bodice | `assets/garment_programs/bodice.py` | Various classes |
| Sleeves | `assets/garment_programs/sleeves.py` | Various classes |
| Skirts | `assets/garment_programs/skirt_*.py` | Various classes |
| Pants | `assets/garment_programs/pants.py` | Various classes |

---

### Stage 5: 3D Simulation

| Task | File | Function/Class | Method | Line |
|------|------|---------------|--------|------|
| Run Simulation | `test_garment_sim.py` | (function) | `run_sim()` | 68 |
| Generate Mesh | `pygarment/meshgen/boxmeshgen.py` | `BoxMesh` | `serialize()` | 63 |

---

## Configuration & Data Files

### Configuration
| Purpose | File | Key Settings |
|---------|------|--------------|
| Main Config | `system.json` | API keys, model paths, output dirs |
| Simulation Props | `assets/Sim_props/default_sim_props.yaml` | Cloth physics, resolution |

### Templates
| Purpose | File |
|---------|------|
| Parameter Values | `assets/design_params/default_text_value.yaml` |
| Parameter Structure | `assets/design_params/default_template.yaml` |
| Body Measurements | `assets/bodies/mean_all.yaml` |

---

## Common Modification Tasks

### 1. Change LLM API/Model
**File:** `lmm_utils/core.py`
- **Class:** `MMUA`
- **Method:** `__init__()` (line 1712)
- **Config:** `system.json` (lines 8-14)

### 2. Add/Modify Design Parameters
**Files:**
- `lmm_utils/core.py` - System prompt (lines 14-1697)
- `assets/design_params/default_text_value.yaml` - Default values
- `assets/design_params/default_template.yaml` - Structure

### 3. Change Parameter Projection Model
**File:** `lmm_utils/predict_garmentcode_picture.py`
- **Class:** `Predictor`
- **Method:** `__init__()` (line 25) - Model loading
- **Method:** `predict()` (line 59) - Prediction logic
- **Config:** `system.json` line 14 - Model path

### 4. Modify Body Measurements
**File:** `assets/bodies/mean_all.yaml`
**Used in:** `lmm_utils/sim_utils.py` line 39

### 5. Change Output Location
**Files:**
- `lmm_utils/helper.py` - `category2yaml2json()` (line 11)
- `lmm_utils/predict_garmentcode_picture.py` - `caption_json()` (line 463)
- `system.json` line 2 - Default output directory

### 6. Modify Garment Construction
**Files:** `assets/garment_programs/*.py`
- **Main:** `meta_garment.py` - Assembly logic
- **Components:** `bodice.py`, `sleeves.py`, `pants.py`, etc.

---

## Output File Locations

### Batch Processing
- **Text:** `{output_folder}/{json_filename}/{index}/{index}.json`
- **Image:** `{output_folder}/{image_folder}/{filename}/{filename}.json`

### GUI Processing
- **Temporary:** `user_data/temp_user_folder_for{id}gpt/`
- **Final:** Set via GUI save function

### Simulation
- **Default:** `Logs/{garment_name}/` (from `system.json`)

---

## Key Data Structures

### Parameter List Format
```python
# Example:
["meta__upper__Shirt", "sleeve__length__long", "collar__f_collar__VNeckHalf"]
```

### YAML Structure
```yaml
design:
  meta:
    upper:
      v: "Shirt"
  sleeve:
    length:
      v: 0.75  # Numeric value
```

### JSON Pattern Format
- File: `*_specification.json`
- Contains: Panel definitions, seam information, measurements
- Generated by: `pygarment/pattern/core.py` - `BasicPattern.serialize()`

---

## Testing Commands

### Test Text Input
```bash
python lmm_utils/test_text_batch.py \
  --input assets/test_text/examples.json \
  --output assets/test_text_result \
  --sim
```

### Test Image Input
```bash
python lmm_utils/test_picture_batch.py \
  --input assets/test_img/examples \
  --output assets/test_image_result/examples \
  --sim
```

### Test Simulation
```bash
python test_garment_sim.py \
  --pattern_spec assets/Patterns/shirt_mean_specification.json \
  --body mean_all \
  --sim_config assets/Sim_props/default_sim_props.yaml
```

---

## Debugging Tips

1. **Check LLM Response:**
   - Look for `gpt_respond.txt` in output folder
   - Check console output for parameter extraction

2. **Verify Parameter List:**
   - Check `caption.json` in output folder
   - Should contain array of parameter strings

3. **Inspect YAML:**
   - Check `*.yaml` file in output folder
   - Verify all required parameters are set

4. **Pattern Generation Issues:**
   - Check `user_data/temp_user_folder_for{id}gpt/` for intermediate files
   - Look for error messages in console

5. **Simulation Issues:**
   - Verify pattern JSON exists and is valid
   - Check simulation config file exists
   - Ensure body file exists
