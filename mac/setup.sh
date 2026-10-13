#!/usr/bin/env bash
# One-time install for Apple Silicon Macs. Creates .venv with Python 3.11 and
# every dependency pinned in mac/requirements-mac.txt. Safe to re-run: it
# brings an existing .venv back in line with the lockfile.
set -euo pipefail

cd "$(dirname "$0")/.."

say()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWarning:\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mError:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || die "This script is for macOS. On other systems use upstream's install."
[[ "$(uname -m)" == "arm64" ]]  || die "This script is for Apple Silicon (arm64). Intel Macs are not supported here."

# insightface has no prebuilt wheel for macOS and compiles C++ during install.
xcode-select -p >/dev/null 2>&1 || die "Xcode command line tools are missing. Run: xcode-select --install — then re-run this script."

if ! command -v uv >/dev/null 2>&1; then
    die "uv is not installed. Install it with: brew install uv  (or: curl -LsSf https://astral.sh/uv/install.sh | sh)"
fi

PYTHON_VERSION=3.11

# A .venv on another Python (an earlier version of this script used 3.10) is
# rebuilt rather than patched: compiled packages are tied to the interpreter.
if [[ -x .venv/bin/python ]] && \
   [[ "$(.venv/bin/python -c 'import sys; print("%d.%d" % sys.version_info[:2])')" != "$PYTHON_VERSION" ]]; then
    say "Replacing .venv: it is not Python $PYTHON_VERSION"
    rm -rf .venv
fi

# --seed puts pip in the venv: FooocusPlus's launcher checks its requirements at
# every start and calls pip for anything missing, so it must be there.
if [[ ! -x .venv/bin/python ]]; then
    say "Creating .venv (Python $PYTHON_VERSION)"
    uv venv --python "$PYTHON_VERSION" --seed .venv
fi
export VIRTUAL_ENV="$PWD/.venv"

LOCK=mac/requirements-mac.txt
STAGE1="$(mktemp)"
trap 'rm -f "$STAGE1"' EXIT

# groundingdino-py ships only as source and its build imports torch, so it
# has to build against the torch in .venv (no build isolation) — which means
# torch must already be installed. It goes in a second step.
grep -v '^groundingdino-py==' "$LOCK" > "$STAGE1"

say "Installing dependencies (first run downloads a few GB)"
uv pip install --python .venv/bin/python -r "$STAGE1"

say "Building groundingdino-py against the installed torch"
GDINO="$(grep '^groundingdino-py==' "$LOCK")"
# Not optional: webui.py imports extras/inpaint_mask.py, which imports
# groundingdino at module load, so the app will not start without it.
uv pip install --python .venv/bin/python --no-deps --no-build-isolation "$GDINO" \
    || die "groundingdino-py failed to build (see above). The app cannot start without it."

# Four OpenCV distributions are pinned upstream and all install into the same
# cv2/ directory, so whichever lands last wins. Make that deterministic:
# contrib-headless 4.10 is the newest and a superset of the other three.
say "Fixing the OpenCV install order"
uv pip install --python .venv/bin/python --no-deps --reinstall \
    "$(grep '^opencv-contrib-python-headless==' "$LOCK")"

say "Checking torch can see the Apple GPU"
.venv/bin/python - <<'EOF'
import torch
print(f"torch {torch.__version__}, MPS available: {torch.backends.mps.is_available()}")
if not torch.backends.mps.is_available():
    raise SystemExit("MPS is not available — generation would run on the CPU.")
EOF

say "Done. Start FooocusPlus with: ./run-mac.sh"
