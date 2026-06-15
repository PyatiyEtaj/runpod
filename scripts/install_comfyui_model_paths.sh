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

mkdir -p "$COMFYUI_DIR"

cp "$PROJECT_DIR/configs/comfyui/extra_model_paths.yaml" "$COMFYUI_DIR/extra_model_paths.yaml"

echo "Installed ComfyUI extra model paths:"
echo "  $COMFYUI_DIR/extra_model_paths.yaml"
echo
echo "FLUX diffusion models: $FLUX_DIFFUSION_MODEL_DIR"
echo "FLUX text encoders:    $FLUX_TEXT_ENCODER_DIR"
echo "FLUX VAE:              $FLUX_VAE_DIR"
