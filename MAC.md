# FooocusPlus on Apple Silicon

This fork's Mac setup: uv-managed Python 3.11, every dependency pinned, no
self-update, one command to start. Aimed at an M-series Mac with 16 GB.

## Install (once)

```bash
xcode-select --install        # skip if already installed
brew install uv               # or: curl -LsSf https://astral.sh/uv/install.sh | sh
git clone -b mac https://github.com/TattyDon/FooocusPlus.git
cd FooocusPlus
./mac/setup.sh
```

`setup.sh` creates `.venv/`, installs from `mac/requirements-mac.txt`, builds
the two packages that have no Mac wheel (insightface, groundingdino-py), and
finishes by checking that torch can see the GPU (`MPS available: True`).
Re-running it is safe.

## Run

```bash
./run-mac.sh
```

The UI opens in your browser at http://127.0.0.1:7865 (port fixed by
`launch.py`). Extra arguments pass straight through:

```bash
./run-mac.sh --preset RealVisXL      # SDXL photoreal instead of Z-Image
./run-mac.sh --disable-in-browser    # don't open a browser tab
```

**First generation downloads the model** — roughly 10–11 GB for the default
Z-Image preset (the model, its Qwen3 text encoder, and the VAE). It looks
stuck while that happens; watch the terminal.

Models, presets, outputs and settings live in **`../UserDir`** — the folder
*next to* the repo, not inside it (upstream's default). Pass
`--user-dir /some/path` to put it elsewhere.

## Presets that suit this Mac

| Preset | Engine | Notes |
|---|---|---|
| `ZI-TurboX_8GGUF` (default) | Z-Image Turbo, Q8 GGUF | Photoreal, 8 steps. Best quality for the memory. |
| `ZI-TurboX_5GGUF` | Z-Image Turbo, Q5 GGUF | Use if Q8 runs out of memory or is too slow. |
| `RealVisXL`, `Juggernaut9`, `RealisticPhoto` | SDXL | The original Fooocus engine; fastest, full inpainting support. |

**Don't use the FP8 presets** (`ZI-Turbo`, `ZI-TurboX`, `*_AIO`, `Flux1D_FP8`):
Metal has no 8-bit float type, so they fail on a Mac. Pick a `GGUF` variant.

## Memory

`run-mac.sh` sets `PYTORCH_MPS_HIGH_WATERMARK_RATIO=1.7` (PyTorch's own
default). Upstream sets `0.0`, which removes the limit entirely and on 16 GB
can swap the whole machine into a crawl. With a ceiling, a model that doesn't
fit gives an out-of-memory error instead. To experiment:

```bash
PYTORCH_MPS_HIGH_WATERMARK_RATIO=1.4 ./run-mac.sh   # stricter
PYTORCH_MPS_HIGH_WATERMARK_RATIO=0.0 ./run-mac.sh   # upstream behaviour, no limit
```

Close other heavy apps (browsers with many tabs, Docker) before generating.

## Updating

There is no auto-update. `git pull` on the `mac` branch, then re-run
`./mac/setup.sh` to bring `.venv` in line with any lockfile change.

## Changing dependencies

Edit `requirements_versions.txt`, `requirements_macos.txt`, `mac/torch.txt`
or `mac/overrides.txt`, then run `./mac/lock.sh` (works on any OS) and commit
the regenerated `mac/requirements-mac.txt`. The launcher re-checks that file
at every start and pip-installs anything that doesn't match, so it must stay
the single source of truth.

## Reporting a baseline

For the speed work, note for each preset: time for the first image (after the
download), time for a second image, and the `it/s` or `s/it` the terminal
prints during sampling. Activity Monitor's **Memory Pressure** graph during
generation is useful too.
