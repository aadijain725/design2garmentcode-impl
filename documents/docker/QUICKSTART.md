# Docker Quick Start Guide

This guide shows you how to run Design2GarmentCode using Docker.

---

## Prerequisites

1. **Docker Desktop** installed ([Download here](https://www.docker.com/products/docker-desktop/))
2. **Model files** downloaded (run `./setup_conda_env.sh` first if you haven't)
3. **OpenAI API key** (optional, for text-based design features)

---

## Option 1: Local Development (CPU)

Best for: Testing, development, machines without GPU

```bash
# Navigate to the docker directory
cd docker

# Build and run with CPU profile
docker compose --profile cpu up --build

# Open in browser
# http://localhost:8080
```

To stop: Press `Ctrl+C` or run `docker compose down`

---

## Option 2: Local with GPU

Best for: Fast inference, machines with NVIDIA GPU

**Requirements**: [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) installed

```bash
# Navigate to the docker directory
cd docker

# Build and run with GPU profile
docker compose --profile gpu up --build

# Open in browser
# http://localhost:8080
```

---

## Option 3: API Mode (Lightest)

Best for: No GPU, don't want to download large models

```bash
# Run with API mode - uses external model API
docker compose --profile api up --build

# Set your API provider credentials
export QWEN_API_URL="https://api.together.xyz/v1"
export QWEN_API_KEY="your-api-key"
```

---

## Deploy to RunPod

### Step 1: Build and Push Image

```bash
# Build the GPU image
docker build -f docker/Dockerfile.gpu -t yourusername/d2g:gpu .

# Login to Docker Hub
docker login

# Push to Docker Hub
docker push yourusername/d2g:gpu
```

### Step 2: Create RunPod Pod

1. Go to [RunPod.io](https://runpod.io) and login
2. Click **"+ Deploy"** → **"GPU Pod"**
3. Select a GPU (RTX 3090 recommended for cost/performance)
4. Under **"Container Image"**, enter: `yourusername/d2g:gpu`
5. Under **"Expose HTTP Ports"**, add: `8080`
6. Click **"Deploy"**

### Step 3: Setup Model Storage (First Time Only)

**Option A: Network Volume (Recommended)**
1. Create a Network Volume in RunPod (100GB)
2. Upload models to the volume
3. Mount volume at `/app/lmm_utils/Qwen` when creating pod

**Option B: Download on Startup**
Models will download automatically from Hugging Face on first run (~5-10 min)

### Step 4: Access Your App

Once the pod is running:
1. Click on your pod
2. Click **"Connect"** → **"HTTP Service [Port 8080]"**
3. Your app is now live!

---

## RunPod Serverless (Auto-scaling)

For production with variable traffic:

```bash
# Build serverless-compatible image
docker build -f docker/Dockerfile.serverless -t yourusername/d2g:serverless .
docker push yourusername/d2g:serverless

# Deploy on RunPod Serverless
# 1. Go to Serverless → Create Endpoint
# 2. Use your image: yourusername/d2g:serverless
# 3. Configure scaling settings
```

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MODEL_MODE` | `local` or `api` | `local` |
| `QWEN_API_URL` | API endpoint for Qwen2-VL | - |
| `QWEN_API_KEY` | API key for Qwen2-VL | - |
| `OPENAI_API_KEY` | OpenAI API key for text features | - |
| `HOST` | Server host | `0.0.0.0` |
| `PORT` | Server port | `8080` |

---

## Switching Between Model Modes

### API Mode (lightweight container, no GPU needed)
```bash
docker run -p 8080:8080 \
  -e MODEL_MODE=api \
  -e QWEN_API_URL=https://api.together.xyz/v1 \
  -e QWEN_API_KEY=your-key \
  d2g:cpu
```

### Local Mode (requires GPU and model files)
```bash
docker run -p 8080:8080 --gpus all \
  -e MODEL_MODE=local \
  -v $(pwd)/lmm_utils/Qwen:/app/lmm_utils/Qwen:ro \
  d2g:gpu
```

---

## Troubleshooting

### "Model files not found"
```bash
# Make sure models are mounted correctly
docker run -v /path/to/lmm_utils/Qwen:/app/lmm_utils/Qwen:ro ...
```

### "CUDA out of memory"
- Use a GPU with more VRAM (16GB+ recommended)
- Or switch to API mode: `-e MODEL_MODE=api`

### "Connection refused on port 8080"
- Ensure the container uses `--host 0.0.0.0` (not 127.0.0.1)
- Check if port 8080 is already in use: `lsof -i :8080`

### Slow first request
- Model loading takes 30-60 seconds on first request
- This is normal - subsequent requests will be fast

---

## Quick Commands Reference

```bash
# Build CPU image
docker build -f docker/Dockerfile.cpu -t d2g:cpu .

# Build GPU image
docker build -f docker/Dockerfile.gpu -t d2g:gpu .

# Run CPU container
docker run -p 8080:8080 -v $(pwd)/lmm_utils/Qwen:/app/lmm_utils/Qwen:ro d2g:cpu

# Run GPU container
docker run -p 8080:8080 --gpus all -v $(pwd)/lmm_utils/Qwen:/app/lmm_utils/Qwen:ro d2g:gpu

# View logs
docker logs -f <container_id>

# Stop all containers
docker compose down

# Clean up unused images
docker image prune
```
