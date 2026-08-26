# Interactive Zsh configuration

HISTFILE="$HOME/.zsh_history"
HISTSIZE=1000000000
SAVEHIST=$HISTSIZE

setopt SHARE_HISTORY
setopt EXTENDED_HISTORY
setopt HIST_FCNTL_LOCK

unsetopt INC_APPEND_HISTORY
unsetopt INC_APPEND_HISTORY_TIME

export VIRTUAL_ENV_DISABLE_PROMPT=1

# Man-page colors
export MANPAGER=less

if [[ -t 1 && -n ${TERM:-} && $TERM != dumb ]] && (( $+commands[tput] )); then
    if man_reset="$(tput sgr0 2>/dev/null)"; then
        man_red="$(tput setaf 1 2>/dev/null)"
        man_green="$(tput setaf 2 2>/dev/null)"
        man_purple="$(tput setaf 5 2>/dev/null)"
        man_orange="$(tput setaf 9 2>/dev/null)"

        export LESS_TERMCAP_mb="$man_red"
        export LESS_TERMCAP_md="$man_orange"
        export LESS_TERMCAP_me="$man_reset"
        export LESS_TERMCAP_se="$man_reset"
        export LESS_TERMCAP_so="$man_purple"
        export LESS_TERMCAP_ue="$man_reset"
        export LESS_TERMCAP_us="$man_green"
    fi
fi

# Native Zsh completion
typeset -U fpath
if [[ -r "$HOME/.bun/_bun" ]]; then
    fpath=("$HOME/.bun" $fpath)
fi

autoload -Uz compinit
compinit

zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}'
bindkey '^I' complete-word

autoload -Uz add-zsh-hook

set_prompt() {
    local venv=none
    local result

    if [[ -n ${VIRTUAL_ENV:-} ]]; then
        venv=${VIRTUAL_ENV:h:t}
    fi

    result=$'\n'
    result+="$(date '+[%m/%d] %H:%M:%S - %s'), venv: $venv"
    result+=$'\nNode: %n@%m'
    result+=$'\nCluster: Laptop'
    result+=$'\n%~'
    result+=$'\n%(!.#.$) '
    PROMPT=$result
}

add-zsh-hook precmd set_prompt

gl() {
    git log --graph --pretty=format:'%C(yellow)%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ad) %C(bold blue)<%an>%Creset' -- "$@"
}

clone-bare() {
    git clone "$1" --bare .bare
    print -r -- "gitdir: ./.bare" > .git
    git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"
}

alias cursor-cli='NO_COLOR=1 cursor-agent'

load_nvm() {
    export NVM_DIR="$HOME/.nvm"
    if [[ -r "$NVM_DIR/nvm.sh" ]]; then
        source "$NVM_DIR/nvm.sh"
    else
        print -u2 -- "load_nvm: $NVM_DIR/nvm.sh is unavailable"
        return 1
    fi
}

load_conda() {
    local conda_command
    local conda_setup

    if (( $+commands[conda] )); then
        conda_command=$commands[conda]
    elif [[ -x /opt/homebrew/anaconda3/bin/conda ]]; then
        conda_command=/opt/homebrew/anaconda3/bin/conda
    else
        print -u2 -- "load_conda: conda is unavailable"
        return 1
    fi

    if conda_setup="$("$conda_command" shell.zsh hook 2>/dev/null)"; then
        eval "$conda_setup"
    else
        print -u2 -- "load_conda: failed to initialize conda"
        return 1
    fi
}

h2() {
    "$(npm prefix -s)/node_modules/.bin/shopify" hydrogen "$@"
}

if [[ -r "$HOME/.fzf.zsh" ]]; then
    source "$HOME/.fzf.zsh"
elif (( $+commands[fzf] )); then
    if fzf_setup="$(fzf --zsh 2>/dev/null)"; then
        source <(print -r -- "$fzf_setup")
    fi
    unset fzf_setup
fi
