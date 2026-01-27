# Downloading Qwen2-VL-2B-Instruct

## Quick start

Use a Python that has `huggingface_hub` (e.g. `/usr/local/bin/python3` if that’s where it’s installed):

```bash
cd /Users/aadijain/Desktop/tinder-fashion/design2garmentcode/design2garmentcode-impl
/usr/local/bin/python3 lmm_utils/Qwen/download_qwen2vl_2b_instruct.py
```

If your project’s `python3` already has `huggingface_hub`:

```bash
python3 lmm_utils/Qwen/download_qwen2vl_2b_instruct.py
```

Output directory:  
`lmm_utils/Qwen/Qwen2-VL-2B-Instruct`

## Resuming

If the download stops, run the same command again. Already-downloaded files are skipped; only missing or incomplete files are fetched.

## Verify only

To only check that required files are present (no download):

```bash
/usr/local/bin/python3 lmm_utils/Qwen/download_qwen2vl_2b_instruct.py --verify-only
```

## Authentication (gated/private models)

Qwen2-VL-2B-Instruct is public; no token is needed by default.

If you use a gated model or need to be logged in:

```bash
export HF_TOKEN=your_huggingface_token
/usr/local/bin/python3 lmm_utils/Qwen/download_qwen2vl_2b_instruct.py
```

Create a token: https://huggingface.co/settings/tokens

## Required files (for verification)

- `config.json`
- `preprocessor_config.json`
- `tokenizer_config.json`
- `tokenizer.json`
- `vocab.json`
- `merges.txt`
- `model.safetensors.index.json`
- `model-00001-of-00002.safetensors`
- `model-00002-of-00002.safetensors`

## Load offline

```python
from transformers import Qwen2VLForConditionalGeneration, AutoProcessor

model = Qwen2VLForConditionalGeneration.from_pretrained(
    "lmm_utils/Qwen/Qwen2-VL-2B-Instruct",
    local_files_only=True
)
processor = AutoProcessor.from_pretrained(
    "lmm_utils/Qwen/Qwen2-VL-2B-Instruct",
    local_files_only=True
)
```

(Use an absolute path if needed.)
