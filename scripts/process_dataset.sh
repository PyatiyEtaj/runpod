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

DATASET_VENV="${DATASET_VENV:-$WORKSPACE_DIR/venv-dataset}"

if [ ! -d "$DATASET_VENV" ]; then
  echo "Dataset venv is missing: $DATASET_VENV"
  echo "Run: bash scripts/setup_dataset_env.sh"
  exit 1
fi

source "$DATASET_VENV/bin/activate"

NEEDS_REALESRGAN=0
EXPECT_UPSCALE_MODE=0
for arg in "$@"; do
  if [ "$EXPECT_UPSCALE_MODE" -eq 1 ]; then
    if [ "$arg" = "realesrgan_x4plus" ]; then
      NEEDS_REALESRGAN=1
    fi
    EXPECT_UPSCALE_MODE=0
    continue
  fi

  case "$arg" in
    --upscale-mode)
      EXPECT_UPSCALE_MODE=1
      ;;
    --upscale-mode=realesrgan_x4plus)
      NEEDS_REALESRGAN=1
      ;;
  esac
done

if [ "$NEEDS_REALESRGAN" -eq 1 ]; then
  if ! python - <<'PY'
import importlib.util
import sys

missing = [name for name in ("basicsr", "realesrgan") if importlib.util.find_spec(name) is None]
if missing:
    print("Missing RealESRGAN dependencies:", ", ".join(missing))
    sys.exit(1)
PY
  then
    python -m pip install \
      "basicsr>=1.4.2,<1.5.0" \
      "realesrgan>=0.3.0,<0.4.0" \
      -c "$PROJECT_DIR/constraints/dataset-cu124.txt"
  fi
fi

python "$PROJECT_DIR/scripts/process_dataset.py" \
  --project-dir "$PROJECT_DIR" \
  --input-dir "$RAW_DATASET_DIR" \
  --output-dir "$PROCESSED_DATASET_DIR" \
  --rmbg-model-dir "$RMBG_MODEL_DIR" \
  --joycaption-model-dir "$JOYCAPTION_MODEL_DIR" \
  --realesrgan-model "${REALESRGAN_X4PLUS_MODEL:-$PROJECT_DIR/models/upscaler/RealESRGAN_x4plus.pth}" \
  "$@"
deactivate
