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
# aliases

VIM_PATH="/usr/local/"

# if we're on Mac...
if [[ "$(uname)" == "Darwin" ]]; then
    VIM_PATH="/usr/local/bin/"

    # gcc
    alias gcc="gcc-4.9"
    alias g++="g++-4.9"
    alias clang="/usr/local/opt/llvm/bin/clang"
    alias clang++="/usr/local/opt/llvm/bin/clang++"
    alias aclang="/usr/bin/clang"
    alias aclang++="/usr/bin/clang++"
elif [[ "$(expr substr $(uname -s) 1 5)" == "Linux" ]]; then
    # linux specific aliases...
    alias c++="clang++"
fi

VIM=$VIM_PATH"vim"
alias vim=$VIM
alias v=vim
alias vi=vim
alias e=vim

VIMDIFF=$VIM_PATH"vimdiff"
alias vimdiff=$VIMDIFF
alias vdiff=vimdiff

# -------------------------
# Exports

export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/usr/local/git/bin"

# Preferred editor for local and remote sessions
export EDITOR=$VIM

# Compilation flags
export ARCHFLAGS="-arch x86_64"

#export MANPAGER=vim
# Colors
default=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
purple=$(tput setaf 5)
orange=$(tput setaf 9)

# Less colors for man pages
export PAGER=less
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
source /Users/miguel/.iterm2_shell_integration.zsh
