#!/usr/bin/env bash
# Start FooocusPlus on an Apple Silicon Mac. Run mac/setup.sh once first.
# Any extra arguments are passed through, e.g.:
#   ./run-mac.sh --preset RealVisXL
#   ./run-mac.sh --disable-in-browser
set -euo pipefail

cd "$(dirname "$0")"

if [[ ! -x .venv/bin/python ]]; then
    echo "No .venv found — run ./mac/setup.sh first." >&2
    exit 1
fi

# The launcher re-checks this file at every start and pip-installs anything
# that doesn't match, so point it at the Mac lockfile setup.sh installed from.
export REQS_FILE=mac/requirements-mac.txt

# Ops that Metal doesn't implement fall back to the CPU instead of erroring.
export PYTORCH_ENABLE_MPS_FALLBACK=1

# How much memory the GPU may claim, as a multiple of what macOS recommends
# for it. Upstream sets 0.0 (no limit), which on a 16 GB Mac lets a big model
# push the whole system into swap. 1.7 is PyTorch's own default: generous,
# but still a ceiling, so you get an out-of-memory error instead of a frozen
# Mac. Override per run: PYTORCH_MPS_HIGH_WATERMARK_RATIO=1.4 ./run-mac.sh
export PYTORCH_MPS_HIGH_WATERMARK_RATIO="${PYTORCH_MPS_HIGH_WATERMARK_RATIO:-1.7}"

# --gpu-type none: torch is managed by uv (mac/setup.sh), so the launcher must
#   not try to reinstall it — this is the hook upstream added for Pinokio.
# --preset: Z-Image Turbo, Q8 GGUF. Photoreal, 8 steps, and GGUF rather than
#   FP8 because Metal has no float8 type (the FP8 presets won't run on a Mac).
# entry_without_update.py: no git pull on launch. This fork diverges from
#   upstream; update with git yourself.
exec .venv/bin/python entry_without_update.py \
    --gpu-type none \
    --preset ZI-TurboX_8GGUF \
    "$@"
