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

        # if the directory doesn't exist
        if [ ! -d $to ]; then 
            mkdir $to # then make the directory 
        fi

        continue # then continue to the next dir
    fi

    echo "Installing" $to

    cp $from $to 
done
