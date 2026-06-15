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

KOHYA_VENV="${KOHYA_VENV:-$WORKSPACE_DIR/venv-kohya}"
PYTORCH_INDEX_URL="${PYTORCH_INDEX_URL:-https://download.pytorch.org/whl/cu124}"
TORCH_VERSION="${TORCH_VERSION:-2.6.0}"
TORCHVISION_VERSION="${TORCHVISION_VERSION:-0.21.0}"
TORCHAUDIO_VERSION="${TORCHAUDIO_VERSION:-2.6.0}"
KOHYA_CONSTRAINTS="$PROJECT_DIR/constraints/kohya-cu124.txt"
FILTER_RE='(^|[[:space:]])(torch|torchvision|torchaudio|xformers|huggingface-hub|huggingface_hub)([<=>[:space:]]|$)|sd-scripts|tensorflow==2\.15\.0\.post1|^[[:space:]]*(-e[[:space:]]+)?\.{1,2}[[:space:]]*$|kohya_ss'

if [ ! -d "$KOHYA_DIR" ]; then
  git clone https://github.com/bmaltais/kohya_ss.git "$KOHYA_DIR"
fi

cd "$KOHYA_DIR"
git submodule update --init --recursive
cd "$PROJECT_DIR"

rm -rf "$KOHYA_VENV"
python3 -m venv "$KOHYA_VENV"
source "$KOHYA_VENV/bin/activate"
python -m pip install --upgrade pip wheel
python -m pip install \
  "torch==$TORCH_VERSION" \
  "torchvision==$TORCHVISION_VERSION" \
  "torchaudio==$TORCHAUDIO_VERSION" \
  --index-url "$PYTORCH_INDEX_URL"
cd "$KOHYA_DIR"
if [ -f requirements_linux.txt ]; then
  KOHYA_REQUIREMENTS=requirements_linux.txt
else
  KOHYA_REQUIREMENTS=requirements.txt
fi
grep -vE "$FILTER_RE" "$KOHYA_REQUIREMENTS" > "$KOHYA_DIR/.requirements.filtered.txt"
python -m pip install -r "$KOHYA_DIR/.requirements.filtered.txt" -c "$KOHYA_CONSTRAINTS"

if [ -f "$KOHYA_DIR/sd-scripts/requirements.txt" ]; then
  grep -vE "$FILTER_RE" "$KOHYA_DIR/sd-scripts/requirements.txt" > "$KOHYA_DIR/sd-scripts/.requirements.filtered.txt"
  python -m pip install -r "$KOHYA_DIR/sd-scripts/.requirements.filtered.txt" -c "$KOHYA_CONSTRAINTS"
elif [ -f "$KOHYA_DIR/sd-scripts/requirements_linux.txt" ]; then
  grep -vE "$FILTER_RE" "$KOHYA_DIR/sd-scripts/requirements_linux.txt" > "$KOHYA_DIR/sd-scripts/.requirements.filtered.txt"
  python -m pip install -r "$KOHYA_DIR/sd-scripts/.requirements.filtered.txt" -c "$KOHYA_CONSTRAINTS"
fi
python -m pip uninstall -y xformers || true
cd "$PROJECT_DIR"
deactivate

echo "Kohya environment ready: $KOHYA_VENV"
