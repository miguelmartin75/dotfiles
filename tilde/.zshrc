
default=$(tput sgr0)
red=$(tput setaf 1)
green=$(tput setaf 2)
purple=$(tput setaf 5)
orange=$(tput setaf 9)

export MANPAGER=less
export LESS_TERMCAP_mb=$red
export LESS_TERMCAP_md=$orange
export LESS_TERMCAP_me=$default
export LESS_TERMCAP_se=$default
export LESS_TERMCAP_so=$purple
export LESS_TERMCAP_ue=$default
export LESS_TERMCAP_us=$green

export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="minimal"

# Example aliases
# alias zshconfig="vim ~/.zshrc"
# Uncomment the following line to disable bi-weekly auto-update checks.
DISABLE_AUTO_UPDATE="true"

# plugins for zsh
source $ZSH/oh-my-zsh.sh


# fzf
[[ -f ~/.fzf.zsh ]] && source ~/.fzf.zsh

# Editor & nvim
export EDITOR=nvim
export NVIM_LOG_FILE="/tmp/.nvimlog"

# Programming: nvm (node)
export NVM_DIR="/Users/miguel/.nvm"
function load_nvm() {
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm
}

# Programming: C/C++ 

function dcmake() { mkdir -p "${1:-build}"; (cd "${1:-build}" && cmake "$@" ..) }
function dccmake() { mkdir -p "${1:-build}"; (cd "${1:-build}" && ccmake "$@" ..) }
alias dmake='make -C ${1:-build}'
function format() { find ${1:-src} -name "*.cpp" -or -name "*.h" | xargs clang-format -i -style=file }

# FFMPEG aliases
function duration() {
    ffprobe -i $1 2>&1 | grep Duration | awk '{print $2}' | sed 's/,//'
}

function duration_no_awk() {
    ffprobe -i $1 2>&1 | grep Duration
}

function count_packets() {
    ffprobe -v error -select_streams v:0 -count_packets -show_entries stream=nb_read_packets -of csv=p=0 $1
}

function count_frames() {
    ffprobe -v error -select_streams v:0 -count_frames -show_entries stream=nb_read_frames -of csv=p=0 $1
}

function show_frames() {
    ffprobe -v error -i $1 -show_frames -show_entries frame=pkt_pts_time -of csv=p=0
}

function extract_frames() {
    file=$1
    out=$2
    ffmpeg -i $file -vsync 0 ${out}/%d.png
}

function show_metadata_audio() {
    ffprobe -i $1 -show_frames -select_streams v:0 -print_format json
}

function save_metadata_audio() {
    file=$1
    no_ext="${1%.*}"

    show_metadata $file | head -n 500 > ${no_ext}.json
}

function show_metadata() {
    ffprobe -i $1 -show_frames -select_streams v:0 -print_format json
}

function save_metadata() {
    file=$1
    no_ext="${1%.*}"

    show_metadata $file | head -n 500 > ${no_ext}.json
}

function save_all_metadata() {
    file=$1
    no_ext="${1%.*}"

    show_metadata $file > ${no_ext}.json
}


function get_rotation() {
    ffprobe -show_streams $1 2>&1 | grep rotate
}

# Programming: Nim
export PATH="/Users/miguelmartin/repos/Nim/bin:$PATH"

# Programming: CONDA
function load_conda() {
    # >>> conda initialize >>>
    # !! Contents within this block are managed by 'conda init' !!
    __conda_setup="$('/usr/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
    if [ $? -eq 0 ]; then
        eval "$__conda_setup"
    else
        if [ -f "/usr/etc/profile.d/conda.sh" ]; then
            . "/usr/etc/profile.d/conda.sh"
        else
            export PATH="/usr/bin:$PATH"
        fi
    fi
    unset __conda_setup
    # <<< conda initialize <<<
}

# ---- WORK
[[ -f /usr/facebook/ops/rc/master.zshrc ]] && source /usr/facebook/ops/rc/master.zshrc
[[ -z "$LOCAL_ADMIN_SCRIPTS" ]] && export LOCAL_ADMIN_SCRIPTS='/usr/facebook/ops/rc'
[[ -f "$LOCAL_ADMIN_SCRIPTS/master.zshrc" ]] && source "${LOCAL_ADMIN_SCRIPTS}/master.zshrc"

# WORK LAPTOP
if [[ -d  /Users/miguelmartin/homebrew/ ]]; then
    export OPENSSL_ROOT_DIR=/Users/miguelmartin/homebrew/Cellar/openssl@3
    export DYLD_LIBRARY_PATH=/Users/miguelmartin/homebrew/lib/
    export LD_LIBRARY_PATH="/Users/miguelmartin/homebrew/lib/:$LD_LIBRARY_PATH"
fi

function remove_uncommited_files() {
    rm $(hg status | awk '{print $2}')
}

alias with-proxy="HTTPS_PROXY=http://fwdproxy:8080 HTTP_PROXY=http://fwdproxy:8080 FTP_PROXY=http://fwdproxy:8080 https_proxy=http://fwdproxy:8080 http_proxy=http://fwdproxy:8080 ftp_proxy=http://fwdproxy:8080 http_no_proxy='\''*.facebook.com|*.tfbnw.net|*.fb.com'\'"

# >>> fb-conda initialize >>>
# This is a managed block. Any changes to this block WILL BE WIPED.
#
# This file manages your aliases and shims conda and micromamba, if you have them.
if test -f /etc/fbconda/fbconda.sh; then
    source /etc/fbconda/fbconda.sh
fi

# <<< fb-conda initialize <<<
