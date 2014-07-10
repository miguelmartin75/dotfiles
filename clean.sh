#!/bin/bash
for file in $(find ./tilda -name "*")
do
    # if we hit an actual directory
    if [ -d $file ]; then
        continue # then continue
    fi

    fileToRemove=~/${file#"./tilda/"} 
    echo "removing" $fileToRemove
    rm $fileToRemove
done
