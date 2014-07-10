# dotfiles

All my personal dot files.

# Prerequisites

Some of my `*rc` files require some pre-reqs. Here are the prerequisites:

- Vundle
	- Vundle is required to be installed for my vimrc. Please note that you must type `:BundleInstall`, after you have install Vundle.

All of these prerequisites should be install automagically for you, via the `./install.sh` script.

# Installation

Now that you have prerequsites install, the installation of the dotfiles are quite simple! The `tilda` directory mimmics `~`. So you can just copy the contents of `tilda` to `~`, or alternatively just use the `./install.sh` script. This script will copy the directory `tilda` to `~`.

# Updating Self

To update this repository, for your current dotfiles on your local machine. Simply run the script `self_update.sh`.

# NOTE

All scripts should be run from the root repository directory. e.g.

```bash
./self_update.sh
```

# License
Copyright (C) 2014 Miguel Martin (miguel@miguel-martin.com)

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
