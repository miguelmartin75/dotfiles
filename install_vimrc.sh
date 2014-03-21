#!/bin/bash

echo 'copying ./vimrc to ~/.vimrc'

# copy the vim file
cp ./vimrc ~/.vimrc

echo 'succesfully copied ./vimrc to ~/.vimrc'
echo 'note: you require to :BundleInstall once you first open VIM'
