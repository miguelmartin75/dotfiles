#!/bin/bash

if [ "${1}x" == "x" ]; then
    echo "please give me a directory full of dotfiles to install..."
    exit 1
fi

DOTFILES_DIR=$1

# NOTE I could use -type f to only copy files,
# however, I'm not sure sure how to create the necessary
# directories with the cp command if it doesn't exist...
for file in $(find $DOTFILES_DIR -name "*")
do
    # ignore the base dir
    if [ $file == "./tilde" ]; then
        continue;
    fi

    readablePath=${file#"${DOTFILES_DIR}/"}
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

