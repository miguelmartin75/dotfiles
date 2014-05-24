# ----------------------------
# Settings

# Path to your oh-my-zsh installation.
export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="minimal"

# Example aliases
# alias zshconfig="vim ~/.zshrc"
# Uncomment the following line to disable bi-weekly auto-update checks.
DISABLE_AUTO_UPDATE="true"

# ---------------------------
# Plugins for zsh

# (oh-my-zsh) plug-ins
#plugins

source $ZSH/oh-my-zsh.sh

# -------------------------
# Exports

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/git/bin"

# Preferred editor for local and remote sessions
EDITOR='vim'

# Compilation flags
export ARCHFLAGS="-arch x86_64"

# -------------------------
# aliases

# vim
alias vim="/usr/local/bin/vim"
alias v=vim
alias vi=vim
alias e=vim

# gcc
alias gcc="gcc-4.9"
alias g++="g++-4.9"
alias clang="/usr/local/opt/llvm/bin/clang"
alias clang++="/usr/local/opt/llvm/bin/clang++"
alias aclang="/usr/bin/clang"
alias aclang++="/usr/bin/clang++"
