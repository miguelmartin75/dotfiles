# vimrc

These are my vimrc files.

# Installation

Installation is quite simple and easy.

If you don't have vundle installed, then:

```bash
bash ./install.sh
```

If you do, then:

```bash
bash ./install_vimrc.sh
```

or

```bash
cp ./vimrc ~/.vimrc
```

Now you have to install the bundles with Vundle, which you can do by opening vim and typing:

```
:BundleInstall
```

That should automagically install all the appropriate bundles for you.

# Bundles that require compliation

There are some bundles that require compilation, which are:

## YouCompleteMe

On Mac, you install by going:

```bash
cd ~/.vim/bundles/YouCompleteMe
./install.sh --clang-completer
```

Please see the readme of YouCompleteMe to learn how to install on your OS.

# License
Copyright (C) 2013 Miguel Martin (miguel.martin7.5@hotmail.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
