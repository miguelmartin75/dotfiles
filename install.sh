#!/bin/bash

if [ ! -f ~/.vim/autoload/plug.vim ]; then
    echo 'installing plug.vim'

    # install plug.vim
    mkdir -p ~/.vim/autoload
    curl -fLo ~/.vim/autoload/plug.vim \
        https://raw.github.com/junegunn/vim-plug/master/plug.vim
fi

for file in $(find ./tilda -name "*")
do
    # ignore the base dir
    if [ $file == "./tilda" ]; then
        continue;
    fi

    readablePath=${file#"./tilda/"}
    to=~/$readablePath
    from=$file

    # if we hit an actual directory
    if [ -d $file ]; then

        # if the directory doesn't exist
        if [ ! -d $to ]; then 
            mkdir $to # then make the directory 
        fi

        continue # then continue to the next dir
    fi

    echo "Installing" $to

    cp $from $to 
done

# run vim and install the plugins for us
vim -c "PlugInstall|qa"
