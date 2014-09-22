let s:bufname = '__SYMFIND__'
let s:sp = "------------------------------------------"
let s:help = ['f xxx - find file xxx', 's xxx - find symbol xxx', 'g xxx - grep pattern xxx' ]
let s:exname = ''

"===== toolkit {{{
let s:match = []
function! s:mymatch(expr, pat)
	let s:match = matchlist(a:expr, a:pat)
	return len(s:match) >0
endf
"}}}

func! s:openSymfind(exname)
	let instno = 0
	if a:exname != ''
		let s:exname = a:exname
	endif
	let bufname = s:bufname . s:exname
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
		setl nonumber
" 		setl winfixheight
" 		setl winfixwidth
		call setline(1, defcmd . ' ')
		call setline(2, s:sp)
		call setline(3, s:help)
		call s:setSyntax()
	endif
	inoremap <silent> <buffer> <cr> <c-o>:call SF_call('')<cr>
	nnoremap <silent> <buffer> <cr> :call SF_go('')<cr>
	nnoremap <silent> <buffer> <s-cr> :call SF_go(1)<cr>
	nnoremap <silent> <buffer> s<cr> :call SF_go(1)<cr>
	nmap <silent> <buffer> <2-leftmouse> <cr>
	nnoremap <silent> <buffer> q :hide<cr>
	nnoremap <silent> <buffer> <c-w>H :call SF_setPreview(1)<cr>
	1
	starti!
endfunc

func! SF_setPreview(force)
	if !a:force && exists('b:preview') && b:preview
		return
	endif
	let b:preview = 1
	wincmd H
	vert res 40
endf

func! SF_call(cmd)
	if a:cmd != ''
		call s:openSymfind('')
		1
		call setline(1, a:cmd)
	endif

	if line('.') > 2
		call SF_go('')
		return
	endif
	let s = getline(1)
	if s:mymatch(s, '^\v(\d+)\w')
		let b:sf_ses = s:match[1]
	elseif exists('b:sf_ses')
		let s = b:sf_ses . s
	endif
	let cmd = 'symsvr.pl -c "' . s . '"'
	if exists('b:sf_instno') && b:sf_instno != 0
		let cmd .= ' :' . b:sf_instno
	endif
	let rv = split(system(cmd), "\n")

	call setline(2, s:sp)
	silent! 3,$d
	call setline(3, rv)
	if s =~ '\v^g\s+'
		exec "!" . rv[0] . "|tee 1.out"
		if winnr('$') != 1
			q
		endif
		lgetfile 1.out
		lopen
		stopi
	else
		" in symfind window
		1
		starti!
	endif
endf

func! SF_go(splitwnd)
	if line('.') <= 2
		return
	endif
	let ls = split(getline('.'), "\t")
	if ls[0] !~ '^\d\+:'
		return
	endif
	let f = ls[-1] . '/' . ls[-2]
	if f =~ '\s'
		" process space
		let f = substitute(f, '\s', '\\\0', 'g')
	endif
	if a:splitwnd || b:preview
		call SF_setPreview(0)
		exe (winnr()+1) . 'wincmd w'
	endif
	let cmd = 'e ' . substitute(f, '\v(.+):(\d+)$', '+\2 \1', '')
"	call confirm(cmd)
	exec cmd
	foldopen!
endf

command! -nargs=? Symfind :call s:openSymfind(<q-args>)
" symfind
nmap <leader>sf :Symfind<cr>
nmap <leader>1sf :Symfind :1<cr>
nmap <leader><c-]> :exe "call SF_call('s <c-r><c-w>')"<cr>
vmap <leader><c-]> y:exe "call SF_call('s <c-r>0')"<cr>
nmap <leader>gf :exe "call SF_call('f <c-r><c-f>')"<cr>
vmap <leader>gf y:exe "call SF_call('f <c-r>0')"<cr>
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
"	hi link sfFolder Special
endf

" TODO
func! SF_complete()
endf

