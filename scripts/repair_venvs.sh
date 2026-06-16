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

DATASET_VENV="${DATASET_VENV:-$WORKSPACE_DIR/venv-dataset}"
if [ -d "$DATASET_VENV" ]; then
  source "$DATASET_VENV/bin/activate"
  python -m pip install "huggingface-hub>=0.28.1,<1.0" "rich>=13.8.0" "numpy<2.0.0" "pillow<12.0" "scipy<1.12" "kornia>=0.7,<0.9" "opencv-python-headless>=4.8,<5.0" "realesrgan>=0.3.0,<0.4.0" -c "$PROJECT_DIR/constraints/dataset-cu124.txt"
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
