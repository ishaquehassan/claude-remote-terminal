#!/bin/bash
# Remote Terminal — Start server
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

# Get local IP
if [[ "$OSTYPE" == "darwin"* ]]; then
    IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "unknown")
else
    IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")
fi

echo "Remote Terminal Server"
echo "  IP:    $IP"
echo "  Port:  8765"
echo "  Token: xrlabs-remote-terminal-2024"
echo ""

python3 "$REPO_DIR/server/server.py"
