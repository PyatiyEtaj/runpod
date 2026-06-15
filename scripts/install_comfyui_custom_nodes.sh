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

TARGET_DIR="$COMFYUI_DIR/custom_nodes/ai_ver2_dataset_nodes"
SOURCE_DIR="$PROJECT_DIR/comfyui/custom_nodes/ai_ver2_dataset_nodes"

mkdir -p "$COMFYUI_DIR/custom_nodes"
rm -rf "$TARGET_DIR"
cp -r "$SOURCE_DIR" "$TARGET_DIR"

source "$WORKSPACE_DIR/venv-comfyui/bin/activate"
pip install --upgrade transformers accelerate safetensors pillow torchvision
pip install --upgrade "huggingface-hub>=0.28.1,<1.0" "rich>=13.8.0"

echo "Installed local ComfyUI custom nodes:"
echo "  $TARGET_DIR"
echo
echo "Available node:"
echo "  AIVer2DatasetBuilder"
