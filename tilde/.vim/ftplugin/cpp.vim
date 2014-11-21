" syntastic
let g:syntastic_cpp_compiler = 'c++'
let g:syntastic_cpp_compiler_options = '-std=c++11 -stdlib=libc++'

let g:ycm_global_ycm_extra_conf ='~/.vim/ftplugin/.ycm_extra_conf.py'
set mps+=<:> " for templates

map <F2> :call SwitchSourceHeader()<CR>
map <F3> :sp<F2>

if exists('*SwitchSourceHeader')
    finish
endif

function! SwitchSourceHeader()
    if(expand("%:e") == "cpp")
        find %:t:r.hpp
    else
        find %:t:r.cpp
    endif
endfunction
