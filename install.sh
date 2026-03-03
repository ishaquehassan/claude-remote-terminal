#!/bin/bash
# Remote Terminal — Universal Installer
# curl -fsSL https://raw.githubusercontent.com/ishaquehassan/remote-terminal/main/install.sh | bash

set -e

REPO="ishaquehassan/remote-terminal"
INSTALL_DIR="$HOME/.remote-terminal"
RAW="https://raw.githubusercontent.com/$REPO/main"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}!${NC} $1"; }
err()  { echo -e "  ${RED}✗ Error:${NC} $1"; exit 1; }
info() { echo -e "  ${CYAN}→${NC} $1"; }
step() { echo -e "\n${BOLD}$1${NC}"; }

clear
echo -e "${CYAN}"
cat << 'EOF'
  ██████╗ ███████╗███╗   ███╗ ██████╗ ████████╗███████╗
  ██╔══██╗██╔════╝████╗ ████║██╔═══██╗╚══██╔══╝██╔════╝
  ██████╔╝█████╗  ██╔████╔██║██║   ██║   ██║   █████╗
  ██╔══██╗██╔══╝  ██║╚██╔╝██║██║   ██║   ██║   ██╔══╝
  ██║  ██║███████╗██║ ╚═╝ ██║╚██████╔╝   ██║   ███████╗
  ╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝ ╚═════╝    ╚═╝   ╚══════╝
  ████████╗███████╗██████╗ ███╗   ███╗██╗███╗   ██╗ █████╗ ██╗
  ╚══██╔══╝██╔════╝██╔══██╗████╗ ████║██║████╗  ██║██╔══██╗██║
     ██║   █████╗  ██████╔╝██╔████╔██║██║██╔██╗ ██║███████║██║
     ██║   ██╔══╝  ██╔══██╗██║╚██╔╝██║██║██║╚██╗██║██╔══██║██║
     ██║   ███████╗██║  ██║██║ ╚═╝ ██║██║██║ ╚████║██║  ██║███████╗
     ╚═╝   ╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝
EOF
echo -e "${NC}"
echo -e "  ${BOLD}Control your terminal from your Android phone${NC}"
echo -e "  github.com/$REPO"
echo ""

# ── Detect OS ──────────────────────────────────────────────────────────────────
step "[ 1 / 5 ]  Detecting system..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="mac"
elif [[ "$OSTYPE" == "linux-gnu"* ]] || [[ "$OSTYPE" == "linux"* ]]; then
    OS="linux"
    if   command -v apt-get &>/dev/null; then PKG="apt"
    elif command -v pacman  &>/dev/null; then PKG="pacman"
    elif command -v dnf     &>/dev/null; then PKG="dnf"
    else PKG="unknown"; fi
else
    err "Unsupported OS. On Windows, please use WSL then re-run this installer."
fi
ok "System: $OS${PKG:+ ($PKG)}"

# Mac: ensure Homebrew
if [ "$OS" = "mac" ] && ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# ── Python 3 ───────────────────────────────────────────────────────────────────
step "[ 2 / 5 ]  Checking dependencies..."

if ! command -v python3 &>/dev/null; then
    info "Installing Python 3..."
    if   [ "$OS" = "mac" ];          then brew install python3
    elif [ "$PKG" = "apt" ];         then sudo apt-get install -y python3 python3-pip
    elif [ "$PKG" = "pacman" ];      then sudo pacman -S --noconfirm python python-pip
    elif [ "$PKG" = "dnf" ];         then sudo dnf install -y python3 python3-pip
    else err "Install Python 3 manually then re-run."; fi
fi
ok "Python: $(python3 --version)"

# websockets
python3 -m pip install --quiet --upgrade websockets
ok "websockets: installed"

# tmux
if ! command -v tmux &>/dev/null; then
    info "Installing tmux..."
    if   [ "$OS" = "mac" ];     then brew install tmux
    elif [ "$PKG" = "apt" ];    then sudo apt-get install -y tmux
    elif [ "$PKG" = "pacman" ]; then sudo pacman -S --noconfirm tmux
    elif [ "$PKG" = "dnf" ];    then sudo dnf install -y tmux
    else warn "tmux not found — install manually for shell sessions"; fi
fi
command -v tmux &>/dev/null && ok "tmux: $(tmux -V)" || warn "tmux: not installed"

# ── Download server ─────────────────────────────────────────────────────────────
step "[ 3 / 5 ]  Installing Remote Terminal server..."

mkdir -p "$INSTALL_DIR"
curl -fsSL "$RAW/server/server.py"              -o "$INSTALL_DIR/server.py"
curl -fsSL "$RAW/scripts/continue_remote.py"    -o "$INSTALL_DIR/continue_remote.py"
curl -fsSL "$RAW/commands/continue-remote.md"   -o "$INSTALL_DIR/continue-remote.md"
ok "Server downloaded to $INSTALL_DIR"

# ── Claude Code slash command ───────────────────────────────────────────────────
step "[ 4 / 5 ]  Setting up Claude Code integration..."

if command -v claude &>/dev/null; then
    mkdir -p "$HOME/.claude/commands" "$HOME/.claude/scripts"
    cp "$INSTALL_DIR/continue_remote.py"  "$HOME/.claude/scripts/"
    cp "$INSTALL_DIR/continue-remote.md"  "$HOME/.claude/commands/"
    ok "/continue-remote command installed for Claude Code"
else
    warn "Claude Code not found — skipping /continue-remote setup"
    warn "Install Claude Code later, then run:"
    warn "  cp $INSTALL_DIR/continue_remote.py ~/.claude/scripts/"
    warn "  cp $INSTALL_DIR/continue-remote.md ~/.claude/commands/"
fi

# ── Create remote-terminal command ─────────────────────────────────────────────
step "[ 5 / 5 ]  Creating launcher..."

LAUNCHER="$INSTALL_DIR/remote-terminal"
cat > "$LAUNCHER" << SCRIPT
#!/bin/bash
# Get IP
if [[ "\$OSTYPE" == "darwin"* ]]; then
    IP=\$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "unknown")
else
    IP=\$(hostname -I 2>/dev/null | awk '{print \$1}' || echo "unknown")
fi
echo "Remote Terminal Server"
echo "  IP    : \$IP"
echo "  Port  : 8765"
echo "  Token : xrlabs-remote-terminal-2024"
echo ""
python3 "$INSTALL_DIR/server.py"
SCRIPT
chmod +x "$LAUNCHER"

# Symlink to PATH
for dir in /usr/local/bin "$HOME/.local/bin" "$HOME/bin"; do
    if [[ ":$PATH:" == *":$dir:"* ]] || [ "$dir" = "/usr/local/bin" ]; then
        if [ -w "$dir" ] 2>/dev/null || sudo test -d "$dir" 2>/dev/null; then
            sudo ln -sf "$LAUNCHER" "$dir/remote-terminal" 2>/dev/null \
                || ln -sf "$LAUNCHER" "$dir/remote-terminal" 2>/dev/null || true
            break
        fi
    fi
done
ok "Launcher created: remote-terminal"

# ── Get IP for display ──────────────────────────────────────────────────────────
if [ "$OS" = "mac" ]; then
    IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || echo "unknown")
else
    IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "unknown")
fi

# ── Done ───────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║          Installation Complete!          ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "  ${BOLD}Server Info${NC}"
echo -e "  ─────────────────────────────────────────"
echo -e "  IP Address : ${CYAN}$IP${NC}"
echo -e "  Port       : ${CYAN}8765${NC}"
echo -e "  Token      : ${CYAN}xrlabs-remote-terminal-2024${NC}"
echo ""
echo -e "  ${BOLD}Next Steps${NC}"
echo -e "  ─────────────────────────────────────────"
echo -e "  1. Install the APK on your Android phone:"
echo -e "     ${CYAN}https://github.com/$REPO/releases/latest${NC}"
echo ""
echo -e "  2. Start the server:"
echo -e "     ${CYAN}remote-terminal${NC}"
echo ""
echo -e "  3. In the app, connect to:"
echo -e "     ${CYAN}ws://$IP:8765${NC}"
echo ""
echo -e "  4. In Claude Code, use ${CYAN}/continue-remote${NC} to send"
echo -e "     your session to your phone instantly."
echo ""
