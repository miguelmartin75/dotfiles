# ===== General =====

export PATH="/usr/local/cuda/bin:/home/media/config/mxe/usr/bin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/git/bin:/usr/texbin:/usr/local/bin/depot_tools"

# Preferred editor for local and remote sessions
export EDITOR=vim

# Compilation flags
export ARCHFLAGS="-arch x86_64"

# -------------------------
# aliases

alias vim2='vim -c "set shiftwidth=2"'

function dcmake() { mkdir -p "${1:-build}"; (cd "${1:-build}" && cmake "$@" ..) }
function dccmake() { mkdir -p "${1:-build}"; (cd "${1:-build}" && ccmake "$@" ..) }
alias dmake='make -C ${1:-build}'

function format() { find ${1:-src} -name "*.cpp" -or -name "*.h" | xargs clang-format -i -style=file }

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

export NVM_DIR="/Users/miguel/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

export CUDA_HOME="/usr/local/cuda"
export LD_LIBRARY_PATH="/usr/local/cuda/lib64:/usr/local/lib:$LD_LIBRARY_PATH"

{
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/miguel
} > /dev/null 2>&1

export OPENCV_ROOT="$HOME/repos/config/opencv-3.2.0"
export CAFFE_ROOT="$HOME/repos/config/caffe"
export PYTHONPATH="./:${CAFFE_ROOT}/python:$PYTHONPATH"

export WIKI_FILES_DIR="$HOME/wiki/wiki"
function wikigoto() {
    cd $WIKI_FILES_DIR
}

function wikiedit() {
    wikigoto && $EDITOR
}

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

