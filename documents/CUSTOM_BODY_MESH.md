# Custom Body Mesh Integration Guide

This guide explains how to use custom body meshes (e.g., SMPL-X, custom scans) with Design2GarmentCode for personalized sewing pattern generation.

---

## Quick Start

```bash
# Setup a custom SMPL-X body mesh
python scripts/setup_custom_body.py \
    --mesh assets/test_mesh/smplx_mesh.obj \
    --name smplx \
    --auto-transform \
    --height 169

# Then run the GUI
python gui.py
```

---

## Overview

Design2GarmentCode generates sewing patterns based on body measurements. The system uses:

1. **Body Mesh (OBJ)** - 3D mesh for cloth simulation and visualization
2. **Body Measurements (YAML)** - Numeric measurements for pattern construction

Both files must have the same base name (e.g., `smplx.obj` and `smplx.yaml`).

---

## Requirements for Body Meshes

### Coordinate System

| Property | Required Value |
|----------|---------------|
| Units | Meters (1 unit = 1 meter) |
| Y-axis | Up (height direction) |
| Origin | Feet at Y=0 |
| Pose | A-pose recommended (arms ~45 degrees from body) |

### Mesh Quality

- **Vertices**: 5,000+ recommended for smooth simulation
- **Format**: Wavefront OBJ (ASCII)
- **Topology**: Closed, manifold mesh preferred
- **Scale**: ~1.7 meters tall for adult human

---

## Using the Setup Script

### Basic Usage

```bash
python scripts/setup_custom_body.py --mesh <input.obj> --name <body_name> [options]
```

### Options

| Option | Description |
|--------|-------------|
| `--mesh, -m` | Path to input OBJ mesh (required) |
| `--name, -n` | Name for output files (required) |
| `--measurements, -M` | Path to custom measurements YAML |
| `--auto-transform, -a` | Transform mesh so feet are at Y=0 |
| `--height, -H` | Body height in cm (default: 170) |
| `--output-dir, -o` | Output directory (default: assets/bodies/) |
| `--force, -f` | Overwrite existing files |
| `--dry-run` | Preview changes without writing |
| `--smpl-segmentation, -s` | Use SMPL vertex segmentation |

### Examples

**1. SMPL-X mesh with auto-transform:**
```bash
python scripts/setup_custom_body.py \
    --mesh assets/test_mesh/smplx_mesh.obj \
    --name smplx \
    --auto-transform \
    --height 169
```

**2. Custom scan with known measurements:**
```bash
python scripts/setup_custom_body.py \
    --mesh my_scan.obj \
    --name my_body \
    --measurements my_measurements.yaml
```

**3. Preview without making changes:**
```bash
python scripts/setup_custom_body.py \
    --mesh input.obj \
    --name test \
    --dry-run
```

---

## Body Measurements File Format

The YAML file contains body measurements in centimeters:

```yaml
body:
  # Primary measurements (required for pattern generation)
  height: 170.0           # Total body height
  bust: 92.0              # Bust circumference
  waist: 74.0             # Waist circumference
  hips: 98.0              # Hip circumference

  # Torso measurements
  underbust: 78.0         # Underbust circumference
  bust_line: 25.0         # Shoulder to bust distance
  waist_line: 38.0        # Shoulder to waist distance
  hips_line: 23.0         # Waist to hip distance

  # Width measurements
  shoulder_w: 38.0        # Shoulder width (across back)
  back_width: 36.0        # Back width at armhole level
  waist_back_width: 32.0  # Back width at waist
  hip_back_width: 38.0    # Back width at hip
  neck_w: 14.0            # Neck width

  # Arm measurements
  arm_length: 55.0        # Shoulder to wrist
  arm_pose_angle: 45.0    # Arm angle from body (degrees)
  armscye_depth: 12.0     # Armhole depth
  wrist: 16.0             # Wrist circumference

  # Additional measurements
  shoulder_incl: 22.0     # Shoulder slope (degrees)
  hip_inclination: 10.0   # Hip tilt (degrees)
  bust_points: 18.0       # Distance between bust points
  bum_points: 18.0        # Distance between bum points
  crotch_hip_diff: 8.0    # Crotch depth below hip
  head_l: 24.0            # Head length
  leg_circ: 55.0          # Upper leg circumference
  vert_bust_line: 20.0    # Vertical bust line
  waist_over_bust_line: 40.0  # Waist over bust measurement
```

### Getting Accurate Measurements

For best results, provide actual body measurements rather than estimates:

1. **From SMPL-X parameters**: Use the SMPL-X body shape parameters (beta values) to compute measurements
2. **From 3D scan software**: Many scanning apps provide body measurements
3. **Manual measurement**: Traditional tape measure approach

---

## Integrating with the System

After running the setup script, you need to update the code to use your new body:

### 1. Update sim_utils.py

Add your body to the `bodies_measurements` dictionary in `lmm_utils/sim_utils.py`:

```python
bodies_measurements = {
    'neutral': './assets/bodies/mean_all.yaml',
    'mean_female': './assets/bodies/mean_female.yaml',
    'mean_male': './assets/bodies/mean_male.yaml',
    'f_smpl': './assets/bodies/f_smpl_average_A40.yaml',
    'm_smpl': './assets/bodies/m_smpl_average_A40.yaml',
    'mean_all_tpose': './assets/bodies/mean_all_tpose.yaml',
    'smplx': './assets/bodies/smplx.yaml',  # <-- Add your body
}
```

### 2. Update GUI (Optional)

To use your body as the default in the GUI, edit `gui/gui_pattern.py`:

```python
# Line 56
self.body_id = 'smplx'  # Change from 'mean_all'
```

### 3. For SMPL/SMPL-X Meshes

If using an SMPL-family mesh, set `smpl_body=True` in simulation configs to use the correct vertex segmentation:

```python
# In PathCofig instantiation
paths = PathCofig(
    ...
    smpl_body=True,  # Use SMPL vertex segmentation
)
```

---

## Troubleshooting

### Mesh appears underground or floating

**Cause**: Y-origin not at feet level

**Solution**: Use `--auto-transform` flag or manually transform the mesh

### Patterns don't fit the body

**Cause**: Inaccurate body measurements

**Solution**: Provide actual measurements via `--measurements` flag

### Simulation crashes or looks wrong

**Cause**: Mesh topology issues or wrong segmentation

**Solution**:
- Ensure mesh is watertight
- Check vertex count (should be >5000)
- For SMPL meshes, use `--smpl-segmentation`

### "Mesh height is too small" error

**Cause**: Mesh units are not meters

**Solution**: Scale your mesh so 1 unit = 1 meter before importing

---

## File Locations

| File | Location | Purpose |
|------|----------|---------|
| Body meshes | `assets/bodies/*.obj` | 3D body geometry |
| Body measurements | `assets/bodies/*.yaml` | Pattern construction parameters |
| Segmentation | `assets/bodies/ggg_body_segmentation.json` | Body part labels (default) |
| SMPL segmentation | `assets/bodies/smpl_vert_segmentation.json` | Body part labels (SMPL) |
| Setup script | `scripts/setup_custom_body.py` | Mesh preparation tool |

---

## Pre-configured Bodies

The system includes these pre-configured bodies:

| Name | Description | Source |
|------|-------------|--------|
| `mean_all` | Average body (neutral) | GarmentCode |
| `mean_female` | Average female body | GarmentCode |
| `mean_male` | Average male body | GarmentCode |
| `f_smpl_average_A40` | SMPL female average, A-pose 40deg | SMPL |
| `m_smpl_average_A40` | SMPL male average, A-pose 40deg | SMPL |
| `mean_all_tpose` | Average body in T-pose | GarmentCode |
| `smplx` | SMPL-X body (custom) | Custom |

---

## Advanced: Extracting Measurements from SMPL-X

If you have SMPL-X body parameters, you can compute measurements:

```python
import smplx
import torch

# Load SMPL-X model
model = smplx.create('models/', model_type='smplx')

# Set body shape (betas)
betas = torch.zeros(1, 10)  # or your custom betas
output = model(betas=betas)

# Get vertices and compute measurements
vertices = output.vertices.detach().numpy()[0]

# Example: compute waist circumference
# (requires identifying waist vertices and computing perimeter)
```

For a complete measurement extraction script, see the SMPL-X documentation.

---

## See Also

- [PIPELINE_OVERVIEW.md](PIPELINE_OVERVIEW.md) - Full pipeline documentation
- [SETUP_AND_RUN.md](SETUP_AND_RUN.md) - Installation and running guide
- [SMPL-X Documentation](https://smpl-x.is.tue.mpg.de/) - SMPL-X model details
