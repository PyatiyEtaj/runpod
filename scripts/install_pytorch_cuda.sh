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

PYTORCH_INDEX_URL="${PYTORCH_INDEX_URL:-https://download.pytorch.org/whl/cu124}"

install_torch() {
  local venv_dir="$1"
  local name="$2"

  if [ ! -d "$venv_dir" ]; then
    echo "Skipping $name: venv not found at $venv_dir"
    return
  fi

  source "$venv_dir/bin/activate"
  python -m pip install --upgrade --force-reinstall torch torchvision torchaudio --index-url "$PYTORCH_INDEX_URL"
  python - <<'PY'
import torch
print("torch:", torch.__version__)
print("cuda build:", torch.version.cuda)
print("cuda available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("gpu:", torch.cuda.get_device_name(0))
PY
  deactivate
}

install_torch "$WORKSPACE_DIR/venv-comfyui" "ComfyUI"
install_torch "$WORKSPACE_DIR/venv-kohya" "Kohya"

echo "PyTorch CUDA install complete. Index: $PYTORCH_INDEX_URL"
