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
TORCH_VERSION="${TORCH_VERSION:-2.6.0}"
TORCHVISION_VERSION="${TORCHVISION_VERSION:-0.21.0}"
TORCHAUDIO_VERSION="${TORCHAUDIO_VERSION:-2.6.0}"

expected_cuda_version() {
  case "$PYTORCH_INDEX_URL" in
    *cu124*) echo "12.4" ;;
    *cu126*) echo "12.6" ;;
    *cu128*) echo "12.8" ;;
    *) echo "" ;;
  esac
}

install_torch() {
  local venv_dir="$1"
  local name="$2"
  local expected_cuda
  expected_cuda="$(expected_cuda_version)"

  if [ ! -d "$venv_dir" ]; then
    echo "Skipping $name: venv not found at $venv_dir"
    return
  fi

  source "$venv_dir/bin/activate"

  current_cuda="$(python - <<'PY'
try:
    import torch
    print(torch.version.cuda or "")
except Exception:
    print("")
PY
)"

  if [ -n "$expected_cuda" ] && [ "$current_cuda" = "$expected_cuda" ] && [ "${FORCE_TORCH_REINSTALL:-0}" != "1" ]; then
    echo "Skipping $name PyTorch reinstall: CUDA build already matches $expected_cuda"
  else
    python -m pip install --force-reinstall \
      "torch==$TORCH_VERSION" \
      "torchvision==$TORCHVISION_VERSION" \
      "torchaudio==$TORCHAUDIO_VERSION" \
      --index-url "$PYTORCH_INDEX_URL"
  fi

  python -m pip install --upgrade "numpy<2.0.0" "pillow<12.0" "scipy<1.12"
  python -m pip uninstall -y xformers || true

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
install_torch "${DATASET_VENV:-$WORKSPACE_DIR/venv-dataset}" "Dataset"
install_torch "$WORKSPACE_DIR/venv-kohya" "Kohya"

echo "PyTorch CUDA install complete. Index: $PYTORCH_INDEX_URL"
