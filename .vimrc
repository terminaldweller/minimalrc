let mapleader = " "
syntax on
colo wildcharm
set background=dark
set nocompatible
set nomodeline
set modelines=0
set number
set relativenumber
set magic
set wildmenu
set list
set title
set showmatch
set hidden
set smarttab
set autoindent
set wildignorecase
set hlsearch
set incsearch
set ignorecase
set smartcase
set noerrorbells
set novisualbell
set dictionary+=/usr/share/dict/words
set backspace=indent,eol,start
set pastetoggle=<F11>
set tabstop=2
set shiftwidth=2
set expandtab
nnoremap <F7> :Vexplore<CR>
nnoremap <leader>nn :bn<CR>
nnoremap <leader>pp :bp<CR>
map <C-e> :q<cr>
nnoremap <F10> :vsp<cr>
nnoremap <S-F10> :sp<cr>
map <leader>w :w<CR>
nmap Y y$
vmap Y y$
nnoremap <S-Delete> :bd<CR>
nnoremap <leader>c :call clearmatches()<CR>
inoremap <c-i> <esc>I
inoremap <c-e> <esc>A
nnoremap <leader>t :bel term<CR>
nnoremap <leader>r :!%:p<CR>
nnoremap <leader>rl :.w !bash<CR>
set pastetoggle=<F11>
cnoremap <C-a> <Home>
cnoremap <C-e> <End>
nmap <leader>m :make<CR>

set laststatus=2
function! InsertStatuslineColor(mode)
  if a:mode == 'i'
    hi statusline ctermfg=22 ctermbg=15 guibg=#005f00 guifg=#ffffff
  elseif a:mode == 'r'
    hi statusline ctermfg=52 ctermbg=15 guibg=#5f0000 guifg=#ffffff
  else
    hi statusline ctermfg=25 ctermbg=63 guibg=#005faf guifg=#5f5fff
  endif
endfunction

au InsertEnter * call InsertStatuslineColor(v:insertmode)
au InsertLeave * hi statusline ctermfg=24 ctermbg=15 guibg=#005f87 guifg=#ffffff
hi statusline ctermfg=24 ctermbg=15 guibg=#005f87 guifg=#ffffff
hi statuslineNC ctermfg=0 ctermbg=24 term=bold guifg=#000000 guibg=#005f87
set statusline=[%f]                             "file name
set statusline+=[%{strlen(&fenc)?&fenc:'none'}, "file encoding
set statusline+=%{&ff}] "file format
set statusline+=%y      "filetype
set statusline+=%h      "help file flag
set statusline+=%m      "modified flag
set statusline+=\ %=                        " align left
set statusline+=Line:%l/%L[%p%%]            " line X of Y [percent of file]
set statusline+=\ Col:%c                    " current column
set statusline+=\ Buf:%n                    " Buffer number
set statusline+=\ [%b][0x%B]\               " ASCII and byte code under cursor

set fillchars+=vert:\ " whitespace signifacant
hi VertSplit ctermbg=0 ctermfg=0 guibg=#000000 guifg=#000000

" highlight groups
hi def InterestingWord1 ctermfg=16 ctermbg=214 guifg=#000000 guibg=#ffaf00
hi def InterestingWord2 ctermfg=16 ctermbg=154 guifg=#000000 guibg=#afff00
hi def InterestingWord3 ctermfg=16 ctermbg=121 guifg=#000000 guibg=#87ffaf
hi def InterestingWord4 ctermfg=16 ctermbg=137 guifg=#000000 guibg=#af875f
hi def InterestingWord5 ctermfg=16 ctermbg=211 guifg=#000000 guibg=#ff87af
hi def InterestingWord6 ctermfg=16 ctermbg=195 guifg=#000000 guibg=#d7ffff
hi def InterestingWord7 ctermfg=16 ctermbg=99 guifg=#000000 guibg=#875fff
hi def InterestingWord8 ctermfg=16 ctermbg=35 guifg=#000000 guibg=#00af5f
hi def InterestingWord9 ctermfg=16 ctermbg=57 guifg=#000000 guibg=#5f00ff
hi def InterestingWord0 ctermfg=16 ctermbg=39 guifg=#000000 guibg=#00afff

"Steve Losh's highlight function
function HighInterestingWord(n)
  normal! mz
  normal! "zyiw
  let mid = 88888 + a:n
  silent! call matchdelete(mid)
  let pat = '\V\<' . escape(@z, '\') . '\>'
  call matchadd("InterestingWord".a:n, pat, 1, mid)
  normal! `z
endfunction

"multiple highlights
nnoremap <silent> <leader>1 :call HighInterestingWord(1)<cr>
nnoremap <silent> <leader>2 :call HighInterestingWord(2)<cr>
nnoremap <silent> <leader>3 :call HighInterestingWord(3)<cr>
nnoremap <silent> <leader>4 :call HighInterestingWord(4)<cr>
nnoremap <silent> <leader>5 :call HighInterestingWord(5)<cr>
nnoremap <silent> <leader>6 :call HighInterestingWord(6)<cr>
nnoremap <silent> <leader>7 :call HighInterestingWord(7)<cr>
nnoremap <silent> <leader>8 :call HighInterestingWord(8)<cr>
nnoremap <silent> <leader>9 :call HighInterestingWord(9)<cr>
nnoremap <silent> <leader>0 :call HighInterestingWord(0)<cr>
"typos
iab adn and
iab teh the
iab strign string
iab pritn print
iab retrun return
iab fucntion function
iab funciton function
iab tehn then
iab coutn count
iab accoutn account
iab applciation application
iab cosnt const
iab ehco echo

"netrw
let g:netrw_sort_by = 'date'
let g:netrw_sort_direction = 'reverse'
let g:netrw_banner = 0
let g:netrw_liststyle = 3
let g:netrw_browse_split = 4
let g:netrw_winsize = 15
let g:netrw_fastbrowse = 1
let g:netrw_sort_by = 'name'
let g:netrw_sort_direction = 'normal'

inoremap " ""<left>
inoremap ' ''<left>
inoremap ` ``<left>
inoremap ( ()<left>
inoremap [ []<left>
inoremap { {}<left>
inoremap {<CR> {<CR>}<ESC>O
inoremap {;<CR> {<CR>};<ESC>O

let g:camelchar = "A-Z0-9.,;:{([`'\"_"
nnoremap <silent><C-h> :<C-u>call search('\C\<\<Bar>\%(^\<Bar>[^'.g:camelchar.']\@<=\)['.g:camelchar.']\<Bar>['.g:camelchar.']\ze\%([^'.g:camelchar.']\&\>\@!\)\<Bar>\%^','bW')<CR>
nnoremap <silent><C-l> :<C-u>call search('\C\<\<Bar>\%(^\<Bar>[^'.g:camelchar.']\@<=\)['.g:camelchar.']\<Bar>['.g:camelchar.']\ze\%([^'.g:camelchar.']\&\>\@!\)\<Bar>\%$','W')<CR>
inoremap <silent><C-h> <C-o>:call search('\C\<\<Bar>\%(^\<Bar>[^'.g:camelchar.']\@<=\)['.g:camelchar.']\<Bar>['.g:camelchar.']\ze\%([^'.g:camelchar.']\&\>\@!\)\<Bar>\%^','bW')<CR>
inoremap <silent><C-l> <C-o>:call search('\C\<\<Bar>\%(^\<Bar>[^'.g:camelchar.']\@<=\)['.g:camelchar.']\<Bar>['.g:camelchar.']\ze\%([^'.g:camelchar.']\&\>\@!\)\<Bar>\%$','W')<CR>
vnoremap <silent><C-h> :<C-U>call search('\C\<\<Bar>\%(^\<Bar>[^'.g:camelchar.']\@<=\)['.g:camelchar.']\<Bar>['.g:camelchar.']\ze\%([^'.g:camelchar.']\&\>\@!\)\<Bar>\%^','bW')<CR>v`>o
vnoremap <silent><C-l> <Esc>`>:<C-U>call search('\C\<\<Bar>\%(^\<Bar>[^'.g:camelchar.']\@<=\)['.g:camelchar.']\<Bar>['.g:camelchar.']\ze\%([^'.g:camelchar.']\&\>\@!\)\<Bar>\%$','W')<CR>v`<o

if bufwinnr(1)
  nnoremap <right> <c-w>>
  nnoremap <left> <c-w><
  nnoremap <up> <c-w>-
  nnoremap <down> <c-w>+
endif

"copy and paste between different Vim instances
nmap _Y :!echo ""> ~/.vi_tmp<CR><CR>:w! ~/.vi_tmp<CR>
vmap _Y :w! ~/.vi_tmp<CR>
nmap _P :r ~/.vi_tmp<CR>

vnoremap <silent> * :<C-u>call VisualSelection('', '')<CR>/<C-R>=@/<CR><CR>
vnoremap <silent> # :<C-u>call VisualSelection('', '')<CR>?<C-R>=@/<CR><CR>

if has("gui")
  " set guifont=DejaVu_Sans_Mono_for_Powerline:h10
  set guioptions-=m
  set guioptions-=T
  set guioptions-=L
  set guioptions-=r
endif
set secure

nmap ,s :call SwitchSourceHeader()<CR>

" standard cscope settings switches from ctags to cscope.
if has("cscope")
	set csprg=/usr/bin/cscope
	set csto=0
	set cscopequickfix=s-,c-,d-,i-,t-,e-,a-
 "  set csqf
	set cst
	set nocsverb
	" add any database in current directory
	if filereadable("cscope.out")
			cs add cscope.out
	" else add database pointed to by environment
	elseif $CSCOPE_DB != ""
			cs add $CSCOPE_DB
	endif
	set csverb
endif

"   " The following maps all invoke one of the following cscope search types:
"   's'   symbol: find all references to the token under cursor
"   'g'   global: find global definition(s) of the token under cursor
"   'c'   calls:  find all calls to the function name under cursor
"   't'   text:   find all instances of the text under cursor
"   'e'   egrep:  egrep search for the word under cursor
"   'f'   file:   open the filename under cursor
"   'i'   includes: find files that include the filename under cursor
"   'd'   called: find functions that function under cursor calls
nnoremap <silent> <C-@>s :lcs find s <C-R>=expand("<cword>")<cr><cr><bar>:lopen<cr><bar>:wincmd p<cr>
nnoremap <silent> <C-@>g :cs find g <C-R>=expand("<cword>")<CR><CR>
nnoremap <silent> <C-@>d :lcs find d <C-R>=expand("<cword>")<cr><cr><bar>:lopen<cr>
nnoremap <silent> <C-@>c :lcs find c <C-R>=expand("<cword>")<cr><cr><bar>:lopen<cr><bar>:wincmd p<cr>
nnoremap <silent> <C-@>t :lcs find t <C-R>=expand("<cword>")<cr><cr><bar>:lopen<cr><bar>:wincmd p<cr>
nnoremap <silent> <C-@>e :lcs find e <C-R>=expand("<cword>")<cr><cr><bar>:lopen<cr><bar>:wincmd p<cr>
nnoremap <silent> <C-@>f :cs find i <C-R>=expand("<cfile>")<CR><CR>
nnoremap <silent> <C-@>i :lcs find i <C-R>=expand("<cword>")<cr><cr><bar>:lopen<cr><bar>:wincmd p<cr>
nnoremap <silent> <C-@>a :lcs find a <C-R>=expand("<cword>")<cr><cr><bar>:lopen<cr><bar>:wincmd p<cr>

"below is for finding where function decl is  used
map g<C-]> :cs find c <C-R>=expand("<cword>")<CR><CR>
"below is for finding where a definition is used
map g<C-\> :cs find s <C-R>=expand("<cword>")<CR><CR>
"ctrl-] and g] now both takes us to the definition.

if executable('rg')
		set grepprg=rg\ --vimgrep\ --no-hidden\ --no-heading\ --smart-case
		set grepformat=%f:%l:%c:%m,%f:%l:%m
endif

augroup gzip
 autocmd!
 autocmd BufReadPre,FileReadPre *.gz set bin
 autocmd BufReadPost,FileReadPost   *.gz '[,']!gunzip
 autocmd BufReadPost,FileReadPost   *.gz set nobin
 autocmd BufReadPost,FileReadPost   *.gz execute ":doautocmd BufReadPost " . expand("%:r")
 autocmd BufWritePost,FileWritePost *.gz !mv <afile> <afile>:r
 autocmd BufWritePost,FileWritePost *.gz !gzip <afile>:r
 autocmd FileAppendPre      *.gz !gunzip <afile>
 autocmd FileAppendPre      *.gz !mv <afile>:r <afile>
 autocmd FileAppendPost     *.gz !mv <afile> <afile>:r
 autocmd FileAppendPost     *.gz !gzip <afile>:r
augroup END
