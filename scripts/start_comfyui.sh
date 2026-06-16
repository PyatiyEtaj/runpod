#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-/workspace/ai-ver-2}"

cd "$PROJECT_DIR"
set -a
source .env
set +a

COMFYUI_VENV="${COMFYUI_VENV:-$WORKSPACE_DIR/venv-comfyui}"
source "$COMFYUI_VENV/bin/activate"
cd "$COMFYUI_DIR"

if [ ! -f "$COMFYUI_DIR/extra_model_paths.yaml" ]; then
  bash "$PROJECT_DIR/scripts/install_comfyui_model_paths.sh"
fi

python main.py \
  --listen 0.0.0.0 \
  --port 8188 \
  --enable-cors-header "*" \
  --output-directory "$PROCESSED_DATASET_DIR"
