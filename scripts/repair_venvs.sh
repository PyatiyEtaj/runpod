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
  python -m pip install "huggingface-hub>=1.5.0,<2.0" "rich>=13.8.0" "numpy<2.0.0" "pillow<12.0" "scipy<1.12" -c "$PROJECT_DIR/constraints/comfyui-cu124.txt"
  python -m pip uninstall -y xformers || true
  python -m pip check || true
  deactivate
fi

if [ -d "$WORKSPACE_DIR/venv-kohya" ]; then
  source "$WORKSPACE_DIR/venv-kohya/bin/activate"
  python -m pip install "huggingface-hub>=0.28.1,<1.0" "rich>=13.8.0" "numpy<2.0.0" "pillow<12.0" "scipy<1.12" -c "$PROJECT_DIR/constraints/kohya-cu124.txt"
  python -m pip uninstall -y xformers || true
  python -m pip check || true
  deactivate
fi

echo "Virtual environment repair complete."
