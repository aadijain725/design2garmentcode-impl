#!/bin/bash
# Design2GarmentCode - Log Monitor
# Monitor GUI and Cloudflare logs with color-coded output

LOG_DIR="/tmp/d2g_logs"
GUI_LOG="$LOG_DIR/gui.log"
CF_LOG="$LOG_DIR/cloudflared.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Design2GarmentCode Log Monitor ===${NC}"
echo -e "GUI Log: $GUI_LOG"
echo -e "Cloudflare Log: $CF_LOG"
echo ""

# Check if logs exist
if [ ! -f "$GUI_LOG" ]; then
    echo -e "${RED}GUI log not found. Is the server running?${NC}"
    echo "Start with: ./run_with_tunnel.sh"
    exit 1
fi

# Show recent status
echo -e "${YELLOW}=== Recent Status ===${NC}"
echo -e "${BLUE}Processes:${NC}"
ps aux | grep -E "gui.py|cloudflared" | grep -v grep || echo "No processes running"
echo ""

echo -e "${BLUE}GPU Memory:${NC}"
nvidia-smi --query-gpu=memory.used,memory.total --format=csv,noheader 2>/dev/null || echo "GPU not available"
echo ""

echo -e "${BLUE}Cloudflare URL:${NC}"
grep -oE "https://[a-zA-Z0-9-]+\.trycloudflare\.com" "$CF_LOG" 2>/dev/null | tail -1 || echo "Not available"
echo ""

echo -e "${YELLOW}=== Live Logs (Ctrl+C to exit) ===${NC}"
tail -f "$GUI_LOG" 2>/dev/null | while IFS= read -r line; do
    if echo "$line" | grep -qE "ERROR|Exception|Traceback"; then
        echo -e "${RED}$line${NC}"
    elif echo "$line" | grep -qE "WARNING|429"; then
        echo -e "${YELLOW}$line${NC}"
    elif echo "$line" | grep -qE "INFO|200 OK|ready"; then
        echo -e "${GREEN}$line${NC}"
    else
        echo "$line"
    fi
done
