for file in $(find ../tilda -name "*")
do
    # if we hit an actual directory
    if [ -d $file ]; then
        continue # then continue
    fi

    readablePath=${file#"./tilda/"}
    to=~/$readablePath
    from=$file

    echo "Installing" $readablePath

    cp $from $to 
done
