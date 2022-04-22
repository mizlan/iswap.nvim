lua require("iswap").init()

" Use the setup() function instead
" highlight default link ISwapSnipe Search
" highlight default link ISwapGrey Comment

command ISwap lua require('iswap').iswap()
command ISwapNode lua require('iswap').iswap_node()
command ISwapWith lua require('iswap').iswap_with()

" <Plug>ISwap will delay because it become <Plug>ISwapWith prefix sequences.
" Use <Plug>ISwapNormal instead
nnoremap <Plug>ISwapNormal <Cmd>lua require('iswap').iswap()<CR>
nnoremap <Plug>ISwapWith <Cmd>lua require('iswap').iswap_with()<CR>
