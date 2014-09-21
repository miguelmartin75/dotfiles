#!/bin/bash

source variables.sh

for file in $(find $DOTFILES_DIR -name "*")
do
    # if we hit an actual directory
    if [ -d $file ]; then
        continue # then continue
    fi

    from=~/${file#"${DOTFILES_DIR}/"}
    to=$file

    echo "copying" $from "to" $to "..."

    cp $from $to 
done
