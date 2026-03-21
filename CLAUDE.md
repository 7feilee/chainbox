# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Chainbox is a Docker-based portable environment for blockchain development, security research, and AI-assisted auditing. It builds a Debian 13 container with language runtimes (Go, Rust, Node.js, Haskell, Python), a full blockchain security toolchain (Foundry, Slither, Mythril, Halmos, Echidna, Medusa, Aderyn, Heimdall-rs), and Claude Code CLI. Published to Docker Hub as `7feilee/chainbox` for AMD64 and ARM64.

## Build and Run

```bash
# Build multi-arch and push
./build.sh --push

# Build for local arch and load
./build.sh --load

# Run container
./chainbox

# Run with port forwarding
./chainbox -p 8545:8545 /path/to/project

# docker-compose (reads secrets from .env, see .env.example)
docker compose run --rm chainbox
```

All scripts respect `CHAINBOX_IMAGE`, `CHAINBOX_USER`, and `CHAINBOX_PLATFORM` env vars.

## Architecture

- **Dockerfile** — Single-stage build with `ARG USERNAME=agent` for configurable container user. Organized in sections: system packages, language runtimes, blockchain dev tools, security tools, Python tools, Claude Code, JS/TS libs. Uses `SHELL ["/bin/bash", "-c"]` for build steps, but the runtime default shell is Zsh.
- **chainbox** — CLI entry point (bash script). Mounts the target directory to `/home/<user>/<dirname>` (basename of the path) and sets it as the container working directory via `exec docker run`. Auto-forwards Claude env vars and mounts `~/.claude` for session persistence. `--no-claude` disables this. Supports `-e`, `-p`, `-v`, `--name`, `--keep` flags passed through to `docker run`.
- **build.sh** — Wraps `docker buildx build` (requires buildx plugin) for multi-platform builds. Uses `--network=host` to share host networking during build. Passes `--build-arg USERNAME` from `CHAINBOX_USER`. Requires `--push` or `--load`. `--load` auto-detects the current arch via `docker info` (overrides `CHAINBOX_PLATFORM`). Supports `--no-cache`. Auto-forwards `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` from the host environment as build args (useful in restricted networks).
- **docker-compose.yml** — Alternative launcher with all env vars and volumes pre-configured. Uses `.env` for secrets (see `.env.example`). Mounts `PROJECT_DIR` (default: current dir) to `/home/<user>/workspace` — a fixed name, unlike `chainbox` which uses the basename of the target path. Also forwards `ETH_RPC_URL` and `CERTORAKEY` (which `chainbox` script does not auto-forward — use `-e` for those).
- **token-vault/** — Demo Foundry/Solidity project as a git submodule (with forge-std as nested submodule). Excluded from the Docker build context via `.dockerignore`.
- **.dockerignore** — Excludes `token-vault/`, `.env*`, `*.md`, `LICENSE` from build context.

## Key Details

- Container username is configurable via `ARG USERNAME` (Dockerfile) / `CHAINBOX_USER` (scripts). Default: `agent`. Must match at build and run time.
- `$HOME` ENV is set to `/home/${USERNAME}` — all subsequent ENV PATH entries use `$HOME` so they resolve correctly for any username.
- Go binary URL in the Dockerfile uses `TARGETARCH` (amd64/arm64) — update the version string manually when changing Go versions (currently 1.25.0).
- Both architectures (amd64/arm64) must be considered when adding new toolchains or binaries. The Dockerfile uses `TARGETARCH` for Go; other arch-specific installs use `uname -m` checks.
- Python CLI tools are installed via `uv tool install` (isolated envs in `~/.local/bin`).
- Aderyn is installed via `cargo install aderyn` (no `--locked`). Heimdall-rs is installed via its bifrost installer (`get.heimdall.rs`), not cargo.
- nvm-based commands require `source ~/.nvm/nvm.sh` before use in Dockerfile RUN steps. The `claude`, `node`, `npm`, `npx` binaries are symlinked to `~/.local/bin` so they're on PATH without sourcing nvm.
- Homebrew (linuxbrew) commands in Dockerfile RUN steps require `eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"` prefix.
- `ipython` is installed with `--with web3 --with eth-abi --with eth-utils` for interactive Ethereum research.
- Default solc version is 0.8.28 via solc-select.
- git-delta is configured as the default git pager (with `zdiff3` conflict style) inside the container image.

## Adding New Tools

Place new tools in the appropriate Dockerfile section (Development / Security / Python / JS). Add a comment with tool name and description. Verify builds on both `amd64` and `arm64`. Test locally with `./build.sh --load && ./chainbox`.

## Claude Code in this Container

- `CLAUDE_CONFIG_DIR` is set to `$HOME/.claude` in the Dockerfile.
- `chainbox` auto-mounts host `~/.claude` for OAuth token and conversation persistence.
- `chainbox` auto-forwards `ANTHROPIC_API_KEY`, `ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_MODEL`, `CLAUDE_CODE_USE_BEDROCK`, `CLAUDE_CODE_USE_VERTEX`.
- API keys are never baked into image layers — always passed at runtime.
- `--no-claude` disables auto-mounting and env forwarding.
- docker-compose additionally forwards `ETH_RPC_URL` and `CERTORAKEY` via `.env` file.
