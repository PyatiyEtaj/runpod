#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="${PROJECT_DIR:-/workspace/ai-ver-2}"

cd "$PROJECT_DIR"
set -a
source .env
set +a

mkdir -p "$OUTPUT_DIR" "$SAMPLE_DIR" "$CACHE_DIR"

if [ ! -d "$TRAIN_DATASET_DIR" ] || [ -z "$(find "$TRAIN_DATASET_DIR" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) -print -quit)" ]; then
  echo "No training images found in $TRAIN_DATASET_DIR"
  exit 1
fi

KOHYA_VENV="${KOHYA_VENV:-$WORKSPACE_DIR/venv-kohya}"
source "$KOHYA_VENV/bin/activate"

# Keep Kohya isolated from dataset download settings. This venv intentionally
# does not require hf_transfer because sd-scripts currently needs old hub APIs.
export HF_HUB_ENABLE_HF_TRANSFER=0

if ! python - <<'PY'
from huggingface_hub import cached_download  # noqa: F401
PY
then
  python -m pip install "huggingface-hub>=0.25.2,<0.26.0" -c "$PROJECT_DIR/constraints/kohya-cu124.txt"
fi

cd "$KOHYA_DIR"

export HF_HOME="$CACHE_DIR/huggingface"
export TOKENIZERS_PARALLELISM=false

CONFIG_FILE="${KOHYA_CONFIG:-$PROJECT_DIR/configs/kohya/flux_lora.toml}"

if [ -f "sd-scripts/flux_train_network.py" ]; then
  python sd-scripts/flux_train_network.py --config_file "$CONFIG_FILE"
elif [ -f "flux_train_network.py" ]; then
  python flux_train_network.py --config_file "$CONFIG_FILE"
else
  echo "Cannot find flux_train_network.py in $KOHYA_DIR. Check installed kohya_ss version."
  exit 1
fi
