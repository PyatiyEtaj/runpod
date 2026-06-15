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
COMFY_CONSTRAINTS="$PROJECT_DIR/constraints/comfyui-cu124.txt"
KOHYA_CONSTRAINTS="$PROJECT_DIR/constraints/kohya-cu124.txt"

echo "This will delete and recreate:"
echo "  $WORKSPACE_DIR/venv-comfyui"
echo "  $WORKSPACE_DIR/venv-kohya"
echo
echo "Models, datasets, ComfyUI repo, Kohya repo, and outputs will not be deleted."

rm -rf "$WORKSPACE_DIR/venv-comfyui" "$WORKSPACE_DIR/venv-kohya"

if [ ! -d "$COMFYUI_DIR" ]; then
  git clone https://github.com/comfyanonymous/ComfyUI.git "$COMFYUI_DIR"
fi

if [ ! -d "$KOHYA_DIR" ]; then
  git clone https://github.com/bmaltais/kohya_ss.git "$KOHYA_DIR"
fi

cd "$KOHYA_DIR"
git submodule update --init --recursive
cd "$PROJECT_DIR"

python3 -m venv "$WORKSPACE_DIR/venv-comfyui"
source "$WORKSPACE_DIR/venv-comfyui/bin/activate"
python -m pip install --upgrade pip wheel
python -m pip install torch torchvision torchaudio --index-url "$PYTORCH_INDEX_URL"
python -m pip install -r "$COMFYUI_DIR/requirements.txt" -c "$COMFY_CONSTRAINTS"
python -m pip install transformers accelerate safetensors pillow torchvision -c "$COMFY_CONSTRAINTS"
python -m pip uninstall -y xformers || true
deactivate

bash "$PROJECT_DIR/scripts/install_comfyui_custom_nodes.sh"
bash "$PROJECT_DIR/scripts/install_comfyui_model_paths.sh"

python3 -m venv "$WORKSPACE_DIR/venv-kohya"
source "$WORKSPACE_DIR/venv-kohya/bin/activate"
python -m pip install --upgrade pip wheel
python -m pip install torch torchvision torchaudio --index-url "$PYTORCH_INDEX_URL"
cd "$KOHYA_DIR"
if [ -f requirements_linux.txt ]; then
  KOHYA_REQUIREMENTS=requirements_linux.txt
else
  KOHYA_REQUIREMENTS=requirements.txt
fi
grep -vE 'sd-scripts|tensorflow==2\.15\.0\.post1|^[[:space:]]*(-e[[:space:]]+)?\.{1,2}[[:space:]]*$|kohya_ss|xformers' "$KOHYA_REQUIREMENTS" > "$KOHYA_DIR/.requirements.filtered.txt"
python -m pip install -r "$KOHYA_DIR/.requirements.filtered.txt" -c "$KOHYA_CONSTRAINTS"

if [ -f "$KOHYA_DIR/sd-scripts/requirements.txt" ]; then
  grep -vE 'sd-scripts|tensorflow==2\.15\.0\.post1|^[[:space:]]*(-e[[:space:]]+)?\.{1,2}[[:space:]]*$|kohya_ss|xformers' "$KOHYA_DIR/sd-scripts/requirements.txt" > "$KOHYA_DIR/sd-scripts/.requirements.filtered.txt"
  python -m pip install -r "$KOHYA_DIR/sd-scripts/.requirements.filtered.txt" -c "$KOHYA_CONSTRAINTS"
elif [ -f "$KOHYA_DIR/sd-scripts/requirements_linux.txt" ]; then
  grep -vE 'sd-scripts|tensorflow==2\.15\.0\.post1|^[[:space:]]*(-e[[:space:]]+)?\.{1,2}[[:space:]]*$|kohya_ss|xformers' "$KOHYA_DIR/sd-scripts/requirements_linux.txt" > "$KOHYA_DIR/sd-scripts/.requirements.filtered.txt"
  python -m pip install -r "$KOHYA_DIR/sd-scripts/.requirements.filtered.txt" -c "$KOHYA_CONSTRAINTS"
fi
python -m pip uninstall -y xformers || true
cd "$PROJECT_DIR"
deactivate

echo
echo "ComfyUI environment:"
source "$WORKSPACE_DIR/venv-comfyui/bin/activate"
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

echo
echo "Kohya environment:"
source "$WORKSPACE_DIR/venv-kohya/bin/activate"
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

echo
echo "Clean rebuild complete."
