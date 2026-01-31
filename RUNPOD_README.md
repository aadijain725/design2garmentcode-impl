# Design2GarmentCode - RunPod Deployment Guide

This guide explains how to deploy Design2GarmentCode on RunPod or any cloud GPU instance.

## Requirements

- **GPU**: NVIDIA GPU with at least 8GB VRAM (RTX 3080+ recommended)
- **Storage**: ~15GB for models and environment
- **OpenAI API Key**: Required for GPT-4o integration

## Quick Start (Recommended)

### Option 1: Direct Setup (No Docker)

```bash
# 1. Clone the repository
git clone https://github.com/aadijain725/design2garmentcode-impl.git
cd design2garmentcode-impl
git checkout runpod-configured

# 2. Run setup (installs conda, environment, downloads models)
chmod +x setup_runpod.sh
./setup_runpod.sh

# 3. Configure your OpenAI API key
cp system.json.template system.json
# Edit system.json and add your API key to "api_keys" field

# 4. Start with Cloudflare tunnel (public URL)
./run_with_tunnel.sh
```

### Option 2: Using Docker

```bash
# 1. Clone and enter directory
git clone https://github.com/aadijain725/design2garmentcode-impl.git
cd design2garmentcode-impl
git checkout runpod-configured

# 2. Set your API key
export OPENAI_API_KEY="sk-your-key-here"

# 3. Build and run with docker-compose
docker-compose up --build

# The GUI will be available at http://localhost:8080
# Cloudflare tunnel URL will be shown in the tunnel container logs
```

## Configuration

### system.json

Edit `system.json` to configure:

```json
{
  "model": {
    "vl_model": "gpt-4o",      // Vision-language model
    "text_model": "gpt-4o"     // Text model
  },
  "api_keys": "sk-your-key",   // OpenAI API key
  "base_urls": "https://api.openai.com/v1"
}
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `OPENAI_API_KEY` | Your OpenAI API key | Required |
| `OPENAI_MODEL` | Model to use | `gpt-4o` |

## Scripts Reference

| Script | Description |
|--------|-------------|
| `setup_runpod.sh` | Full setup: conda, environment, models |
| `setup_runpod.sh --skip-models` | Setup without downloading models |
| `run_with_tunnel.sh` | Start GUI + Cloudflare tunnel |
| `start_gui.sh` | Start GUI only (no tunnel) |
| `monitor_logs.sh` | Live log viewer with colors |

## Accessing the GUI

### Via Cloudflare Tunnel (Public)
When using `run_with_tunnel.sh`, a public URL like this will be displayed:
```
https://random-words.trycloudflare.com
```
This URL is accessible from anywhere.

### Via RunPod Port Forwarding
If your RunPod instance has HTTP port 8080 exposed, use:
```
https://<pod-id>-8080.proxy.runpod.net
```

### Local Only
```
http://localhost:8080
```

## Using the GUI

1. Open the URL in your browser
2. Navigate to the **"PARSE DESIGN"** tab
3. Enter your design input:
   - Text description (e.g., "A flowy summer dress with short sleeves")
   - Upload a photograph
   - Upload a sketch
4. Click submit and wait for the pattern to generate
5. To modify: type `modify: <your instruction>` in the chatbox

## Troubleshooting

### "429 Too Many Requests" errors
This is OpenAI rate limiting. The system retries automatically. Consider:
- Using a paid OpenAI account with higher limits
- Waiting a few seconds between requests

### Connection Timeout errors
Normal for Cloudflare tunnels - handled automatically.

### Models not loading
Ensure you have enough disk space (~15GB) and run:
```bash
./setup_runpod.sh
```

### GPU not detected
Check with `nvidia-smi`. Ensure NVIDIA drivers are installed.

### Conda environment issues
```bash
# Remove and recreate
conda env remove -n d2g
./setup_runpod.sh
```

## File Structure

```
design2garmentcode-impl/
├── Dockerfile              # Docker image definition
├── docker-compose.yml      # Container orchestration
├── docker-entrypoint.sh    # Container startup script
├── environment_runpod.yml  # Conda environment
├── setup_runpod.sh         # Setup script
├── run_with_tunnel.sh      # Start with Cloudflare
├── start_gui.sh            # Start GUI only
├── monitor_logs.sh         # Log viewer
├── system.json.template    # Config template
├── gui.py                  # Main GUI application
└── lmm_utils/
    └── Qwen/
        ├── Qwen2-VL-2B-Instruct/  # Base model (~4GB)
        └── qwen2vl_lora_mlp/
            └── model.pth          # Fine-tuned weights (~4.5GB)
```

## Support

For issues, please open a GitHub issue or check the main README.
