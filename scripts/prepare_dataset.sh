#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-/workspace/ai-ver-2}"

cd "$PROJECT_DIR"
set -a
source .env
set +a

DATASET_REPEATS="${DATASET_REPEATS:-10}"
DATASET_CLASS_NAME="${DATASET_CLASS_NAME:-subject}"
TRAIN_SUBSET_DIR="$TRAIN_DATASET_DIR/${DATASET_REPEATS}_${DATASET_CLASS_NAME}"

mkdir -p "$RAW_DATASET_DIR" "$PROCESSED_DATASET_DIR" "$TRAIN_SUBSET_DIR"

echo "Input images: $RAW_DATASET_DIR"
echo "ComfyUI workflow: workflows/comfyui/dataset_pipeline.json"
echo
echo "Run ComfyUI with scripts/start_comfyui.sh, open port 8188, load the workflow, and process images from:"
echo "  $RAW_DATASET_DIR"
echo
echo "After ComfyUI saves processed images and .txt captions, this script syncs them into:"
echo "  $TRAIN_SUBSET_DIR"

find "$PROCESSED_DATASET_DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' -o -iname '*.txt' \) -print0 \
  | xargs -0 -r -I{} cp -n "{}" "$TRAIN_SUBSET_DIR/"

echo "Training dataset file count:"
find "$TRAIN_SUBSET_DIR" -maxdepth 1 -type f | wc -l
