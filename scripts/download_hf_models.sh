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

REALESRGAN_X4PLUS_MODEL="${REALESRGAN_X4PLUS_MODEL:-$PROJECT_DIR/models/upscaler/RealESRGAN_x4plus.pth}"
REALESRGAN_X4PLUS_URL="${REALESRGAN_X4PLUS_URL:-https://github.com/xinntao/Real-ESRGAN/releases/download/v0.1.0/RealESRGAN_x4plus.pth}"

mkdir -p "$JOYCAPTION_MODEL_DIR" "$RMBG_MODEL_DIR" "$(dirname "$REALESRGAN_X4PLUS_MODEL")" "$CACHE_DIR/huggingface"

DATASET_VENV="${DATASET_VENV:-$WORKSPACE_DIR/venv-dataset}"
if [ ! -d "$DATASET_VENV" ]; then
  bash "$PROJECT_DIR/scripts/setup_dataset_env.sh"
fi

source "$DATASET_VENV/bin/activate"
python -m pip install "huggingface-hub>=0.28.1,<1.0" -c "$PROJECT_DIR/constraints/dataset-cu124.txt"

export HF_HOME="$CACHE_DIR/huggingface"

HF_ARGS=()
if [ -n "${HF_TOKEN:-}" ]; then
  HF_ARGS+=(--token "$HF_TOKEN")
fi

hf download "$JOYCAPTION_REPO" \
  --local-dir "$JOYCAPTION_MODEL_DIR" \
  "${HF_ARGS[@]}"

hf download "$RMBG_REPO" \
  --local-dir "$RMBG_MODEL_DIR" \
  "${HF_ARGS[@]}"

if [ ! -f "$REALESRGAN_X4PLUS_MODEL" ]; then
  python - "$REALESRGAN_X4PLUS_URL" "$REALESRGAN_X4PLUS_MODEL" <<'PY'
import sys
import urllib.request
from pathlib import Path

url = sys.argv[1]
target = Path(sys.argv[2])
target.parent.mkdir(parents=True, exist_ok=True)
with urllib.request.urlopen(url) as response:
    target.write_bytes(response.read())
PY
fi

echo "Downloaded:"
echo "  JoyCaption: $JOYCAPTION_MODEL_DIR"
echo "  RMBG-2.0:   $RMBG_MODEL_DIR"
echo "  RealESRGAN: $REALESRGAN_X4PLUS_MODEL"

if [ ! -f "$RMBG_MODEL_DIR/birefnet.py" ] || [ ! -f "$RMBG_MODEL_DIR/BiRefNet_config.py" ]; then
  echo
  echo "Warning: RMBG local directory is missing custom-code files."
  echo "Expected:"
  echo "  $RMBG_MODEL_DIR/birefnet.py"
  echo "  $RMBG_MODEL_DIR/BiRefNet_config.py"
  echo "The dataset processor can fall back to RMBG_REPO=$RMBG_REPO if HF_TOKEN is set."
fi
