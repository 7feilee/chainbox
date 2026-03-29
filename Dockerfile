FROM debian:13

ARG USERNAME=agent
ARG DEBIAN_FRONTEND=noninteractive

LABEL org.opencontainers.image.title="chainbox"
LABEL org.opencontainers.image.description="Portable blockchain development and security research environment"
LABEL org.opencontainers.image.source="https://github.com/7feilee/chainbox"
LABEL org.opencontainers.image.licenses="MIT"

# System packages (including native deps for blockchain security tools)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    bash-completion ca-certificates curl git gnupg htop less locales-all man-db \
    openssh-server psmisc python3-dev python3-venv rsync sudo tmux vim wget iftop iotop \
    build-essential zsh fio smartmontools apache2-utils \
    cloc cmake make gdb jq ncdu progress rclone strace socat binutils \
    dnsutils whois mtr lftp iperf3 ranger tcpdump zstd ffmpeg exiftool \
    netcat-openbsd p7zip sqlite3 \
    libffi-dev libffi8 libgmp-dev libgmp10 libncurses-dev libncurses6 libtinfo6 pkg-config \
    libssl-dev libleveldb-dev && \
    rm -rf /var/lib/apt/lists/*

RUN useradd -ms /usr/bin/zsh ${USERNAME} && \
    usermod -aG sudo ${USERNAME} && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER ${USERNAME}
ENV HOME=/home/${USERNAME}
WORKDIR $HOME
SHELL ["/bin/bash", "-c"]

# Shell environment (Zsh + oh-my-zsh + plugins + vim)
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" && \
    curl https://raw.githubusercontent.com/zzh1996/zshrc/master/zshrc.sh > ~/.zshrc.sh && \
    sed -i '/source $ZSH\/oh-my-zsh.sh/isource ~/.zshrc.sh' ~/.zshrc && \
    git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions && \
    git clone https://github.com/zsh-users/zsh-completions ~/.oh-my-zsh/custom/plugins/zsh-completions && \
    git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting && \
    curl https://raw.githubusercontent.com/wklken/vim-for-server/master/vimrc > ~/.vimrc

# ========================
# Language Runtimes
# ========================

# Go
ARG TARGETARCH
RUN wget https://go.dev/dl/go1.25.0.linux-${TARGETARCH}.tar.gz -O go.tar.gz && \
    sudo tar -C /usr/local -xzf go.tar.gz && \
    rm go.tar.gz
ENV PATH=$PATH:/usr/local/go/bin:$HOME/go/bin

# Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH=$PATH:$HOME/.cargo/bin

# nvm + Node.js
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash && \
    source ~/.nvm/nvm.sh && \
    nvm install node

# uv (Python package manager)
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH=$PATH:$HOME/.local/bin

# Haskell
RUN curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | BOOTSTRAP_HASKELL_NONINTERACTIVE=1 sh && \
    echo 'source ~/.ghcup/env' >> ~/.zshrc

# Homebrew
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" && \
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.zshrc

# Brew packages + git-delta config
RUN eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && \
    brew install jless ripgrep git-delta && \
    git config --global core.pager delta && \
    git config --global interactive.diffFilter 'delta --color-only' && \
    git config --global delta.navigate true && \
    git config --global merge.conflictStyle zdiff3

# ========================
# Blockchain Development
# ========================

# Foundry (forge, cast, anvil, chisel) — Solidity toolkit
RUN curl -L https://foundry.paradigm.xyz | bash && $HOME/.foundry/bin/foundryup
ENV PATH=$PATH:$HOME/.foundry/bin

# Huff — low-level EVM assembly language
RUN curl -L get.huff.sh | bash && $HOME/.huff/bin/huffup
ENV PATH=$PATH:$HOME/.huff/bin

# Solidity compiler version manager + default compiler
RUN uv tool install solc-select && \
    solc-select install 0.8.28 && \
    solc-select use 0.8.28

# Vyper — Pythonic smart contract language
RUN uv tool install vyper

# ========================
# Blockchain Security
# ========================

# Slither — Solidity static analysis (Trail of Bits)
RUN uv tool install slither-analyzer

# Mythril — EVM symbolic execution and vulnerability detection
RUN uv tool install mythril

# Halmos — symbolic testing for Foundry projects (a]0)
RUN uv tool install halmos

# Certora CLI — formal verification
RUN uv tool install certora-cli

# Aderyn — fast Rust-based Solidity static analysis (Cyfrin)
RUN cargo install aderyn

# Heimdall-rs — EVM bytecode decompiler and reverse engineering toolkit
RUN curl -L https://get.heimdall.rs | bash && $HOME/.bifrost/bin/bifrost

# Medusa — coverage-guided smart contract fuzzer (Trail of Bits)
RUN go install github.com/crytic/medusa@latest

# Echidna — property-based smart contract fuzzer (Trail of Bits)
RUN eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)" && \
    brew install echidna

# ========================
# Python Tools & Libraries
# ========================

# ipython with Ethereum libraries for interactive security research
RUN uv tool install ipython --with web3 --with eth-abi --with eth-utils

# ========================
# AI-Assisted Development
# ========================

# Bun — JS/TS runtime (required by Claude Code Telegram plugin MCP server)
RUN curl -fsSL https://bun.sh/install | bash
ENV PATH=$HOME/.bun/bin:$PATH

# Claude Code CLI (Anthropic)
RUN source ~/.nvm/nvm.sh && npm install -g @anthropic-ai/claude-code

# ========================
# JS/TS Ethereum Libraries
# ========================

RUN source ~/.nvm/nvm.sh && npm install -g ethers viem

# Expose nvm node/npm binaries on PATH for all shells (claude, npx, node)
# nvm installs to a versioned dir; this symlinks the active version to a stable path
RUN NODE_DIR="$(find $HOME/.nvm/versions/node -maxdepth 1 -type d | sort -V | tail -1)" && \
    ln -sf "$NODE_DIR/bin/node" $HOME/.local/bin/node && \
    ln -sf "$NODE_DIR/bin/npm" $HOME/.local/bin/npm && \
    ln -sf "$NODE_DIR/bin/npx" $HOME/.local/bin/npx && \
    ln -sf "$NODE_DIR/bin/claude" $HOME/.local/bin/claude

# ========================
# Claude Code Configuration
# ========================

# Config directory for credential/session persistence (mount as volume)
ENV CLAUDE_CONFIG_DIR=$HOME/.claude

# ========================
# Environment
# ========================

ENV TZ=America/Los_Angeles
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
CMD ["zsh"]
