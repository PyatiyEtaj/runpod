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

COMFYUI_VENV="${COMFYUI_VENV:-$WORKSPACE_DIR/venv-comfyui}"
PYTORCH_INDEX_URL="${PYTORCH_INDEX_URL:-https://download.pytorch.org/whl/cu124}"
TORCH_VERSION="${TORCH_VERSION:-2.6.0}"
TORCHVISION_VERSION="${TORCHVISION_VERSION:-0.21.0}"
TORCHAUDIO_VERSION="${TORCHAUDIO_VERSION:-2.6.0}"
COMFY_CONSTRAINTS="$PROJECT_DIR/constraints/comfyui-cu124.txt"
FILTER_RE='(^|[[:space:]])(torch|torchvision|torchaudio|xformers|huggingface-hub|huggingface_hub)([<=>[:space:]]|$)'

if [ ! -d "$COMFYUI_DIR" ]; then
  git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
fi

rm -rf "$COMFYUI_VENV"
python3 -m venv "$COMFYUI_VENV"
source "$COMFYUI_VENV/bin/activate"
python -m pip install --upgrade pip wheel
python -m pip install \
  "torch==$TORCH_VERSION" \
  "torchvision==$TORCHVISION_VERSION" \
  "torchaudio==$TORCHAUDIO_VERSION" \
  --index-url "$PYTORCH_INDEX_URL"
grep -vE "$FILTER_RE" "$COMFYUI_DIR/requirements.txt" > "$COMFYUI_DIR/.requirements.filtered.txt"
python -m pip install -r "$COMFYUI_DIR/.requirements.filtered.txt" -c "$COMFY_CONSTRAINTS"
python -m pip uninstall -y xformers || true
deactivate

bash "$PROJECT_DIR/scripts/install_comfyui_model_paths.sh"

echo "ComfyUI environment ready: $COMFYUI_VENV"
