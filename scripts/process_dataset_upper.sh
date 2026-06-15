#!/usr/bin/env bash
set -euo pipefail

bash "$(dirname "$0")/process_dataset.sh" --crop-region upper "$@"
