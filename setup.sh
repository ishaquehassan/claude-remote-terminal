#!/bin/bash
# Remote Terminal — One-time setup script
# Works on: macOS, Linux (Debian/Ubuntu/Arch), Windows (WSL)
set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
err()  { echo -e "${RED}✗${NC} $1"; exit 1; }
info() { echo -e "${CYAN}→${NC} $1"; }

echo ""
echo "  Remote Terminal Setup"
echo "  ====================="
echo ""

# ── Detect OS ──────────────────────────────────────────────────────────────────
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
    OS="linux"
    # Detect distro
    if command -v apt-get &>/dev/null; then PKG="apt";
    elif command -v pacman  &>/dev/null; then PKG="pacman";
    elif command -v dnf     &>/dev/null; then PKG="dnf";
    else PKG="unknown"; fi
else
    err "Windows detected. Please use WSL (Windows Subsystem for Linux) and re-run this script inside WSL."
fi
ok "OS: $OS"

# ── Python 3 ───────────────────────────────────────────────────────────────────
if ! command -v python3 &>/dev/null; then
    info "Installing Python 3..."
    if   [ "$OS" = "mac" ];              then brew install python3
    elif [ "$PKG" = "apt" ];             then sudo apt-get install -y python3 python3-pip
    elif [ "$PKG" = "pacman" ];          then sudo pacman -S --noconfirm python python-pip
    elif [ "$PKG" = "dnf" ];             then sudo dnf install -y python3 python3-pip
    else err "Install Python 3 manually then re-run."; fi
fi
PYTHON=$(command -v python3)
ok "Python: $($PYTHON --version)"

# ── pip / websockets ───────────────────────────────────────────────────────────
info "Installing Python dependencies..."
$PYTHON -m pip install --quiet --upgrade websockets
ok "websockets installed"

# ── tmux ───────────────────────────────────────────────────────────────────────
if ! command -v tmux &>/dev/null; then
    info "Installing tmux..."
    if   [ "$OS" = "mac" ];     then brew install tmux
    elif [ "$PKG" = "apt" ];    then sudo apt-get install -y tmux
    elif [ "$PKG" = "pacman" ]; then sudo pacman -S --noconfirm tmux
    elif [ "$PKG" = "dnf" ];    then sudo dnf install -y tmux
    else warn "Could not install tmux automatically. Install it manually for shell sessions."; fi
fi
if command -v tmux &>/dev/null; then ok "tmux: $(tmux -V)"; else warn "tmux not found — shell sessions won't work"; fi

# ── Claude Code (optional) ─────────────────────────────────────────────────────
if command -v claude &>/dev/null; then
    ok "Claude Code: found"
    # Install /continue-remote slash command
    CLAUDE_DIR="$HOME/.claude"
    mkdir -p "$CLAUDE_DIR/commands" "$CLAUDE_DIR/scripts"
    cp "$REPO_DIR/commands/continue-remote.md" "$CLAUDE_DIR/commands/"
    cp "$REPO_DIR/scripts/continue_remote.py"  "$CLAUDE_DIR/scripts/"
    ok "/continue-remote command installed"
else
    warn "Claude Code not found — /continue-remote won't work (everything else will)"
fi

# ── Get local IP ───────────────────────────────────────────────────────────────
if [ "$OS" = "mac" ]; then
    IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "unknown")
else
    IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")
fi

# ── Make start.sh executable ───────────────────────────────────────────────────
chmod +x "$REPO_DIR/start.sh" 2>/dev/null || true

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo -e "  ${GREEN}Setup complete!${NC}"
echo "  ──────────────────────────────"
echo -e "  IP Address : ${CYAN}$IP${NC}"
echo -e "  Port       : ${CYAN}8765${NC}"
echo -e "  Token      : ${CYAN}xrlabs-remote-terminal-2024${NC}"
echo ""
echo "  Start server:"
echo "    ./start.sh"
echo "  Or:"
echo "    python3 server/server.py"
echo ""
echo "  In the phone app, connect to:  ws://$IP:8765"
echo ""
