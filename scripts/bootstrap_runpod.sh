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

mkdir -p \
  "$WORKSPACE_DIR" \
  "$MODEL_DIR" \
  "$FLUX_MODEL_DIR" \
  "$FLUX_DIFFUSION_MODEL_DIR" \
  "$FLUX_TEXT_ENCODER_DIR" \
  "$FLUX_VAE_DIR" \
  "$JOYCAPTION_MODEL_DIR" \
  "$RMBG_MODEL_DIR" \
  "$CACHE_DIR"

if [ ! -d "$COMFYUI_DIR" ]; then
  git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
fi

if [ ! -d "$KOHYA_DIR" ]; then
  git clone https://github.com/bmaltais/kohya_ss.git "$KOHYA_DIR"
fi

cd "$KOHYA_DIR"
git submodule update --init --recursive
cd "$PROJECT_DIR"

COMFYUI_VENV="${COMFYUI_VENV:-$WORKSPACE_DIR/venv-comfyui}"
DATASET_VENV="${DATASET_VENV:-$WORKSPACE_DIR/venv-dataset}"
KOHYA_VENV="${KOHYA_VENV:-$WORKSPACE_DIR/venv-kohya}"

if [ ! -d "$COMFYUI_VENV" ] || [ ! -d "$DATASET_VENV" ] || [ ! -d "$KOHYA_VENV" ] || [ "${CLEAN_REBUILD:-0}" = "1" ]; then
  bash "$PROJECT_DIR/scripts/rebuild_venvs_clean.sh"
else
  echo "Project virtual environments already exist:"
  echo "  $COMFYUI_VENV"
  echo "  $DATASET_VENV"
  echo "  $KOHYA_VENV"
  echo
  echo "Skipping dependency install. To rebuild cleanly, run:"
  echo "  bash scripts/rebuild_venvs_clean.sh"
fi

echo "Bootstrap complete."
echo "Next model step:"
echo "  scripts/download_flux_dev.sh"
echo "  scripts/download_hf_models.sh"
echo
echo "Runtime environments:"
echo "  ComfyUI: $COMFYUI_VENV"
echo "  Dataset: $DATASET_VENV"
echo "  Kohya:   $KOHYA_VENV"
