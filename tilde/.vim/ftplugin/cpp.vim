" syntastic
let g:syntastic_cpp_compiler = 'clang++'
let g:syntastic_cpp_compiler_options = '-std=c++11 -stdlib=libc++'

let g:ycm_global_ycm_extra_conf ='~/.vim/ftplugin/.ycm_extra_conf.py'
"set mps+=<:> " for templates