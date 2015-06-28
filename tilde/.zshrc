# -----------------------
# General

export ANDROID_HOME="/Users/miguel/Library/Android/sdk"

export PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/git/bin:/usr/texbin:/usr/local/bin/depot_tools"
export PATH=${PATH}:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools

# Preferred editor for local and remote sessions
export EDITOR=vim

# Compilation flags
export ARCHFLAGS="-arch x86_64"


# -------------------------
# aliases

# if we're on Mac...
if [[ "$(uname)" == "Darwin" ]]; then
    # gcc
    alias gcc="gcc-4.9"
    alias g++="g++-4.9"

    # regular clang installed by homebrew
    alias clang="/usr/local/opt/llvm/bin/clang"
    alias clang++="/usr/local/opt/llvm/bin/clang++"

    # apple clang, installed by default
    alias aclang="/usr/bin/clang"
    alias aclang++="/usr/bin/clang++"

    # default compiler
    export CC=clang
    export CPP=clang++
    export CXX=clang++
fi

alias prog='cd /Volumes/HDD/Programming'

alias v=vim
alias vi=vim
alias e=vim
alias vdiff=vimdiff

function dcmake() { mkdir -p "${1:-build}"; (cd "${1:-build}" && ccmake "$@" ..) }
alias dmake='make -C ${1:-build}'


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
