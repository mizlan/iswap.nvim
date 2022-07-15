lua require("iswap").init()

" Use the setup() function instead
" highlight default link ISwapSnipe Search
" highlight default link ISwapGrey Comment

command ISwap lua require('iswap').iswap()
command ISwapWith lua require('iswap').iswap_with()

" 1. pick cursor node any parent X, 2. swap picked ancestr X with its sibling
command ISwapNode lua require('iswap').iswap_node()

" 1. Use cursor outer node X, 2. swap X with chosen siblings
command ISwapCursorNode lua require('iswap').iswap_cursor_node()

" Same as ISwapCursorNode but swap with right siblings
command ISwapCursorNodeRight lua require('iswap').iswap_cursor_node(nil, 'right')

" Same as ISwapCursorNode but swap with left siblings
command ISwapCursorNodeLeft lua require('iswap').iswap_cursor_node(nil, 'left')

" <Plug>ISwap will delay because it become <Plug>ISwapWith prefix sequences.
" Use <Plug>ISwapNormal instead
nnoremap <Plug>ISwapNormal <Cmd>lua require('iswap').iswap()<CR>
nnoremap <Plug>ISwapWith <Cmd>lua require('iswap').iswap_with()<CR>
