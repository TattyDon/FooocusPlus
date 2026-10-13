# CLAUDE.md — TattyDon/FooocusPlus

John's fork of DavidDragonsage/FooocusPlus (itself a Fooocus fork, GPL-3.0).

## What this fork is for

- **Runs locally on John's Mac:** Apple M2 Pro, 16 GB unified memory.
- **Photoreal output.** Not anime/illustration — don't spend effort on those presets.
- **What to protect:** the Fooocus UI and inpainting. They are why this codebase was chosen.
- **Roadmap:** (a) run cleanly on the Mac → (b) make it fast on Metal (MPS, maybe
  Core ML / MLX) → (c) newer photoreal models.
- **Diverges from upstream on purpose.** Don't merge or cherry-pick from
  DavidDragonsage/FooocusPlus unless John asks; don't make changes "so it
  merges cleanly later".
- Work happens on the `mac` branch.

## Mac setup (see MAC.md for the user-facing version)

- `mac/setup.sh` — one-time install with uv into `.venv` (Python 3.11).
- `run-mac.sh` — launches `entry_without_update.py --gpu-type none --preset ZI-TurboX_8GGUF`.
- `mac/requirements-mac.txt` — the lockfile; **generated** by `mac/lock.sh`
  from `requirements_versions.txt` + `requirements_macos.txt` + `mac/torch.txt`
  + `mac/overrides.txt`. Never hand-edit it.

## Rules that bite

- **The launcher pip-installs at every start.** `launch.py` runs
  `requirements_met()` on `$REQS_FILE` and installs anything whose version
  doesn't match exactly. `run-mac.sh` points `REQS_FILE` at the Mac lockfile.
  If the lockfile and `.venv` disagree, the app "fixes" `.venv` with pip behind
  uv's back. After changing a pin, regenerate the lock and re-run setup.
- **`--gpu-type none` is what stops the launcher reinstalling torch.** Upstream
  added it for Pinokio (`launch_support.py`, `dependency_resolver`). Without it,
  torchruntime picks and installs a torch build itself.
- **No FP8 on Mac.** Metal has no float8 dtype. FP8 presets and
  `--unet-in-fp8-*` / `--clip-in-fp8-*` fail; use GGUF or fp16 models.
- **groundingdino is on the startup path.** `webui.py` → `extras/inpaint_mask.py`
  → `groundingdino` at import time, so a failed build means no app, not just
  no feature. It is built with `--no-build-isolation` after torch is in `.venv`.
- **Four OpenCV distributions are pinned upstream** and all write to `cv2/`.
  `setup.sh` reinstalls `opencv-contrib-python-headless` last so the result is
  deterministic.
- **Memory ceiling.** `launch.py` defaults `PYTORCH_MPS_HIGH_WATERMARK_RATIO` to
  `0.0` (no limit) only if unset; `run-mac.sh` sets `1.7`. Don't hard-set it in
  Python again.
- **Python 3.11, not upstream's 3.10.** SciPy 1.15.x — the last release for
  3.10 — ships a Fortran `_spropack.so` that recent macOS's loader rejects
  (`__thread_bss ... offset field is not zero`), and `rembg` imports it at
  startup, so on 3.10 the app dies before the UI. 1.17.1 (PROPACK in C) needs
  3.11. Don't move back to 3.10, and check new pins have cp311 macOS arm64
  wheels. `launch.py`'s only 3.10 check is in the xformers path, unused on Mac.
- **SDXL needs `--all-in-fp16` on MPS.** The SDXL engine's `should_use_fp16()`
  returns False for MPS, so without the flag SDXL loads in fp32 (~10 GB, held
  twice while moving to the GPU) and a 16 GB Mac swaps every step — measured
  330 s/it and a 171 s model move. The VAE stays fp32 regardless (good: SDXL's
  VAE gives black images in fp16). Don't drop the flag from `run-mac.sh`.
- **Comfy runs as a subprocess** (`backend_base/comfyd.py`) using
  `sys.executable` and the parent's environment. Flux / Z-Image go through it;
  SDXL doesn't. Env vars set in `run-mac.sh` reach both.

## Testing

Cloud sessions run on Linux with no Apple GPU, so they can't run generation.
What they *can* check: `./mac/lock.sh` resolves, `uvx --from shellcheck-py
shellcheck run-mac.sh mac/*.sh` is clean, Python compiles, and source-only
packages build. Real verification is John running `./run-mac.sh` on the Mac
and reporting timings — ask for them rather than claiming something works.
