for file in $(find ../tilda -name "*")
do
    # if we hit an actual directory
    if [ -d $file ]; then
        continue # then continue
    fi

    readablePath=${file#"./tilda/"}
    to=~/$readablePath
    from=$file

    shouldInstall="invalid"

    while [[ "$shouldInstall" != "y" && "$shouldInstall" != "n" ]]; do
        echo "Do you wish to install" $readablePath "(y/n)?"
        read shouldInstall
    done

    # if we don't wish to update the file
    if [ "$shouldInstall" == "n" ]; then
        continue
    fi

    echo "copying" $from "to" $to "..."

    cp $from $to 
done
