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
  "$RAW_DATASET_DIR" \
  "$PROCESSED_DATASET_DIR" \
  "$TRAIN_DATASET_DIR" \
  "$MODEL_DIR" \
  "$FLUX_MODEL_DIR" \
  "$FLUX_DIFFUSION_MODEL_DIR" \
  "$FLUX_TEXT_ENCODER_DIR" \
  "$FLUX_VAE_DIR" \
  "$JOYCAPTION_MODEL_DIR" \
  "$RMBG_MODEL_DIR" \
  "$OUTPUT_DIR" \
  "$SAMPLE_DIR" \
  "$CACHE_DIR"

echo "Project is ready."
echo "Raw images:       $RAW_DATASET_DIR"
echo "Training dataset: $TRAIN_DATASET_DIR"
echo "LoRA output:      $OUTPUT_DIR"
echo
echo "Next:"
echo "  scripts/bootstrap_runpod.sh"
echo "  scripts/start_comfyui.sh"
echo "  scripts/train_flux_lora.sh"
