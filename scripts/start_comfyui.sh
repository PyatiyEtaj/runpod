#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-/workspace/ai-ver-2}"

cd "$PROJECT_DIR"
set -a
source .env
set +a

source "$WORKSPACE_DIR/venv-comfyui/bin/activate"
cd "$COMFYUI_DIR"

if [ ! -f "$COMFYUI_DIR/extra_model_paths.yaml" ]; then
  bash "$PROJECT_DIR/scripts/install_comfyui_model_paths.sh"
fi

if [ ! -d "$COMFYUI_DIR/custom_nodes/ai_ver2_dataset_nodes" ]; then
  bash "$PROJECT_DIR/scripts/install_comfyui_custom_nodes.sh"
fi

python main.py --listen 0.0.0.0 --port 8188 --output-directory "$PROCESSED_DATASET_DIR"
