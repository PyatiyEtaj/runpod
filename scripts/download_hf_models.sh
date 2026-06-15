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

mkdir -p "$JOYCAPTION_MODEL_DIR" "$RMBG_MODEL_DIR" "$CACHE_DIR/huggingface"

source "$WORKSPACE_DIR/venv-comfyui/bin/activate"
pip install --upgrade "huggingface_hub>=0.28.1,<1.0"

export HF_HOME="$CACHE_DIR/huggingface"

HF_ARGS=()
if [ -n "${HF_TOKEN:-}" ]; then
  HF_ARGS+=(--token "$HF_TOKEN")
fi

hf download "$JOYCAPTION_REPO" \
  --local-dir "$JOYCAPTION_MODEL_DIR" \
  --local-dir-use-symlinks False \
  "${HF_ARGS[@]}"

hf download "$RMBG_REPO" \
  --local-dir "$RMBG_MODEL_DIR" \
  --local-dir-use-symlinks False \
  "${HF_ARGS[@]}"

echo "Downloaded:"
echo "  JoyCaption: $JOYCAPTION_MODEL_DIR"
echo "  RMBG-2.0:   $RMBG_MODEL_DIR"
