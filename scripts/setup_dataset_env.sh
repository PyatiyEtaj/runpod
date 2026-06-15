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

DATASET_VENV="${DATASET_VENV:-$WORKSPACE_DIR/venv-dataset}"
PYTORCH_INDEX_URL="${PYTORCH_INDEX_URL:-https://download.pytorch.org/whl/cu124}"
TORCH_VERSION="${TORCH_VERSION:-2.6.0}"
TORCHVISION_VERSION="${TORCHVISION_VERSION:-0.21.0}"
TORCHAUDIO_VERSION="${TORCHAUDIO_VERSION:-2.6.0}"
DATASET_CONSTRAINTS="$PROJECT_DIR/constraints/dataset-cu124.txt"

rm -rf "$DATASET_VENV"
python3 -m venv "$DATASET_VENV"
source "$DATASET_VENV/bin/activate"
python -m pip install --upgrade pip wheel
python -m pip install \
  "torch==$TORCH_VERSION" \
  "torchvision==$TORCHVISION_VERSION" \
  "torchaudio==$TORCHAUDIO_VERSION" \
  --index-url "$PYTORCH_INDEX_URL"
python -m pip install \
  transformers accelerate safetensors pillow scipy numpy timm einops sentencepiece protobuf \
  -c "$DATASET_CONSTRAINTS"
deactivate

echo "Dataset processor environment ready: $DATASET_VENV"
