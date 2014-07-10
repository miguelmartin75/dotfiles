#!/bin/bash
for file in $(find ./tilda -name "*")
do
    # if we hit an actual directory
    if [ -d $file ]; then
        continue # then continue
    fi

    from=~/${file#"./tilda/"} 
    to=$file

    echo "copying" $from "to" $to "..."

    cp $from $to 
done
