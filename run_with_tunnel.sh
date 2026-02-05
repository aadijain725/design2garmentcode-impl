#!/bin/bash
# Design2GarmentCode - Run with Cloudflare Tunnel
# This script starts the GUI and exposes it via Cloudflare tunnel

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

LOG_DIR="/tmp/d2g_logs"
GUI_LOG="$LOG_DIR/gui.log"
CF_LOG="$LOG_DIR/cloudflared.log"
DETAILED_LOG="$LOG_DIR/gui_detailed.log"

# Create log directory
mkdir -p "$LOG_DIR"

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Design2GarmentCode - RunPod Launcher${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""

# Function to cleanup on exit
cleanup() {
    echo -e "\n${YELLOW}Shutting down...${NC}"
    pkill -f "gui.py" 2>/dev/null || true
    pkill -f "cloudflared" 2>/dev/null || true
    echo -e "${GREEN}Cleanup complete.${NC}"
}
trap cleanup EXIT

# Check for GPU
echo -e "${BLUE}[1/5] Checking GPU...${NC}"
if command -v nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
    GPU_MEM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader 2>/dev/null | head -1)
    echo -e "${GREEN}  ✓ GPU: $GPU_NAME ($GPU_MEM)${NC}"
else
    echo -e "${YELLOW}  ⚠ No GPU detected${NC}"
fi

# Check conda environment
echo -e "${BLUE}[2/5] Activating conda environment...${NC}"
if [ -f "/root/miniconda3/etc/profile.d/conda.sh" ]; then
    source /root/miniconda3/etc/profile.d/conda.sh
elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    source "$HOME/miniconda3/etc/profile.d/conda.sh"
else
    echo -e "${RED}  ✗ Conda not found. Run setup_runpod.sh first.${NC}"
    exit 1
fi
conda activate d2g
export TOKENIZERS_PARALLELISM=false  # Suppress HuggingFace tokenizers warning
echo -e "${GREEN}  ✓ Environment 'd2g' activated${NC}"

# Kill any existing processes
echo -e "${BLUE}[3/5] Cleaning up old processes...${NC}"
pkill -f "gui.py" 2>/dev/null || true
pkill -f "cloudflared" 2>/dev/null || true
sleep 2
echo -e "${GREEN}  ✓ Cleaned${NC}"

# Start GUI
echo -e "${BLUE}[4/5] Starting GUI server...${NC}"
python gui.py --host 0.0.0.0 --port 8080 > "$GUI_LOG" 2>&1 &
GUI_PID=$!
echo -e "  PID: $GUI_PID"

# Wait for GUI to be ready
echo -n "  Waiting for server"
for i in {1..60}; do
    if curl -s -o /dev/null -w "" http://localhost:8080 2>/dev/null; then
        echo ""
        echo -e "${GREEN}  ✓ GUI ready on port 8080${NC}"
        break
    fi
    echo -n "."
    sleep 2
done

# Check if GUI started successfully
if ! ps -p $GUI_PID > /dev/null 2>&1; then
    echo -e "${RED}  ✗ GUI failed to start. Check logs:${NC}"
    tail -20 "$GUI_LOG"
    exit 1
fi

# Start Cloudflare tunnel
echo -e "${BLUE}[5/5] Starting Cloudflare tunnel...${NC}"
cloudflared tunnel --url http://localhost:8080 > "$CF_LOG" 2>&1 &
CF_PID=$!
sleep 12  # Allow extra time for tunnel initialization

# Get tunnel URL (with retry)
TUNNEL_URL=""
for attempt in {1..3}; do
    TUNNEL_URL=$(grep -oE "https://[a-zA-Z0-9-]+\.trycloudflare\.com" "$CF_LOG" 2>/dev/null | tail -1)
    if [ -n "$TUNNEL_URL" ]; then
        break
    fi
    echo -e "  Waiting for tunnel URL (attempt $attempt/3)..."
    sleep 3
done

if [ -z "$TUNNEL_URL" ]; then
    echo -e "${RED}  ✗ Failed to get tunnel URL. Check logs:${NC}"
    cat "$CF_LOG"
    exit 1
fi

echo -e "${GREEN}  ✓ Tunnel active${NC}"
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  PUBLIC URL: ${TUNNEL_URL}${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${YELLOW}Logs:${NC}"
echo -e "  GUI:        $GUI_LOG"
echo -e "  Cloudflare: $CF_LOG"
echo -e "  Detailed:   $DETAILED_LOG"
echo ""
echo -e "${YELLOW}Commands:${NC}"
echo -e "  Monitor GUI:  tail -f $GUI_LOG"
echo -e "  Monitor CF:   tail -f $CF_LOG"
echo -e "  GPU status:   nvidia-smi"
echo ""
echo -e "${BLUE}Press Ctrl+C to stop all services${NC}"
echo ""

# Monitor logs
echo -e "${YELLOW}=== Live Log Monitor ===${NC}"
tail -f "$GUI_LOG" 2>/dev/null | while read line; do
    if echo "$line" | grep -q "ERROR"; then
        echo -e "${RED}$line${NC}"
    elif echo "$line" | grep -q "WARNING"; then
        echo -e "${YELLOW}$line${NC}"
    elif echo "$line" | grep -q "INFO"; then
        echo -e "${GREEN}$line${NC}"
    else
        echo "$line"
    fi
done
