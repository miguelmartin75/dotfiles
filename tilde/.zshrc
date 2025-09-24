# ===== General =====

export PATH="/usr/local/cuda/bin:/home/media/config/mxe/usr/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/git/bin:/usr/texbin:/usr/local/bin/depot_tools"

# Preferred editor for local and remote sessions
# export GIT_EDITOR="/opt/homebrew/bin/emacsclient"
export GIT_EDITOR="nvim"
# export EDITOR="/opt/homebrew/bin/emacsclient"
export EDITOR="nvim"
export HISTSIZE=100000000

# -----------------
# Misc

# Colors
default=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
purple=$(tput setaf 5)
orange=$(tput setaf 9)

# Less colors for man pages
export MANPAGER=less
# Begin blinking
export LESS_TERMCAP_mb=$red
# Begin bold
export LESS_TERMCAP_md=$orange
# End mode
export LESS_TERMCAP_me=$default
# End standout-mode
export LESS_TERMCAP_se=$default
# Begin standout-mode - info box
export LESS_TERMCAP_so=$purple
# End underline
export LESS_TERMCAP_ue=$default
# Begin underline
export LESS_TERMCAP_us=$green

# ----------------------------
# oh-my-zsh specifics

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="minimal"

# Example aliases
# alias zshconfig="vim ~/.zshrc"
# Uncomment the following line to disable bi-weekly auto-update checks.
DISABLE_AUTO_UPDATE="true"

# plugins for zsh
source $ZSH/oh-my-zsh.sh

# export CUDA_HOME="/usr/local/cuda"
# export LD_LIBRARY_PATH="/usr/local/cuda/lib64:/usr/local/lib:$LD_LIBRARY_PATH"

{
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/miguel
} > /dev/null 2>&1

export OPENCV_ROOT="$HOME/repos/config/opencv-3.2.0"
export CAFFE_ROOT="$HOME/repos/config/caffe"
# export PYTHONPATH="./:${CAFFE_ROOT}/python:$PYTHONPATH"

if [ -f "$HOME/.cargo/env" ]; then
    source "$HOME/.cargo/env"
fi


# export CPLUS_INCLUDE_PATH="${CPLUS_INCLUDE_PATH:+${CPLUS_INCLUDE_PATH}:}/usr/local/include"
# export PATH=$HOME/.nimble/bin:/usr/local/opt/llvm/bin:/usr/local/cuda/bin:/home/media/config/mxe/usr/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/git/bin:/usr/texbin:/usr/local/bin/depot_tools:/usr/local/opt/fzf/bin

# export FZF_DEFAULT_COMMAND='fd --type f'
# lldb_path=$(lldb --python-path)
# export PYTHONPATH="$lldb_path:$PYTHONPATH"

# export PYTHONPATH="/Applications/Xcode.app/Contents/SharedFrameworks/LLDB.framework/Resources/Python:$PYTHONPATH"
# export PATH="/usr/local/opt/llvm@16/bin:$PATH"
# export PATH="$HOME/repos/nim_playground/Nim/bin:$PATH"

# export LDFLAGS="-L/usr/local/opt/llvm/lib"
# export CPPFLAGS="-I/usr/local/opt/llvm/include"
# export LLVM_DIR="/usr/local/opt/llvm"

function load_nvm() {
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
}

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
function load_conda() {
    __conda_setup="$('/opt/homebrew/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "" ]; then
            . "/opt/homebrew/anaconda3/etc/profile.d/conda.sh"
        else
            export PATH="/opt/homebrew/anaconda3/bin/conda:$PATH"
        fi
    fi
    unset __conda_setup
    # <<< conda initialize <<<
}

# Shopify Hydrogen alias to local projects
alias h2='$(npm prefix -s)/node_modules/.bin/shopify hydrogen'

# . "$HOME/.cargo/env"
# export PATH=$HOME/.cargo/bin:$PATH

# bun completions
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
eval "$(/usr/libexec/path_helper)"

# . "$HOME/.local/bin/env"
# export PATH="$HOME/Library/Python/3.9/bin:$PATH"
# export PATH="$HOME/software/orca/:$PATH"

source ~/.secrets
export PATH="$HOME/repos/zls/zig-out/bin:$PATH"
export PATH="$HOME/repos/nimlangserver:$HOME/repos/nimlsp/build:$HOME/repos/atlas/src:$HOME/.nimble/bin/$PATH"
export PATH="$HOME/.local/bin:$PATH"


# languages
# nim
export PATH="$HOME/repos/Nim/bin:$PATH"
# export PATH="$HOME/repos/Nim-dev/bin:$PATH"
export PATH="$HOME/.nimble/bin:$PATH"

# rust
export PATH="$HOME/.cargo/bin:$PATH"

# odin
export PATH="$HOME/repos/Odin:$PATH"

# export LDFLAGS="-L/usr/local/opt/openblas/lib"
# export CPPFLAGS="-I/usr/local/opt/openblas/include"
# export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
# export LLVM_PATH="/usr/local/opt/llvm/"
# export LLVM_VERSION="20"
# export LD_LIBRARY_PATH="$LLVM_PATH/lib/:$LD_LIBRARY_PATH"
# export DYLD_LIBRARY_PATH="$LLVM_PATH/lib/:$DYLD_LIBRARY_PATH"
# export CPATH="$LLVM_PATH/lib/clang/$LLVM_VERSION/include/"
# export LDFLAGS="-L$LLVM_PATH/lib"
# export CPPFLAGS="-I$LLVM_PATH/include"
# export CC="$LLVM_PATH/bin/clang"
# export CXX="$LLVM_PATH/bin/clang++"
# export PATH="$LLVM_PATH/bin:$PATH"

eval "$(/opt/homebrew/bin/brew shellenv)"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
source <(fzf --zsh)

export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
export LDFLAGS="-L/opt/homebrew/opt/llvm/lib"
export CPPFLAGS="-I/opt/homebrew/opt/llvm/include"

export LDFLAGS="-L/opt/homebrew/opt/llvm/lib/unwind -lunwind"

# add nix
export PATH="/nix/var/nix/profiles/default/bin:$PATH"

# export EMACS_SOCKET_NAME=
export ICLOUD_DIR="$HOME/Library/Mobile Documents/com~apple~CloudDocs"
