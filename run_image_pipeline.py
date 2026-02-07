#!/usr/bin/env python3
"""
Run the image-to-pattern pipeline from command line.

Usage:
    python run_image_pipeline.py path/to/image.jpg [--output /path/to/output] [--no-sim]

Examples:
    python run_image_pipeline.py assets/dress_clo_input/Dress_Clo.jpg
    python run_image_pipeline.py my_dress.png --output ./results --no-sim
"""

import argparse
import sys
import os

# CRITICAL: Initialize warp BEFORE adding /app to path
# The /app/warp folder shadows the real warp-lang package
import warp as wp
wp.init()

# Now safe to add /app and import
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
os.chdir(os.path.dirname(os.path.abspath(__file__)))

from lmm_utils.agent import Agent
from gui.gui_pattern import GUIPattern


def main():
    parser = argparse.ArgumentParser(
        description='Image to Sewing Pattern Pipeline',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    python run_image_pipeline.py assets/dress_clo_input/Dress_Clo.jpg
    python run_image_pipeline.py photo.png --output ./my_patterns
    python run_image_pipeline.py sketch.jpg --no-sim  # Skip 3D simulation
        """
    )
    parser.add_argument('image', help='Path to input image (JPG/PNG)')
    parser.add_argument('--output', '-o', default=None, 
                        help='Output directory (default: auto-generated in tmp_gui/downloads)')
    parser.add_argument('--no-sim', action='store_true',
                        help='Skip 3D physics simulation (faster, pattern only)')
    parser.add_argument('--verbose', '-v', action='store_true',
                        help='Show detailed progress')
    
    args = parser.parse_args()
    
    # Validate input
    if not os.path.exists(args.image):
        print(f"Error: Image not found: {args.image}")
        sys.exit(1)
    
    print(f"Loading models...")
    agent = Agent()
    print(f"Models loaded.\n")
    
    # Stage 1-2: GPT-4o + Qwen2-VL
    print(f"Processing image: {args.image}")
    print(f"  Stage 1: MMUA (GPT-4o) analyzing design...")
    print(f"  Stage 2: DSL-GA (Qwen2-VL) generating parameters...")
    
    result = agent.design(images=[args.image])
    
    if not result.gpt_design_params:
        print(f"Error: Pipeline failed. GPT response: {result.gpt_response}")
        sys.exit(1)
    
    if args.verbose:
        print(f"\nDetected design: {result.gpt_design_list[:5]}...")
    
    # Stage 3: Generate pattern
    print(f"  Stage 3: GarmentCode generating pattern...")
    gp = GUIPattern()
    gp.set_new_design(result.gpt_design_params)
    gp.design_params = result.gpt_design_params
    gp.design_list = result.gpt_design_list
    gp.reload_garment()
    
    pattern_folder = gp.save(pack=False)
    print(f"\n✓ Pattern saved: {pattern_folder}")
    print(f"  - pattern.png/svg (sewing pattern)")
    print(f"  - print_pattern.pdf (printable)")
    print(f"  - specification.json (measurements)")
    
    # Stage 4: 3D Simulation (optional)
    if not args.no_sim:
        print(f"\n  Stage 4: Warp physics simulation...")
        sim_folder, sim_glb = gp.drape_3d()
        print(f"\n✓ 3D simulation: {sim_folder}/{sim_glb}")
        print(f"  - *_sim.glb (3D mesh)")
        print(f"  - *_render_front/back.png (previews)")
    
    print(f"\nDone!")


if __name__ == '__main__':
    main()
