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

mkdir -p \
  "$WORKSPACE_DIR" \
  "$MODEL_DIR" \
  "$FLUX_MODEL_DIR" \
  "$FLUX_DIFFUSION_MODEL_DIR" \
  "$FLUX_TEXT_ENCODER_DIR" \
  "$FLUX_VAE_DIR" \
  "$JOYCAPTION_MODEL_DIR" \
  "$RMBG_MODEL_DIR" \
  "$CACHE_DIR"

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
pip install --upgrade pip wheel
pip install -r "$COMFYUI_DIR/requirements.txt"
pip install --upgrade huggingface_hub
deactivate

bash "$PROJECT_DIR/scripts/install_comfyui_custom_nodes.sh"

python3 -m venv "$WORKSPACE_DIR/venv-kohya"
source "$WORKSPACE_DIR/venv-kohya/bin/activate"
pip install --upgrade pip wheel
cd "$KOHYA_DIR"
if [ -f "$KOHYA_DIR/requirements_linux.txt" ]; then
  KOHYA_REQUIREMENTS=requirements_linux.txt
else
  KOHYA_REQUIREMENTS=requirements.txt
fi

FILTERED_REQUIREMENTS="$KOHYA_DIR/.requirements.filtered.txt"
grep -vE 'sd-scripts|tensorflow==2\.15\.0\.post1|^[[:space:]]*(-e[[:space:]]+)?\.{1,2}[[:space:]]*$|kohya_ss' "$KOHYA_REQUIREMENTS" > "$FILTERED_REQUIREMENTS"
pip install -r "$FILTERED_REQUIREMENTS"

if [ -f "$KOHYA_DIR/sd-scripts/requirements.txt" ]; then
  SD_SCRIPTS_REQUIREMENTS="$KOHYA_DIR/sd-scripts/.requirements.filtered.txt"
  grep -vE 'sd-scripts|tensorflow==2\.15\.0\.post1|^[[:space:]]*(-e[[:space:]]+)?\.{1,2}[[:space:]]*$|kohya_ss' "$KOHYA_DIR/sd-scripts/requirements.txt" > "$SD_SCRIPTS_REQUIREMENTS"
  pip install -r "$SD_SCRIPTS_REQUIREMENTS"
elif [ -f "$KOHYA_DIR/sd-scripts/requirements_linux.txt" ]; then
  SD_SCRIPTS_REQUIREMENTS="$KOHYA_DIR/sd-scripts/.requirements.filtered.txt"
  grep -vE 'sd-scripts|tensorflow==2\.15\.0\.post1|^[[:space:]]*(-e[[:space:]]+)?\.{1,2}[[:space:]]*$|kohya_ss' "$KOHYA_DIR/sd-scripts/requirements_linux.txt" > "$SD_SCRIPTS_REQUIREMENTS"
  pip install -r "$SD_SCRIPTS_REQUIREMENTS"
fi
cd "$PROJECT_DIR"
deactivate

echo "Bootstrap complete."
echo "Next model step:"
echo "  scripts/download_flux_dev.sh"
echo "  scripts/download_hf_models.sh"
echo
echo "Install ComfyUI custom nodes that support:"
echo "  Local dataset node: AIVer2DatasetBuilder"
echo "  JoyCaption model:   $JOYCAPTION_REPO"
echo "  RMBG model:         $RMBG_REPO"
