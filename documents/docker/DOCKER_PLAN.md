# Docker Plan for Design2GarmentCode

## Quick Docker Concepts (For Beginners)

| Term | What It Means |
|------|---------------|
| **Container** | A lightweight "box" that packages your app + all its dependencies so it runs the same everywhere |
| **Image** | A blueprint/template for creating containers (like a class vs instance) |
| **Dockerfile** | A recipe file that tells Docker how to build your image |
| **docker-compose** | A tool to run multiple containers together easily |
| **Volume** | A way to share files between your computer and the container |
| **RunPod** | GPU cloud platform optimized for ML workloads - our deployment target |

---

## Target Platform: RunPod

RunPod is great for ML workloads because:
- Pay-per-hour GPU access (cheaper than AWS for ML)
- Pre-configured CUDA environments
- Easy Docker deployment via "Pods" or "Serverless"
- Your existing GPU credits can be used

---

## What We're Containerizing

Your project has 4 main pieces:

```
┌─────────────────────────────────────────────────────────────┐
│                     Design2GarmentCode                       │
├─────────────────────────────────────────────────────────────┤
│  1. GUI (NiceGUI web server on port 8080)                   │
│  2. AI Model (Qwen2-VL for image understanding) ~5GB        │
│  3. Pattern Generator (Python code → SVG patterns)          │
│  4. 3D Simulator (physics-based draping)                    │
└─────────────────────────────────────────────────────────────┘
```

---

## Recommended Approach: Single Container First

**Why?** Simpler to build, debug, and deploy. You can split into microservices later.

### Files We'll Create

```
design2garmentcode-impl/
├── docker/                   # Lives at project root, pushed to GitHub
│   ├── Dockerfile.gpu        # For GPU machines (RunPod/production)
│   ├── Dockerfile.cpu        # For CPU-only (development/testing)
│   ├── Dockerfile.api        # Lightweight API-only mode (no local model)
│   ├── docker-compose.yml    # Easy one-command startup
│   ├── .dockerignore         # Files to exclude from container
│   ├── entrypoint.sh         # Startup script inside container
│   └── runpod.yaml           # RunPod-specific deployment config
```

**GitHub**: Yes! The entire `docker/` directory gets pushed to GitHub. Model files are in `.gitignore` (too large), but all Docker configs are version controlled.

---

## Container Options

### Option A: GPU Container (for production/cloud)
- **Base**: `nvidia/cuda:12.1.0-runtime-ubuntu22.04`
- **Size**: ~4GB (without models)
- **Use when**: Running on RunPod or any cloud with GPU

### Option B: CPU Container (for development)
- **Base**: `python:3.9-slim`
- **Size**: ~2GB (without models)
- **Use when**: Testing locally without GPU, cheaper cloud instances

### Option C: API Container (lightest)
- **Base**: `python:3.9-slim`
- **Size**: ~500MB
- **Use when**: Using external API for model inference

---

## Handling Large Model Files (~8GB)

**Problem**: Model files are huge. We don't want to rebuild them into the image every time code changes.

**Solution**: Support BOTH API-based and local model deployment (switchable via config)

### Option A: API-Based (Lighter, Simpler)

Use a hosted Qwen2-VL API instead of running locally:

| Provider | Qwen2-VL Support | Pricing |
|----------|------------------|---------|
| Together AI | Yes | ~$0.20/1M tokens |
| Replicate | Yes | ~$0.0005/second |
| Hugging Face Inference | Yes | Free tier available |

**Benefits**:
- Container size: ~500MB (no model files!)
- No GPU needed for the container
- Pay only for what you use
- Simpler deployment

**Config**: Set `MODEL_MODE=api` + `QWEN_API_URL` environment variables

### Option B: Local Model (Full Control)

Run Qwen2-VL inside the container with GPU:

```
Your Computer / RunPod Volume     Docker Container
─────────────────────────────────────────────────────
lmm_utils/Qwen/
├── Qwen2-VL-2B-Instruct/  ────► /app/lmm_utils/Qwen/Qwen2-VL-2B-Instruct/
│   ├── model-00001.safetensors
│   └── model-00002.safetensors
└── qwen2vl_lora_mlp/      ────► /app/lmm_utils/Qwen/qwen2vl_lora_mlp/
    └── model.pth
```

**Benefits**:
- No per-request costs after setup
- Full control over the model
- Works offline
- Can use your fine-tuned LoRA weights

**Config**: Set `MODEL_MODE=local` environment variable

---

## Files to Modify (Minor Code Updates)

| File | Change Needed |
|------|---------------|
| `lmm_utils/fintuned_qwen2vl_model.py:25` | Make model path configurable via env var |
| `lmm_utils/predict_garmentcode_picture.py` | Support `MODEL_PATH` env var |
| `system.json` | Will be overridden by env vars in container |

---

## Cloud Cost Estimates (RunPod)

| Use Case | GPU | Hourly Cost | 24/7 Monthly |
|----------|-----|-------------|--------------|
| Development | RTX 3090 | ~$0.44/hr | ~$320 |
| Production | RTX 4090 | ~$0.69/hr | ~$500 |
| High-end | A100 80GB | ~$1.99/hr | ~$1,430 |
| Network Volume | 100GB | - | ~$10 |

**Cost Saving Tips**:
- Use "Community Cloud" (cheaper than Secure Cloud)
- Stop pods when not in use
- Use API mode to avoid GPU costs entirely
- RunPod Serverless: pay only when processing requests

---

## Summary

| What | Details |
|------|---------|
| **Approach** | Single monolithic container (simple to start) |
| **Images** | 3 Dockerfiles (GPU, CPU, API-only variants) |
| **Models** | Switchable: API-based OR mounted volumes |
| **Cloud Target** | RunPod (Pods or Serverless) |
| **Docker Location** | `design2garmentcode-impl/docker/` (pushed to GitHub) |
| **Files to Create** | 6 new files in `docker/` directory |
| **Files to Modify** | 2-3 small path changes + model mode switch |

## What Gets Pushed to GitHub

```
docker/
├── Dockerfile.gpu        ✅ Pushed
├── Dockerfile.cpu        ✅ Pushed
├── Dockerfile.api        ✅ Pushed
├── docker-compose.yml    ✅ Pushed
├── .dockerignore         ✅ Pushed
├── entrypoint.sh         ✅ Pushed
└── runpod.yaml           ✅ Pushed

lmm_utils/Qwen/
├── Qwen2-VL-2B-Instruct/ ❌ In .gitignore (too large)
└── qwen2vl_lora_mlp/     ❌ In .gitignore (too large)
```
