#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
# Jinn Stack — Full Installation Script
# Installs: Jinn Gateway, Mem0, MCP Memory Service, MemViz
# Targets: macOS (arm64/x64) and Linux (x64)
# Idempotent: safe to re-run at any time
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# ── Paths (configurable via env) ──
JINN_HOME="${JINN_HOME:-$HOME/.jinn}"
JINN_CLI_DIR="${JINN_CLI_DIR:-$HOME/dev/jinn-cli}"
MEM0_HOME="${MEM0_HOME:-$HOME/.mem0}"
MEM0_VENV="${MEM0_HOME}/venv"
MEMVIZ_DIR="${MEMVIZ_DIR:-$HOME/.openclaw/workspace/memviz}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Colors ──
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Helpers ──
info()    { echo -e "${GREEN}[ok]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!!]${NC} $1"; }
err()     { echo -e "${RED}[err]${NC} $1"; }
fatal()   { err "$1"; exit 1; }
section() { echo -e "\n${BLUE}${BOLD}── $1 ──${NC}"; }
step()    { echo -e "  ${CYAN}->  ${NC}$1"; }

# ── Banner ──
echo -e "${BOLD}"
echo "  ╔═══════════════════════════════════════╗"
echo "  ║       Jinn Stack — Installer          ║"
echo "  ║  Gateway + Mem0 + MCP Memory + MemViz ║"
echo "  ╚═══════════════════════════════════════╝"
echo -e "${NC}"

# ═══════════════════════════════════════════════════════════════
# STEP 0 — Prerequisites (auto-detect & install)
# ═══════════════════════════════════════════════════════════════
section "Checking prerequisites"

# ── OS & package manager detection ──
OS="$(uname -s)"
ARCH="$(uname -m)"
PKG_MANAGER=""

detect_pkg_manager() {
  if [ "$OS" = "Darwin" ]; then
    if command -v brew &>/dev/null; then
      PKG_MANAGER="brew"
    else
      return 1
    fi
  elif [ "$OS" = "Linux" ]; then
    if command -v apt-get &>/dev/null; then
      PKG_MANAGER="apt"
    elif command -v dnf &>/dev/null; then
      PKG_MANAGER="dnf"
    elif command -v pacman &>/dev/null; then
      PKG_MANAGER="pacman"
    elif command -v zypper &>/dev/null; then
      PKG_MANAGER="zypper"
    elif command -v apk &>/dev/null; then
      PKG_MANAGER="apk"
    else
      return 1
    fi
  else
    return 1
  fi
}

detect_pkg_manager || true
info "OS: $OS ($ARCH), package manager: ${PKG_MANAGER:-none detected}"

# ── Helper functions ──
check_cmd() {
  if command -v "$1" &>/dev/null; then
    info "$1 found: $(command -v "$1")"
    return 0
  else
    err "$1 not found"
    return 1
  fi
}

check_version() {
  local cmd="$1" min="$2" actual="$3"
  local sorted
  sorted=$(printf '%s\n%s' "$min" "$actual" | sort -V | head -1)
  if [ "$sorted" = "$min" ]; then
    info "$cmd $actual (>= $min)"
    return 0
  else
    err "$cmd $actual is below minimum $min"
    return 1
  fi
}

# Ask user before installing
ask_install() {
  local name="$1"
  if [ "${AUTO_INSTALL:-}" = "1" ]; then
    return 0
  fi
  echo ""
  read -rp "  Install $name? [Y/n] " reply
  [[ -z "$reply" || "$reply" =~ ^[Yy]$ ]]
}

# ── Package install functions ──
install_with_pkg() {
  local pkg="$1"
  case "$PKG_MANAGER" in
    brew)   brew install "$pkg" ;;
    apt)    sudo apt-get update -qq && sudo apt-get install -y "$pkg" ;;
    dnf)    sudo dnf install -y "$pkg" ;;
    pacman) sudo pacman -S --noconfirm "$pkg" ;;
    zypper) sudo zypper install -y "$pkg" ;;
    apk)    sudo apk add "$pkg" ;;
    *)      return 1 ;;
  esac
}

install_git() {
  step "Installing git..."
  case "$PKG_MANAGER" in
    brew)   brew install git ;;
    apt)    sudo apt-get update -qq && sudo apt-get install -y git ;;
    dnf)    sudo dnf install -y git ;;
    pacman) sudo pacman -S --noconfirm git ;;
    *)      install_with_pkg git ;;
  esac
}

install_node() {
  step "Installing Node.js..."
  if [ "$OS" = "Darwin" ] && [ "$PKG_MANAGER" = "brew" ]; then
    brew install node
  elif [ "$OS" = "Linux" ]; then
    # Use NodeSource for a recent version
    if command -v curl &>/dev/null; then
      step "Using NodeSource setup script for Node.js 22.x..."
      curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - 2>/dev/null
      case "$PKG_MANAGER" in
        apt)    sudo apt-get install -y nodejs ;;
        dnf)    sudo dnf install -y nodejs ;;
        *)      install_with_pkg nodejs ;;
      esac
    else
      install_with_pkg nodejs
    fi
  else
    return 1
  fi
}

install_python() {
  step "Installing Python..."
  case "$PKG_MANAGER" in
    brew)   brew install python@3.13 ;;
    apt)    sudo apt-get update -qq && sudo apt-get install -y python3 python3-venv python3-pip ;;
    dnf)    sudo dnf install -y python3 python3-pip ;;
    pacman) sudo pacman -S --noconfirm python python-pip ;;
    *)      install_with_pkg python3 ;;
  esac
}

install_pnpm() {
  step "Installing pnpm..."
  if command -v npm &>/dev/null; then
    npm install -g pnpm
  elif command -v corepack &>/dev/null; then
    corepack enable
    corepack prepare pnpm@latest --activate
  else
    curl -fsSL https://get.pnpm.io/install.sh | sh -
    # Source env for current session
    export PNPM_HOME="${PNPM_HOME:-$HOME/.local/share/pnpm}"
    export PATH="$PNPM_HOME:$PATH"
  fi
}

install_homebrew() {
  step "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Source brew for current session
  if [ -f /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -f /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  PKG_MANAGER="brew"
}

# ═══════════════════════════════════════════════════════════════
# Run prerequisite checks with auto-install offers
# ═══════════════════════════════════════════════════════════════

MISSING=()

# macOS without Homebrew — offer to install it first
if [ "$OS" = "Darwin" ] && [ -z "$PKG_MANAGER" ]; then
  warn "Homebrew not found (recommended for macOS)"
  if ask_install "Homebrew (package manager for macOS)"; then
    install_homebrew
    info "Homebrew installed"
  fi
fi

# Git
if ! check_cmd git; then
  if [ -n "$PKG_MANAGER" ] && ask_install "git"; then
    install_git && info "git installed" || MISSING+=("git")
  else
    MISSING+=("git")
  fi
fi

# Node >= 20
if command -v node &>/dev/null; then
  NODE_VER=$(node -v | sed 's/^v//')
  if ! check_version "node" "20.0.0" "$NODE_VER"; then
    warn "Node.js $NODE_VER is too old (need >= 20)"
    if [ -n "$PKG_MANAGER" ] && ask_install "Node.js 22.x (upgrade)"; then
      install_node && info "Node.js upgraded" || MISSING+=("node>=20")
    else
      MISSING+=("node>=20")
    fi
  fi
else
  if [ -n "$PKG_MANAGER" ] && ask_install "Node.js 22.x"; then
    install_node && info "Node.js installed" || MISSING+=("node>=20")
  else
    MISSING+=("node>=20")
  fi
fi

# Python >= 3.11
if command -v python3 &>/dev/null; then
  PY_VER=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}')")
  if ! check_version "python3" "3.11.0" "$PY_VER"; then
    warn "Python $PY_VER is too old (need >= 3.11)"
    if [ -n "$PKG_MANAGER" ] && ask_install "Python 3.13 (upgrade)"; then
      install_python && info "Python upgraded" || MISSING+=("python>=3.11")
    else
      MISSING+=("python>=3.11")
    fi
  fi
else
  if [ -n "$PKG_MANAGER" ] && ask_install "Python 3"; then
    install_python && info "Python installed" || MISSING+=("python>=3.11")
  else
    MISSING+=("python>=3.11")
  fi
fi

# pnpm
if ! check_cmd pnpm; then
  if ask_install "pnpm"; then
    install_pnpm && info "pnpm installed" || MISSING+=("pnpm")
  else
    MISSING+=("pnpm")
  fi
fi

# npm (comes with node, but check)
if ! check_cmd npm; then
  MISSING+=("npm (should come with Node.js)")
fi

# ── Final check ──
if [ ${#MISSING[@]} -gt 0 ]; then
  echo ""
  err "Missing prerequisites that could not be installed:"
  for m in "${MISSING[@]}"; do
    echo "    - $m"
  done
  echo ""
  echo "  Install them manually and re-run this script."
  exit 1
fi

info "All prerequisites satisfied"

# ═══════════════════════════════════════════════════════════════
# STEP 1 — Create directories
# ═══════════════════════════════════════════════════════════════
section "Creating directory structure"

for dir in \
  "$JINN_HOME" \
  "$JINN_HOME/org" \
  "$JINN_HOME/knowledge" \
  "$JINN_HOME/sessions" \
  "$JINN_HOME/logs" \
  "$JINN_HOME/logs/archive" \
  "$JINN_HOME/tmp" \
  "$JINN_HOME/data" \
  "$JINN_HOME/com" \
  "$JINN_HOME/models" \
  "$JINN_HOME/cron" \
  "$JINN_HOME/cron/runs" \
  "$JINN_HOME/plugins" \
  "$JINN_HOME/docs" \
  "$JINN_HOME/skills" \
  "$JINN_HOME/scripts" \
  "$JINN_HOME/remote" \
  "$JINN_HOME/remote/skills" \
  "$MEM0_HOME" \
; do
  mkdir -p "$dir"
done
info "Directory structure created"

# ═══════════════════════════════════════════════════════════════
# STEP 2 — Clone & build Jinn Gateway
# ═══════════════════════════════════════════════════════════════
section "Jinn Gateway"

if [ -d "$JINN_CLI_DIR/.git" ]; then
  step "Repo already cloned at $JINN_CLI_DIR — pulling latest"
  git -C "$JINN_CLI_DIR" fetch origin custom-v2
  git -C "$JINN_CLI_DIR" checkout custom-v2
  git -C "$JINN_CLI_DIR" pull origin custom-v2
else
  step "Cloning jinn (branch custom-v2)..."
  mkdir -p "$(dirname "$JINN_CLI_DIR")"
  git clone -b custom-v2 https://github.com/firefloc-nox/jinn.git "$JINN_CLI_DIR"
fi
info "Jinn repo ready at $JINN_CLI_DIR"

step "Installing dependencies (pnpm)..."
(cd "$JINN_CLI_DIR" && pnpm install --frozen-lockfile 2>/dev/null || pnpm install)
info "Dependencies installed"

step "Building (pnpm turbo build)..."
(cd "$JINN_CLI_DIR" && pnpm turbo build)
info "Jinn Gateway built"

# ═══════════════════════════════════════════════════════════════
# STEP 3 — Setup Mem0 + MCP Memory Service
# ═══════════════════════════════════════════════════════════════
section "Mem0 & MCP Memory Service"

if [ -d "$MEM0_VENV" ]; then
  step "Venv already exists at $MEM0_VENV — upgrading packages"
else
  step "Creating Python venv..."
  python3 -m venv "$MEM0_VENV"
  info "Venv created"
fi

step "Installing mem0ai + mcp-memory-service..."
"$MEM0_VENV/bin/pip" install --upgrade pip -q
"$MEM0_VENV/bin/pip" install --upgrade mem0ai mcp-memory-service -q
info "Mem0 packages installed"

# Generate config
if [ ! -f "$MEM0_HOME/config.json" ]; then
  step "Generating config.json template..."
  sed "s|MEM0_DB_PATH|$MEM0_HOME/memory.db|g" \
    "$SCRIPT_DIR/templates/config.mem0.json" > "$MEM0_HOME/config.json"
  info "Config written to $MEM0_HOME/config.json"
  warn "Edit $MEM0_HOME/config.json to set your OPENAI_API_KEY"
else
  info "Config already exists — skipping"
fi

# ═══════════════════════════════════════════════════════════════
# STEP 4 — Clone MemViz
# ═══════════════════════════════════════════════════════════════
section "MemViz"

if [ -d "$MEMVIZ_DIR/.git" ]; then
  step "Repo already cloned at $MEMVIZ_DIR — pulling latest"
  git -C "$MEMVIZ_DIR" pull
else
  step "Cloning memviz..."
  mkdir -p "$(dirname "$MEMVIZ_DIR")"
  git clone https://github.com/pfillion42/memviz "$MEMVIZ_DIR"
fi
info "MemViz repo ready"

step "Installing dependencies (npm)..."
(cd "$MEMVIZ_DIR" && npm install)
info "MemViz dependencies installed"

# ═══════════════════════════════════════════════════════════════
# STEP 5 — Scaffold ~/.jinn/
# ═══════════════════════════════════════════════════════════════
section "Scaffolding $JINN_HOME"

# Docs — always overwrite (reference docs)
step "Installing docs..."
cp -r "$SCRIPT_DIR/scaffold/docs/"*.md "$JINN_HOME/docs/"
info "8 docs installed"

# Skills — copy if not present (don't overwrite user customizations)
step "Installing skills..."
SKILLS_INSTALLED=0
for skill_dir in "$SCRIPT_DIR/scaffold/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  target="$JINN_HOME/skills/$skill_name"
  if [ ! -d "$target" ]; then
    mkdir -p "$target"
    cp "$skill_dir"SKILL.md "$target/SKILL.md"
    SKILLS_INSTALLED=$((SKILLS_INSTALLED + 1))
  fi
done
info "$SKILLS_INSTALLED new skills installed (existing preserved)"

# Scripts
step "Installing scripts..."
cp "$SCRIPT_DIR/scaffold/scripts/"*.sh "$JINN_HOME/scripts/"
chmod +x "$JINN_HOME/scripts/"*.sh
info "Scripts installed"

# Plugins
step "Installing plugins..."
cp "$SCRIPT_DIR/templates/mem0-bridge.js" "$JINN_HOME/plugins/mem0-bridge.js"
info "mem0-bridge.js installed"

# Remote kit
step "Installing remote kit..."
cp -r "$SCRIPT_DIR/scaffold/remote/"* "$JINN_HOME/remote/"
info "Remote kit installed"

# CLAUDE.md & AGENTS.md — only if missing
for mdfile in CLAUDE.md AGENTS.md; do
  if [ ! -f "$JINN_HOME/$mdfile" ]; then
    cp "$SCRIPT_DIR/scaffold/$mdfile" "$JINN_HOME/$mdfile"
    info "$mdfile installed"
  else
    info "$mdfile already exists — preserved"
  fi
done

# Config — only if missing
if [ ! -f "$JINN_HOME/config.yaml" ]; then
  step "Generating config.yaml template..."
  sed \
    -e "s|MEM0_VENV_PYTHON|$MEM0_VENV/bin/python3|g" \
    -e "s|MCP_MEMORY_DB_PATH|$(if [ "$(uname)" = "Darwin" ]; then echo "$HOME/Library/Application Support/mcp-memory/sqlite_vec.db"; else echo "$HOME/.local/share/mcp-memory/sqlite_vec.db"; fi)|g" \
    -e "s|OPERATOR_NAME|$(whoami)|g" \
    "$SCRIPT_DIR/templates/config.yaml" > "$JINN_HOME/config.yaml"
  info "config.yaml generated"
  warn "Edit $JINN_HOME/config.yaml to configure engines, connectors, and portal"
else
  info "config.yaml already exists — preserved"
fi

# Cron — only if missing
if [ ! -f "$JINN_HOME/cron/jobs.json" ]; then
  cp "$SCRIPT_DIR/templates/cron-jobs.json" "$JINN_HOME/cron/jobs.json"
  info "cron/jobs.json initialized (empty)"
else
  info "cron/jobs.json already exists — preserved"
fi

# ═══════════════════════════════════════════════════════════════
# STEP 6 — Install start.sh / stop.sh
# ═══════════════════════════════════════════════════════════════
section "Service scripts"

cp "$SCRIPT_DIR/start.sh" "$JINN_HOME/start.sh"
cp "$SCRIPT_DIR/stop.sh" "$JINN_HOME/stop.sh"
chmod +x "$JINN_HOME/start.sh" "$JINN_HOME/stop.sh"
info "start.sh and stop.sh installed in $JINN_HOME/"

# ═══════════════════════════════════════════════════════════════
# STEP 7 — Symlinks for Claude Code / Agents
# ═══════════════════════════════════════════════════════════════
section "Engine skill symlinks"

# Claude Code skills
CLAUDE_SKILLS="$HOME/.claude/skills"
mkdir -p "$CLAUDE_SKILLS"
for skill_dir in "$JINN_HOME/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  link="$CLAUDE_SKILLS/$skill_name"
  if [ ! -L "$link" ] && [ ! -d "$link" ]; then
    ln -s "$skill_dir" "$link"
  fi
done
info "Claude Code skill symlinks updated"

# Agents skills (.agents/skills/)
AGENTS_SKILLS="$HOME/.agents/skills"
mkdir -p "$AGENTS_SKILLS"
for skill_dir in "$JINN_HOME/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  link="$AGENTS_SKILLS/$skill_name"
  if [ ! -L "$link" ] && [ ! -d "$link" ]; then
    ln -s "$skill_dir" "$link"
  fi
done
info "Agents skill symlinks updated"

# ═══════════════════════════════════════════════════════════════
# DONE
# ═══════════════════════════════════════════════════════════════
echo ""
echo -e "${GREEN}${BOLD}  Installation complete!${NC}"
echo ""
echo "  Installed components:"
echo "    Jinn Gateway   $JINN_CLI_DIR (branch: custom-v2)"
echo "    Mem0 + MCP     $MEM0_VENV"
echo "    MemViz         $MEMVIZ_DIR"
echo "    Config         $JINN_HOME/"
echo ""
echo "  Next steps:"
echo "    1. Edit $JINN_HOME/config.yaml (connectors, portal name)"
echo "    2. Edit $MEM0_HOME/config.json (API key)"
echo "    3. Start services: $JINN_HOME/start.sh"
echo "    4. Open http://localhost:7778 for the gateway"
echo ""
