#!/usr/bin/env bash
# Jinn Stack — One-line bootstrap
# Usage: bash <(curl -sL https://raw.githubusercontent.com/firefloc-nox/jinn-stack/main/bootstrap.sh)

set -euo pipefail

STACK_DIR="${JINN_STACK_DIR:-$HOME/dev/jinn-stack}"

echo "Jinn Stack — Bootstrap"
echo ""

if [ -d "$STACK_DIR/.git" ]; then
  echo "Updating existing installation at $STACK_DIR..."
  git -C "$STACK_DIR" pull origin main
else
  echo "Cloning jinn-stack to $STACK_DIR..."
  mkdir -p "$(dirname "$STACK_DIR")"
  git clone https://github.com/firefloc-nox/jinn-stack.git "$STACK_DIR"
fi

echo ""
echo "Running installer..."
echo ""
bash "$STACK_DIR/install.sh"
