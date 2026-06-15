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
python "$PROJECT_DIR/scripts/process_dataset.py" \
  --project-dir "$PROJECT_DIR" \
  --input-dir "$RAW_DATASET_DIR" \
  --output-dir "$PROCESSED_DATASET_DIR" \
  --rmbg-model-dir "$RMBG_MODEL_DIR" \
  --joycaption-model-dir "$JOYCAPTION_MODEL_DIR" \
  "$@"
deactivate
