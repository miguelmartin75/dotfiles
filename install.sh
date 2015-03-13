#!/bin/bash

# vim-plug for vim
if [ ! -f ~/.vim/autoload/plug.vim ]; then
    echo 'installing plug.vim'

    # install plug.vim
    mkdir -p ~/.vim/autoload
    curl -L https://raw.github.com/junegunn/vim-plug/master/plug.vim > ~/.vim/autoload/plug.vim
fi

# if we're on a mac...
if [ $(uname) == "Darwin" ]; then
    # run the osx script
    echo "running ./osx setup script" 
    ./osx
fi

./install_dotfiles.sh ./tilde

# run vim and install the plugins for us
vim -c "PlugInstall|qa"
