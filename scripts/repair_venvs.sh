#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-/workspace/ai-ver-2}"

cd "$PROJECT_DIR"

if [ ! -f .env ]; then
  cp .env.example .env
fi

set -a
source .env
set +a

if [ -d "$WORKSPACE_DIR/venv-comfyui" ]; then
  source "$WORKSPACE_DIR/venv-comfyui/bin/activate"
  python -m pip install --upgrade --force-reinstall "huggingface-hub>=1.5.0,<2.0" "rich>=13.8.0"
  python -m pip check || true
  deactivate
fi

if [ -d "$WORKSPACE_DIR/venv-kohya" ]; then
  source "$WORKSPACE_DIR/venv-kohya/bin/activate"
  python -m pip install --upgrade "huggingface-hub>=0.28.1,<1.0" "rich>=13.8.0"
  python -m pip check || true
  deactivate
fi

echo "Virtual environment repair complete."
