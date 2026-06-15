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
DATASET_VENV="${DATASET_VENV:-$WORKSPACE_DIR/venv-dataset}"
KOHYA_VENV="${KOHYA_VENV:-$WORKSPACE_DIR/venv-kohya}"

echo "This will delete and recreate:"
echo "  $COMFYUI_VENV"
echo "  $DATASET_VENV"
echo "  $KOHYA_VENV"
echo
echo "Models, datasets, ComfyUI repo, Kohya repo, and outputs will not be deleted."

rm -rf "$COMFYUI_VENV" "$DATASET_VENV" "$KOHYA_VENV"

bash "$PROJECT_DIR/scripts/setup_comfyui_env.sh"
bash "$PROJECT_DIR/scripts/setup_dataset_env.sh"
bash "$PROJECT_DIR/scripts/setup_kohya_env.sh"

for env_name in comfyui dataset kohya; do
  case "$env_name" in
    comfyui) venv_dir="$COMFYUI_VENV" ;;
    dataset) venv_dir="$DATASET_VENV" ;;
    kohya) venv_dir="$KOHYA_VENV" ;;
  esac

  echo
  echo "$env_name environment:"
  source "$venv_dir/bin/activate"
  python -m pip check || true
  python - <<'PY'
import torch
print("torch:", torch.__version__)
print("cuda build:", torch.version.cuda)
print("cuda available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("gpu:", torch.cuda.get_device_name(0))
PY
  deactivate
done

echo
echo "Clean rebuild complete."
