# Login environment configuration

export EDITOR=nvim
export GIT_EDITOR=nvim
export BUN_INSTALL="$HOME/.bun"
export OPENCV_ROOT="$HOME/repos/config/opencv-3.2.0"
export CAFFE_ROOT="$HOME/repos/config/caffe"
export ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs"

if [[ -d /opt/homebrew/opt/llvm ]]; then
    export LDFLAGS="-L/opt/homebrew/opt/llvm/lib -L/opt/homebrew/opt/llvm/lib/unwind -lunwind"
    export CPPFLAGS="-I/opt/homebrew/opt/llvm/include"
fi

if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if [[ -r "$HOME/.cargo/env" ]]; then
    source "$HOME/.cargo/env"
fi

if [[ -r "$HOME/.secrets" ]]; then
    source "$HOME/.secrets"
fi

typeset -U path PATH
path=(
    "$HOME/.local/bin"
    "$HOME/.bun/bin"
    "$HOME/.cargo/bin"
    "$HOME/.nimble/bin"
    "$HOME/repos/Nim/bin"
    "$HOME/repos/Odin"
    "$HOME/repos/zls/zig-out/bin"
    "$HOME/repos/nimlangserver"
    "$HOME/repos/nimlsp/build"
    "$HOME/repos/atlas/src"
    "$HOME/repos/sgit/build"
    "/opt/homebrew/opt/llvm/bin"
    "/nix/var/nix/profiles/default/bin"
    $path
)
