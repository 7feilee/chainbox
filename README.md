# Chainbox

A portable, multi-architecture Docker environment for blockchain development, security research, and AI-assisted auditing with Claude Code. Ships with Foundry, a full security analysis suite, multiple language runtimes, and first-class Claude Code integration.

Published to Docker Hub as `7feilee/chainbox` for both `linux/amd64` and `linux/arm64`.

## Quick Start

```bash
# Run with current directory mounted
./chainbox

# Run with a specific project directory
./chainbox ~/projects/my-contract

# Expose Anvil port
./chainbox -p 8545:8545 .

# Mount SSH keys for git operations
./chainbox -v $HOME/.ssh:/home/agent/.ssh .

# Or use docker-compose
docker compose run --rm chainbox
```

Run `./chainbox --help` for all options.

The `chainbox` script automatically:
- Mounts your directory into the container at `/home/<user>/<dirname>`
- Forwards `ANTHROPIC_API_KEY` if set in your shell (no `-e` needed)
- Mounts `~/.claude` from your host for OAuth token and session persistence
- Drops you into an interactive Zsh session with all tools available

## Building the Image

```bash
# Build multi-arch and push to registry
./build.sh --push

# Build for your local architecture and load into Docker
./build.sh --load

# Build without cache
./build.sh --push --no-cache
```

### Custom Image Name

```bash
# Build and push to your own repo
CHAINBOX_IMAGE=yourusername/chainbox ./build.sh --push

# Run using your own image
CHAINBOX_IMAGE=yourusername/chainbox ./chainbox
```

### Custom Username

The container user defaults to `agent`. To change it, set `CHAINBOX_USER` at both build and run time:

```bash
# Build with custom username
CHAINBOX_USER=alice ./build.sh --load

# Run with matching username
CHAINBOX_USER=alice ./chainbox .
```

### Build for a Single Platform

```bash
CHAINBOX_PLATFORM=linux/arm64 ./build.sh --push
```

## Claude Code (AI-Assisted Development)

[Claude Code](https://docs.anthropic.com/en/docs/claude-code) is pre-installed — Anthropic's agentic coding CLI that reads your codebase, edits files, runs commands, and assists with blockchain development and security audits.

### Authentication

There are three ways to authenticate, depending on your setup:

**Option 1: API Key (recommended for Docker)**

Set your API key on the host — `chainbox` auto-forwards it:

```bash
export ANTHROPIC_API_KEY=sk-ant-api03-...
./chainbox .

# Inside the container, Claude is ready immediately:
claude
```

**Option 2: OAuth Login (Claude Pro/Team subscription)**

The `chainbox` script auto-mounts `~/.claude` from your host, so OAuth tokens persist across container restarts:

```bash
./chainbox .

# Inside the container, login once:
claude auth login

# The token is saved to your host's ~/.claude — next time, you're already logged in
```

**Option 3: Cloud Providers (Bedrock / Vertex AI)**

```bash
export CLAUDE_CODE_USE_BEDROCK=true   # AWS Bedrock
# or
export CLAUDE_CODE_USE_VERTEX=true    # Google Vertex AI

./chainbox .
```

### Check Auth Status

```bash
# Inside the container
claude auth status --text
```

### Using Claude for Blockchain Security

```bash
# Interactive session in your project
claude

# One-shot tasks (headless / CI-friendly)
claude -p "Review this contract for reentrancy vulnerabilities"
claude -p "Write a Foundry fuzz test for the withdraw function"
claude -p "Explain what this on-chain bytecode does" --allowedTools "Bash,Read"

# Resume previous conversation
claude -c

# Structured output for scripting
claude -p "List all external calls in src/Vault.sol" --output-format json
```

### Session Persistence

The `chainbox` script auto-mounts `~/.claude` between your host and the container:

| What persists | Where |
|---------------|-------|
| OAuth tokens | `~/.claude/.credentials.json` |
| Conversation history | `~/.claude/projects/` |
| User settings | `~/.claude/settings.json` |
| Global CLAUDE.md | `~/.claude/CLAUDE.md` |

This means:
- Login once with `claude auth login`, and every future container has access
- Conversation history survives container restarts (`claude -c` to continue)
- Custom settings and instructions carry across sessions

To disable this behavior:

```bash
./chainbox --no-claude .
```

### Docker Compose

For persistent environments with all secrets configured:

```bash
cp .env.example .env
# Edit .env with your keys

docker compose run --rm chainbox
```

### Security Notes

- API keys are **never** baked into the Docker image — they're passed at runtime only
- `~/.claude` is mounted as a volume, not copied into the image
- Use `claude auth logout` to clear credentials from the mounted volume
- For CI/CD, use `ANTHROPIC_API_KEY` env var with `-p` (headless) mode — no persistent state needed

## Blockchain Development Tools

| Tool | Description |
|------|-------------|
| **Foundry** (`forge`, `cast`, `anvil`, `chisel`) | The primary Solidity development toolkit — compile, test, fuzz, deploy, debug, and interact with smart contracts |
| **solc-select** | Solidity compiler version manager — switch between `solc` versions per project |
| **Huff** | Low-level EVM assembly language for writing gas-optimized contracts with direct opcode access |
| **Vyper** | Pythonic smart contract language — security-focused alternative to Solidity |
| **ethers.js** | JavaScript library for Ethereum interaction (globally installed) |
| **viem** | Modern TypeScript Ethereum library — type-safe, performant alternative to ethers |
| **web3.py** / **eth-abi** / **eth-utils** | Python Ethereum libraries (available inside `ipython` for interactive research) |

### Common Foundry Workflows

```bash
# Initialize a new project
forge init my-project

# Build contracts
forge build

# Run tests with verbosity
forge test -vvvv

# Fork mainnet for testing
forge test --fork-url https://eth.llamarpc.com

# Deploy a contract
forge create src/Counter.sol:Counter --rpc-url <RPC_URL> --private-key <KEY>

# Interact with on-chain contracts
cast call <ADDRESS> "balanceOf(address)" <WALLET> --rpc-url https://eth.llamarpc.com

# Start a local Ethereum node
anvil

# Open Solidity REPL
chisel

# Manage dependencies with Soldeer (built into Foundry)
forge soldeer install
```

## Blockchain Security Tools

| Tool | Type | Description |
|------|------|-------------|
| **Slither** | Static Analysis | Trail of Bits' Solidity analyzer — detects vulnerabilities, prints contract summaries, integrates with CI |
| **Aderyn** | Static Analysis | Cyfrin's fast Rust-based analyzer — complements Slither with additional detectors |
| **Mythril** | Symbolic Execution | Deep EVM bytecode analysis — finds reentrancy, overflows, and access control issues |
| **Halmos** | Symbolic Testing | Proves properties hold for *all* inputs in Foundry test format — not sampling, full coverage |
| **Echidna** | Fuzzing | Property-based smart contract fuzzer by Trail of Bits (Haskell-based) |
| **Medusa** | Fuzzing | Coverage-guided parallelized fuzzer by Trail of Bits (Go-based, complements Echidna) |
| **Heimdall-rs** | Reverse Engineering | EVM bytecode decompiler, disassembler, and ABI decoder for analyzing on-chain contracts |
| **Certora CLI** | Formal Verification | Write CVL specs to mathematically prove contract correctness (requires API key — set `CERTORAKEY`) |

### Security Audit Workflow

```bash
# --- Static Analysis ---
slither .
slither . --detect reentrancy-eth,unchecked-transfer
aderyn .

# --- Symbolic Execution ---
myth analyze src/Vault.sol --solc-json mythril.config.json
halmos --function check_

# --- Fuzzing ---
forge test --match-test testFuzz
echidna . --contract MyContract --config echidna.yaml
medusa fuzz

# --- Reverse Engineering ---
heimdall decompile --rpc-url https://eth.llamarpc.com <ADDRESS>
heimdall decode <CALLDATA>

# --- Formal Verification (Certora) ---
certoraRun certora/conf/Vault.conf
```

### Interactive Security Research with IPython

The `ipython` shell comes pre-loaded with `web3`, `eth_abi`, and `eth_utils`:

```python
$ ipython

from web3 import Web3
from eth_abi import encode, decode

w3 = Web3(Web3.HTTPProvider("https://eth.llamarpc.com"))
print(w3.eth.block_number)

decode(["address", "uint256"], bytes.fromhex("..."))
encode(["address", "uint256"], ["0xdead...", 1000])
```

## Language Runtimes

| Runtime | Version / Manager | Notes |
|---------|-------------------|-------|
| **Go** | 1.25.0 | Installed from official release |
| **Rust** | Latest stable (rustup) | Includes `cargo` for building Rust-based tools |
| **Node.js** | Latest LTS (nvm) | Use `nvm install <version>` to switch |
| **Python** | System + uv | Use `uv` for package management |
| **Haskell** | GHCup | `source ~/.ghcup/env` to activate |
| **Homebrew** | Linuxbrew | `brew install <pkg>` for additional tools |

## System Utilities

- **Development**: `build-essential`, `cmake`, `make`, `gdb`, `git`, `cloc`, `jq`, `sqlite3`
- **Shell**: Zsh + oh-my-zsh with autosuggestions, completions, syntax-highlighting
- **Editor**: Vim (pre-configured), `jless` (JSON viewer)
- **Search**: `ripgrep` (`rg`), `ranger` (file manager)
- **Git**: `git-delta` (syntax-highlighted diffs, configured as default pager)
- **Network**: `curl`, `wget`, `mtr`, `tcpdump`, `iperf3`, `socat`, `netcat`, `dnsutils`, `whois`, `lftp`
- **Monitoring**: `htop`, `iftop`, `iotop`, `strace`, `ncdu`, `progress`
- **Archive/Media**: `zstd`, `p7zip`, `ffmpeg`, `exiftool`
- **Storage**: `fio`, `smartmontools`, `rclone`

## Container Details

- **Base image**: Debian 13 (Trixie)
- **User**: configurable via `CHAINBOX_USER` (default: `agent`), non-root with passwordless sudo
- **Shell**: Zsh with oh-my-zsh
- **Timezone**: `America/Los_Angeles`
- **Locale**: `en_US.UTF-8`
- **Architectures**: `linux/amd64`, `linux/arm64`

## Environment Variables

Copy `.env.example` to `.env` and fill in your keys:

```bash
cp .env.example .env
```

| Variable | Purpose | Auto-forwarded |
|----------|---------|:--------------:|
| `ANTHROPIC_API_KEY` | Claude Code API key | Yes |
| `ANTHROPIC_AUTH_TOKEN` | Bearer token for LLM gateways/proxies | Yes |
| `ANTHROPIC_MODEL` | Override Claude model (e.g., `claude-opus-4-6`) | Yes |
| `CLAUDE_CODE_USE_BEDROCK` | Use AWS Bedrock as backend | Yes |
| `CLAUDE_CODE_USE_VERTEX` | Use Google Vertex AI as backend | Yes |
| `CERTORAKEY` | Certora Prover formal verification API key | No |
| `ETH_RPC_URL` | Default Ethereum RPC endpoint | No |
| `CHAINBOX_IMAGE` | Override Docker image name (default: `7feilee/chainbox`) | — |
| `CHAINBOX_PLATFORM` | Override build platforms (default: `linux/amd64,linux/arm64`) | — |
| `CHAINBOX_USER` | Container username (default: `agent`) | — |

"Auto-forwarded" means `chainbox` passes it to the container automatically if set in your shell. For others, use `-e`:

```bash
./chainbox -e ETH_RPC_URL=$ETH_RPC_URL -e CERTORAKEY=$CERTORAKEY .
```

## Updating Tools

Inside the container, most tools can self-update:

```bash
foundryup                    # Update Foundry
huffup                       # Update Huff
rustup update                # Update Rust
solc-select install 0.8.29   # Install new Solidity version
uv tool upgrade slither-analyzer  # Update Slither
uv tool upgrade mythril      # Update Mythril
uv tool upgrade halmos       # Update Halmos
```

## Extending the Image

```dockerfile
FROM 7feilee/chainbox

# Install additional tools
RUN source ~/.nvm/nvm.sh && npm install -g hardhat
RUN uv tool install wake
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/add-tool`)
3. Edit the `Dockerfile` to add your changes
4. Test locally: `./build.sh --load && ./chainbox`
5. Commit and open a pull request

When adding new tools, please:
- Add a comment with the tool name and a brief description
- Place it in the appropriate section (Development / Security / Python / JS)
- Verify it builds on both `amd64` and `arm64`

## Acknowledgements

The `chainbox` CLI script is inspired by [mydocker](https://github.com/zzh1996/mydocker) by [@zzh1996](https://github.com/zzh1996).

## License

[MIT](LICENSE)
