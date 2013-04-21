let s:bufname = '__SYMFIND__'
let s:sp = "------------------------------------------"
let s:help = ['f xxx - find file xxx', 's xxx - find symbol xxx']

"===== toolkit {{{
let s:match = []
function! s:mymatch(expr, pat)
	let s:match = matchlist(a:expr, a:pat)
	return len(s:match) >0
endf
"}}}

func! s:openSymfind(exname)
	let instno = 0
	let bufname = s:bufname . a:exname
	let defcmd = 'f'
	if s:mymatch(a:exname, '\v:(\d+)$')
		let instno = s:match[1] +0
	endif
	if a:exname[0] == 'f' || a:exname[0] == 's'
		let defcmd = a:exname[0]
	endif

	let wnr = bufwinnr(bufname)
	let bexists = bufexists(bufname)
	if wnr != -1
		exe wnr . 'wincmd w'
	else
		exe 'new ' . bufname
		let b:preview = 0
	endif
	if !bexists
		let b:sf_instno = instno
		setl buftype=nofile
		setl noswapfile
		setl hidden
		setl nowrap
		setl cursorline
" 		setl winfixheight
" 		setl winfixwidth
		call setline(1, defcmd . ' ')
		call setline(2, s:sp)
		call setline(3, s:help)
		call s:setSyntax()
	endif
	inoremap <silent> <buffer> <cr> <c-o>:call SF_call()<cr>
	nnoremap <silent> <buffer> <cr> :call SF_go('')<cr>
	nnoremap <silent> <buffer> <s-cr> :call SF_go(1)<cr>
	nmap <silent> <buffer> <2-leftmouse> <cr>
	nnoremap <silent> <buffer> <esc> :hide<cr>
	nmap <silent> <buffer> q <esc>
	1
	starti!
endfunc

func! SF_call()
	if line('.') > 2
		call SF_go('')
	endif
	let s = getline(1)
	let cmd = 'symsvr.pl -c "' . s . '"'
	if exists('b:sf_instno') && b:sf_instno != 0
		let cmd .= ' :' . b:sf_instno
	endif
	let rv = split(system(cmd), "\n")

	call setline(2, s:sp)
	silent! 3,$d
	call setline(3, rv)
	1
	starti!
endf

func! SF_go(splitwnd)
	if line('.') <= 2
		return
	endif
	let ls = split(getline('.'), "\t")
	if len(ls) < 3
		return
	endif
	let f = ls[-1] . '/' . ls[-2]
	if a:splitwnd || b:preview
		let b:preview = 1
		wincmd H
		vert res 40
		exe (winnr()+1) . 'wincmd w'
	endif
	let cmd = 'e ' . substitute(f, '\v(.+):(\d+)$', '+\2 \1', 0)
"	call confirm(cmd)
	exec cmd
endf

command! -nargs=? Symfind :call s:openSymfind(<q-args>)
" symfind
nmap <leader>sf :Symfind<cr>
" find file
" nmap <leader>ff :Symfind f<cr>
" find symbol
" nmap <leader>fs :Symfind s<cr>

func! s:setSyntax ()
	" sfLineNr	sfKind	sfKeyword	sfExtra	sfFile	sfFolder
	" sfLineNr	sfFile	sfFolder
	syn match sfLineNr /^\v\d+:/ nextgroup=sfKind,sfFile
	syn match sfKind /\t[a-z]\>/ contained nextgroup=sfKeyword
	syn match sfKeyword /\t[^\t]\+/ contained nextgroup=sfExtra
	syn match sfExtra /\t[^\t]*/ contained nextgroup=sfFile
	syn match sfFile /\v\t[^\t]{2,}/ contained nextgroup=sfFolder
	syn match sfFolder /\t\S*[/\\]\S*/ contained

	hi link sfLineNr LineNr
	hi link sfKind Type
	hi link sfKeyword Identifier
	hi link sfExtra Special
	hi link sfFile Macro
	hi link sfFolder Special
endf

" TODO
func! SF_complete()
endf

