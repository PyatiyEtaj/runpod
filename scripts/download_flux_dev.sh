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

mkdir -p "$FLUX_DIFFUSION_MODEL_DIR" "$FLUX_TEXT_ENCODER_DIR" "$FLUX_VAE_DIR" "$CACHE_DIR/huggingface"

source "$WORKSPACE_DIR/venv-comfyui/bin/activate"
pip install --upgrade huggingface_hub

export HF_HOME="$CACHE_DIR/huggingface"

HF_ARGS=()
if [ -n "${HF_TOKEN:-}" ]; then
  HF_ARGS+=(--token "$HF_TOKEN")
fi

huggingface-cli download "$FLUX_DEV_REPO" "$FLUX_DEV_FILE" \
  --local-dir "$FLUX_DIFFUSION_MODEL_DIR" \
  --local-dir-use-symlinks False \
  "${HF_ARGS[@]}"

huggingface-cli download "$FLUX_DEV_REPO" "$FLUX_AE_FILE" \
  --local-dir "$FLUX_VAE_DIR" \
  --local-dir-use-symlinks False \
  "${HF_ARGS[@]}"

huggingface-cli download "$FLUX_TEXT_ENCODERS_REPO" "$FLUX_CLIP_L_FILE" \
  --local-dir "$FLUX_TEXT_ENCODER_DIR" \
  --local-dir-use-symlinks False \
  "${HF_ARGS[@]}"

huggingface-cli download "$FLUX_TEXT_ENCODERS_REPO" "$FLUX_T5XXL_FILE" \
  --local-dir "$FLUX_TEXT_ENCODER_DIR" \
  --local-dir-use-symlinks False \
  "${HF_ARGS[@]}"

bash "$PROJECT_DIR/scripts/install_comfyui_model_paths.sh"

echo "Downloaded FLUX.1-dev files:"
echo "  $FLUX_DIFFUSION_MODEL_DIR/$FLUX_DEV_FILE"
echo "  $FLUX_VAE_DIR/$FLUX_AE_FILE"
echo "  $FLUX_TEXT_ENCODER_DIR/$FLUX_CLIP_L_FILE"
echo "  $FLUX_TEXT_ENCODER_DIR/$FLUX_T5XXL_FILE"
