#!/usr/bin/env python3
"""
Download Qwen2-VL-2B-Instruct from Hugging Face to a local directory.

Uses the huggingface_hub Python API (snapshot_download). Supports resume:
re-run the script after an interruption to continue; already-complete files
are skipped. Works with Python 3.9 and does not require huggingface-cli.

Usage:
    python3 download_qwen2vl_2b_instruct.py [--local-dir DIR] [--verify-only] [--force]

Use a Python that has huggingface_hub (e.g. /usr/local/bin/python3 if that's
where it is installed). See lmm_utils/Qwen/DOWNLOAD_README.md for details.

Authentication (if the model becomes gated):
    export HF_TOKEN=your_token
"""

from __future__ import annotations

import argparse
import os
import sys


# Required model files for loading offline (from Hugging Face repo structure)
REQUIRED_FILES = [
    "config.json",
    "preprocessor_config.json",
    "tokenizer_config.json",
    "tokenizer.json",
    "vocab.json",
    "merges.txt",
    "model.safetensors.index.json",
    "model-00001-of-00002.safetensors",
    "model-00002-of-00002.safetensors",
]

OPTIONAL_FILES = [
    "generation_config.json",
    "chat_template.json",
]


def get_default_local_dir() -> str:
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "Qwen2-VL-2B-Instruct")


def verify_download(local_dir: str) -> tuple[bool, list[str], list[str]]:
    """Check that required and optional files exist. Returns (ok, missing_required, missing_optional)."""
    missing_required = [f for f in REQUIRED_FILES if not os.path.isfile(os.path.join(local_dir, f))]
    missing_optional = [f for f in OPTIONAL_FILES if not os.path.isfile(os.path.join(local_dir, f))]
    return (len(missing_required) == 0, missing_required, missing_optional)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Download Qwen2-VL-2B-Instruct from Hugging Face to a local directory."
    )
    parser.add_argument(
        "--local-dir",
        type=str,
        default=None,
        help=f"Target directory (default: {get_default_local_dir()})",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Re-download files even if they exist (force_download=True)",
    )
    parser.add_argument(
        "--verify-only",
        action="store_true",
        help="Only verify already-downloaded files; do not download.",
    )
    args = parser.parse_args()

    local_dir = args.local_dir or get_default_local_dir()
    local_dir = os.path.abspath(local_dir)

    # Use HF_TOKEN if set (for gated/private models); otherwise None (public, no auth)
    token = os.environ.get("HF_TOKEN") or None

    try:
        from huggingface_hub import snapshot_download
    except ImportError as e:
        print("ERROR: huggingface_hub is not installed.", file=sys.stderr)
        print("  pip install 'huggingface_hub>=0.20.0'", file=sys.stderr)
        return 1

    os.makedirs(local_dir, exist_ok=True)

    if args.verify_only:
        ok, missing_required, missing_optional = verify_download(local_dir)
        if missing_required:
            print("FAIL: missing required files:", missing_required, file=sys.stderr)
            return 1
        print("OK: all required model files are present.")
        if missing_optional:
            print("  (Optional files not found: " + ", ".join(missing_optional) + ")")
        return 0

    print(f"Downloading Qwen2-VL-2B-Instruct to: {local_dir}")
    print("(Re-run this script to resume if interrupted.)")
    print()

    try:
        snapshot_download(
            repo_id="Qwen/Qwen2-VL-2B-Instruct",
            revision="main",
            local_dir=local_dir,
            force_download=args.force,
            token=token,
            max_workers=4,
        )
    except Exception as e:
        if "401" in str(e) or "unauthorized" in str(e).lower() or "authentication" in str(e).lower():
            print("AUTHENTICATION may be required.", file=sys.stderr)
            print("  - Set HF_TOKEN: export HF_TOKEN=your_huggingface_token", file=sys.stderr)
            print("  - Or run: huggingface-cli login  (if installed)", file=sys.stderr)
            print("  - Get a token: https://huggingface.co/settings/tokens", file=sys.stderr)
        raise

    ok, missing_required, missing_optional = verify_download(local_dir)

    if missing_required:
        print("VERIFICATION FAILED: missing required files:", missing_required, file=sys.stderr)
        return 1

    print("Verification: all required model files are present.")
    if missing_optional:
        print("  (Optional files not found: " + ", ".join(missing_optional) + ")")

    print()
    print("SUCCESS: Qwen2-VL-2B-Instruct is ready at:")
    print(f"  {local_dir}")
    print()
    print("Load offline, e.g.:")
    print('  from transformers import Qwen2VLForConditionalGeneration, AutoProcessor')
    print(f'  model = Qwen2VLForConditionalGeneration.from_pretrained("{local_dir}", local_files_only=True)')
    print(f'  processor = AutoProcessor.from_pretrained("{local_dir}", local_files_only=True)')
    return 0


if __name__ == "__main__":
    sys.exit(main())
