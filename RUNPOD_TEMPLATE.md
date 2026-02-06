# RunPod Template Configuration

## Create Template at:
https://runpod.io/console/user/templates

---

## Template Settings

| Field | Value |
|-------|-------|
| **Template Name** | Design2GarmentCode |
| **Container Image** | `ghcr.io/aadijain725/design2garmentcode-impl:runpod-end2end-pipeline` |
| **Docker Command** | *(leave empty — uses entrypoint)* |
| **Container Disk** | 20 GB |
| **Volume Disk** | 20 GB |
| **Volume Mount Path** | `/app/lmm_utils/Qwen` |

---

## Exposed Ports

| Port | Type |
|------|------|
| 8080 | HTTP |

---

## Environment Variables

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `OPENAI_API_KEY` | *(user fills in)* | Required for GPT-4o |
| `OPENAI_MODEL` | `gpt-4o` | Model to use |

---

## Minimum Requirements

- **GPU VRAM:** 8 GB minimum (RTX 3080+ or A40/A100)
- **System RAM:** 16 GB recommended
- **Storage:** ~15 GB for models (downloaded on first run)

---

## How It Works

1. User creates a pod from this template
2. Pod starts, runs `docker-entrypoint.sh`
3. Entrypoint checks for models, downloads if missing (~4 GB Qwen2-VL + ~4.5 GB LoRA weights)
4. GUI starts on port 8080
5. User accesses via RunPod proxy URL: `https://<pod-id>-8080.proxy.runpod.net`

---

## Alternative: Cloudflare Tunnel

For public URL access without RunPod's proxy:

```bash
# SSH into pod, then:
./run_with_tunnel.sh
```

This starts the GUI + Cloudflare tunnel, prints a public `https://xxx.trycloudflare.com` URL.

---

## First Run Time

- **Cold start (no models cached):** ~5-10 min (downloading 8.5 GB of models)
- **Warm start (models in volume):** ~30 sec

---

## Testing the Template

After creating, launch a test pod and verify:
1. Pod starts without errors
2. Models download successfully
3. GUI accessible at `https://<pod-id>-8080.proxy.runpod.net`
4. Can generate a pattern from text input
