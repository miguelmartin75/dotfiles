#!/bin/bash
if [ ! -d ~/.vim/bundle ]; then
    echo 'installing Vundle'

    # install Vundle
    git clone https://github.com/gmarik/vundle.git ~/.vim/bundle/vundle
fi

for file in $(find ./tilda -name "*")
do
    readablePath=${file#"./tilda/"}
    to=~/$readablePath
    from=$file

    # if we hit an actual directory
    if [ -d $file ]; then
        mkdir $to # make the directory (just incase it doesn't exist)
        continue # then continue
    fi

    echo "Installing" $to

    cp $from $to 
done
