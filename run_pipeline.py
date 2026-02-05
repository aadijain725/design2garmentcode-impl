#!/usr/bin/env python
"""CLI entry point for the unified design pipeline.

Usage examples:
    python run_pipeline.py --text "A-line summer dress"
    python run_pipeline.py --images front.jpg back.jpg --output ./results
    python run_pipeline.py --images photo.jpg --text "make it sleeveless" --sim
    python run_pipeline.py --text "pencil skirt" --no-model-init --verbose
"""

import argparse
import json
import logging
import sys
import time
from pathlib import Path

import yaml


def main():
    parser = argparse.ArgumentParser(
        description='Unified Multimodal Design Pipeline')
    parser.add_argument(
        '--images', nargs='+', default=[],
        help='One or more garment image paths')
    parser.add_argument(
        '--text', type=str, default='',
        help='Text design prompt')
    parser.add_argument(
        '--output', type=str, default='./pipeline_output',
        help='Output directory for results')
    parser.add_argument(
        '--sim', action='store_true',
        help='Run 3D simulation after pattern generation')
    parser.add_argument(
        '--no-model-init', action='store_true',
        help='Skip Qwen2-VL model initialization (faster startup)')
    parser.add_argument(
        '--verbose', action='store_true',
        help='Enable DEBUG logging')
    args = parser.parse_args()

    # Configure logging
    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
    )
    logger = logging.getLogger('design2garmentcode.cli')

    if not args.images and not args.text:
        parser.error('At least one of --images or --text is required.')

    # Validate image paths
    for img_path in args.images:
        if not Path(img_path).exists():
            parser.error(f'Image file not found: {img_path}')

    # Create output directory
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    # Import here to avoid slow imports when just checking --help
    from lmm_utils.agent import Agent, PipelineResult

    logger.info("Initializing Agent (model_init=%s)", not args.no_model_init)
    agent = Agent(model_init=not args.no_model_init)

    # Run pipeline
    logger.info("Running design pipeline...")
    start = time.time()
    result: PipelineResult = agent.design(
        images=args.images if args.images else None,
        text=args.text if args.text else None,
    )
    elapsed = time.time() - start
    logger.info("Pipeline completed in %.1fs", elapsed)

    # Save pipeline_result.json
    result_path = output_dir / 'pipeline_result.json'
    result_dict = {
        'input_images': result.input_images,
        'input_text': result.input_text,
        'primary_image': result.primary_image,
        'gpt_response': result.gpt_response,
        'gpt_design_list': result.gpt_design_list,
        'elapsed_seconds': round(elapsed, 2),
    }
    with open(result_path, 'w') as f:
        json.dump(result_dict, f, indent=2, ensure_ascii=False)
    logger.info("Saved pipeline result: %s", result_path)

    # Save caption.json
    if result.caption:
        caption_path = output_dir / 'caption.json'
        with open(caption_path, 'w') as f:
            json.dump(result.caption, f, indent=2, ensure_ascii=False)
        logger.info("Saved caption: %s", caption_path)

    # Save design_params.yaml
    if result.gpt_design_params:
        params_path = output_dir / 'design_params.yaml'
        with open(params_path, 'w') as f:
            yaml.dump(
                {'design': result.gpt_design_params}, f,
                default_flow_style=False, sort_keys=False)
        logger.info("Saved design params: %s", params_path)

    if result.gpt_design_params is None:
        logger.error("Pipeline did not produce design params. Response: %s",
                      result.gpt_response)
        sys.exit(1)

    # 3D simulation (optional)
    if args.sim:
        logger.info("Running 3D simulation...")
        try:
            from gui.gui_pattern import GUIPattern
            gui_pattern = GUIPattern()
            gui_pattern.set_new_design(result.gpt_design_params)
            gui_pattern.design_params = result.gpt_design_params
            gui_pattern.design_list = result.gpt_design_list
            gui_pattern.reload_garment()

            pattern_folder = gui_pattern.save(pack=False)
            logger.info("Saved pattern to: %s", pattern_folder)

            sim_folder, sim_glb = gui_pattern.drape_3d()
            logger.info("Simulation output: %s/%s", sim_folder, sim_glb)

            result.sim_output_path = str(sim_folder)
            result.mesh_path = str(Path(sim_folder) / sim_glb)
        except Exception as e:
            logger.error("Simulation failed: %s", e)
            sys.exit(1)

    print(f"\nDone. Output saved to: {output_dir}")
    if result.gpt_response:
        print(f"GPT Response: {result.gpt_response[:200]}...")


if __name__ == '__main__':
    main()
