#!/usr/bin/env python
"""
Setup Custom Body Mesh for Design2GarmentCode

This script prepares a custom body mesh (e.g., SMPL-X) for use with the
Design2GarmentCode pipeline. It handles mesh transformation, body measurements,
and integration with the existing system.

Usage:
    python scripts/setup_custom_body.py --mesh path/to/mesh.obj --name my_body
    python scripts/setup_custom_body.py --mesh path/to/mesh.obj --name my_body --measurements path/to/measurements.yaml
    python scripts/setup_custom_body.py --mesh path/to/mesh.obj --name my_body --auto-transform

See documents/CUSTOM_BODY_MESH.md for detailed documentation.
"""

import argparse
import shutil
import sys
from pathlib import Path

import numpy as np
import yaml


def load_obj_vertices(obj_path: Path) -> np.ndarray:
    """Load vertex positions from an OBJ file."""
    vertices = []
    with open(obj_path, 'r') as f:
        for line in f:
            if line.startswith('v '):
                parts = line.strip().split()
                vertices.append([float(parts[1]), float(parts[2]), float(parts[3])])
    return np.array(vertices)


def get_mesh_bounds(vertices: np.ndarray) -> dict:
    """Calculate bounding box of mesh vertices."""
    return {
        'min': vertices.min(axis=0),
        'max': vertices.max(axis=0),
        'center': vertices.mean(axis=0),
        'height': vertices[:, 1].max() - vertices[:, 1].min(),
        'y_min': vertices[:, 1].min(),
        'y_max': vertices[:, 1].max(),
    }


def transform_mesh_to_ground(input_path: Path, output_path: Path, y_offset: float) -> None:
    """
    Transform mesh so that the lowest point is at Y=0.

    Args:
        input_path: Path to input OBJ file
        output_path: Path to output OBJ file
        y_offset: Value to add to Y coordinates
    """
    with open(input_path, 'r') as f_in, open(output_path, 'w') as f_out:
        for line in f_in:
            if line.startswith('v '):
                parts = line.strip().split()
                x, y, z = float(parts[1]), float(parts[2]), float(parts[3])
                f_out.write(f"v {x} {y + y_offset:.10f} {z}\n")
            else:
                f_out.write(line)


def estimate_body_measurements(vertices: np.ndarray, height_cm: float) -> dict:
    """
    Estimate body measurements from mesh vertices.

    This provides rough estimates - for accurate patterns,
    provide actual measurements via --measurements flag.

    Args:
        vertices: Mesh vertex positions (after Y transformation)
        height_cm: Body height in centimeters

    Returns:
        Dictionary of body measurements
    """
    # Scale factor from mesh units to cm
    mesh_height = vertices[:, 1].max() - vertices[:, 1].min()
    scale = height_cm / (mesh_height * 100) if mesh_height < 10 else height_cm / mesh_height

    # Find approximate body regions by Y coordinate
    y_normalized = (vertices[:, 1] - vertices[:, 1].min()) / mesh_height

    # Rough body proportions (normalized from feet=0 to head=1)
    waist_level = 0.58  # ~58% up from feet
    hip_level = 0.52    # ~52% up from feet
    bust_level = 0.72   # ~72% up from feet
    shoulder_level = 0.82  # ~82% up from feet

    def get_circumference_at_level(level: float, tolerance: float = 0.02) -> float:
        """Estimate circumference at a given normalized Y level."""
        mask = np.abs(y_normalized - level) < tolerance
        if not mask.any():
            return 0.0
        level_verts = vertices[mask]
        # Approximate circumference as perimeter of bounding box * pi/2
        x_range = level_verts[:, 0].max() - level_verts[:, 0].min()
        z_range = level_verts[:, 2].max() - level_verts[:, 2].min()
        # Ellipse circumference approximation
        a, b = x_range / 2, z_range / 2
        circumference = np.pi * (3 * (a + b) - np.sqrt((3 * a + b) * (a + 3 * b)))
        return circumference * scale * 100  # Convert to cm

    def get_width_at_level(level: float, tolerance: float = 0.02) -> float:
        """Get width (X extent) at a given normalized Y level."""
        mask = np.abs(y_normalized - level) < tolerance
        if not mask.any():
            return 0.0
        level_verts = vertices[mask]
        return (level_verts[:, 0].max() - level_verts[:, 0].min()) * scale * 100

    # Estimate measurements
    measurements = {
        'height': height_cm,
        'bust': get_circumference_at_level(bust_level),
        'waist': get_circumference_at_level(waist_level),
        'hips': get_circumference_at_level(hip_level),
        'underbust': get_circumference_at_level(bust_level - 0.05),
        'shoulder_w': get_width_at_level(shoulder_level),
        'back_width': get_width_at_level(bust_level) * 0.95,
        'waist_back_width': get_width_at_level(waist_level) * 0.95,
        'hip_back_width': get_width_at_level(hip_level) * 0.95,

        # Derived/estimated values (these are approximations)
        'arm_length': height_cm * 0.314,  # ~31.4% of height
        'arm_pose_angle': 45.0,
        'armscye_depth': height_cm * 0.075,
        'bum_points': height_cm * 0.106,
        'bust_line': height_cm * 0.149,
        'bust_points': height_cm * 0.099,
        'crotch_hip_diff': height_cm * 0.051,
        'head_l': height_cm * 0.153,
        'hips_line': height_cm * 0.137,
        'leg_circ': height_cm * 0.350,
        'neck_w': height_cm * 0.110,
        'shoulder_incl': 21.5,  # degrees
        'hip_inclination': 10.0,  # degrees
        'vert_bust_line': height_cm * 0.123,
        'waist_line': height_cm * 0.215,
        'waist_over_bust_line': height_cm * 0.236,
        'wrist': height_cm * 0.097,
    }

    # Ensure reasonable minimums
    for key in ['bust', 'waist', 'hips', 'underbust']:
        if measurements[key] < 50:  # Unreasonably small
            measurements[key] = 85.0  # Default fallback

    return measurements


def create_body_yaml(measurements: dict, output_path: Path) -> None:
    """Create body measurements YAML file."""
    content = {'body': measurements}
    with open(output_path, 'w') as f:
        yaml.dump(content, f, default_flow_style=False, sort_keys=False)


def copy_mesh(input_path: Path, output_path: Path) -> None:
    """Copy mesh file to destination."""
    shutil.copy2(input_path, output_path)


def validate_mesh(obj_path: Path) -> tuple[bool, str]:
    """
    Validate that the OBJ file is suitable for use.

    Returns:
        Tuple of (is_valid, message)
    """
    if not obj_path.exists():
        return False, f"File not found: {obj_path}"

    if obj_path.suffix.lower() != '.obj':
        return False, f"Expected .obj file, got: {obj_path.suffix}"

    try:
        vertices = load_obj_vertices(obj_path)
        if len(vertices) == 0:
            return False, "No vertices found in mesh"
        if len(vertices) < 100:
            return False, f"Mesh has only {len(vertices)} vertices - expected a body mesh"

        bounds = get_mesh_bounds(vertices)
        if bounds['height'] < 0.1:
            return False, f"Mesh height ({bounds['height']:.3f}) is too small"
        if bounds['height'] > 100:
            return False, f"Mesh height ({bounds['height']:.1f}) suggests unusual units"

        return True, f"Valid mesh: {len(vertices)} vertices, height={bounds['height']:.3f}"
    except Exception as e:
        return False, f"Error reading mesh: {e}"


def update_sim_utils_bodies(bodies_path: Path, body_name: str) -> None:
    """
    Print instructions for updating sim_utils.py to include the new body.
    """
    print(f"\n--- Manual Step Required ---")
    print(f"Add the following line to lmm_utils/sim_utils.py in the bodies_measurements dict:")
    print(f"    '{body_name}': './assets/bodies/{body_name}.yaml',")
    print(f"----------------------------\n")


def main():
    parser = argparse.ArgumentParser(
        description='Setup a custom body mesh for Design2GarmentCode',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic setup with auto-transform
  python scripts/setup_custom_body.py --mesh my_body.obj --name custom1 --auto-transform

  # With custom measurements
  python scripts/setup_custom_body.py --mesh my_body.obj --name custom1 --measurements body_measurements.yaml

  # Specify height for measurement estimation
  python scripts/setup_custom_body.py --mesh my_body.obj --name custom1 --auto-transform --height 175

See documents/CUSTOM_BODY_MESH.md for detailed documentation.
        """
    )

    parser.add_argument('--mesh', '-m', type=Path, required=True,
                        help='Path to input body mesh OBJ file')
    parser.add_argument('--name', '-n', type=str, required=True,
                        help='Name for the body (used for output files)')
    parser.add_argument('--measurements', '-M', type=Path, default=None,
                        help='Path to body measurements YAML file (optional)')
    parser.add_argument('--auto-transform', '-a', action='store_true',
                        help='Automatically transform mesh so feet are at Y=0')
    parser.add_argument('--height', '-H', type=float, default=170.0,
                        help='Body height in cm for measurement estimation (default: 170)')
    parser.add_argument('--output-dir', '-o', type=Path, default=None,
                        help='Output directory (default: assets/bodies/)')
    parser.add_argument('--force', '-f', action='store_true',
                        help='Overwrite existing files')
    parser.add_argument('--dry-run', action='store_true',
                        help='Show what would be done without making changes')
    parser.add_argument('--smpl-segmentation', '-s', action='store_true',
                        help='Use SMPL vertex segmentation (for SMPL/SMPL-X meshes)')

    args = parser.parse_args()

    # Determine paths
    script_dir = Path(__file__).parent
    project_root = script_dir.parent
    bodies_dir = args.output_dir or (project_root / 'assets' / 'bodies')

    output_mesh = bodies_dir / f'{args.name}.obj'
    output_yaml = bodies_dir / f'{args.name}.yaml'

    # Validate input
    print(f"Validating input mesh: {args.mesh}")
    is_valid, message = validate_mesh(args.mesh)
    if not is_valid:
        print(f"ERROR: {message}")
        sys.exit(1)
    print(f"  {message}")

    # Check for existing files
    if not args.force:
        if output_mesh.exists():
            print(f"ERROR: Output mesh already exists: {output_mesh}")
            print("Use --force to overwrite")
            sys.exit(1)
        if output_yaml.exists():
            print(f"ERROR: Output YAML already exists: {output_yaml}")
            print("Use --force to overwrite")
            sys.exit(1)

    # Load and analyze mesh
    vertices = load_obj_vertices(args.mesh)
    bounds = get_mesh_bounds(vertices)

    print(f"\nMesh analysis:")
    print(f"  Vertices: {len(vertices)}")
    print(f"  Height: {bounds['height']:.3f}")
    print(f"  Y range: [{bounds['y_min']:.3f}, {bounds['y_max']:.3f}]")
    print(f"  Center: [{bounds['center'][0]:.3f}, {bounds['center'][1]:.3f}, {bounds['center'][2]:.3f}]")

    # Determine if transformation is needed
    needs_transform = abs(bounds['y_min']) > 0.01
    y_offset = -bounds['y_min'] if needs_transform else 0

    if needs_transform:
        print(f"\n  Mesh Y-min is {bounds['y_min']:.3f}, not at ground level.")
        if args.auto_transform:
            print(f"  Will transform by Y+{y_offset:.3f} to place feet at Y=0")
        else:
            print(f"  Consider using --auto-transform to fix this")

    if args.dry_run:
        print("\n--- DRY RUN - No changes made ---")
        print(f"Would create: {output_mesh}")
        print(f"Would create: {output_yaml}")
        if args.smpl_segmentation:
            print(f"Would use SMPL vertex segmentation")
        return

    # Process mesh
    print(f"\nProcessing mesh...")
    if args.auto_transform and needs_transform:
        print(f"  Transforming mesh (Y offset: {y_offset:.3f})")
        transform_mesh_to_ground(args.mesh, output_mesh, y_offset)
    else:
        print(f"  Copying mesh without transformation")
        copy_mesh(args.mesh, output_mesh)
    print(f"  Saved to: {output_mesh}")

    # Handle measurements
    if args.measurements:
        print(f"\nUsing provided measurements: {args.measurements}")
        shutil.copy2(args.measurements, output_yaml)
    else:
        print(f"\nEstimating body measurements (height={args.height}cm)")
        print("  NOTE: For accurate patterns, provide actual measurements via --measurements")

        # Reload vertices if transformed
        if args.auto_transform and needs_transform:
            vertices = load_obj_vertices(output_mesh)

        measurements = estimate_body_measurements(vertices, args.height)
        create_body_yaml(measurements, output_yaml)
    print(f"  Saved to: {output_yaml}")

    # Summary
    print(f"\n{'='*50}")
    print(f"SUCCESS: Body '{args.name}' set up successfully!")
    print(f"{'='*50}")
    print(f"\nFiles created:")
    print(f"  Mesh: {output_mesh}")
    print(f"  Measurements: {output_yaml}")

    update_sim_utils_bodies(bodies_dir, args.name)

    print(f"To use this body in the GUI, modify gui/gui_pattern.py line 56:")
    print(f"    self.body_id = '{args.name}'")

    if args.smpl_segmentation:
        print(f"\nFor SMPL/SMPL-X meshes, set smpl_body=True in PathCofig calls")

    print(f"\nTo test pattern generation:")
    print(f"    python gui.py")
    print(f"    # Then use 'PARSE DESIGN' tab with a text prompt")


if __name__ == '__main__':
    main()
