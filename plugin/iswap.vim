lua require("iswap").init()

" Use the setup() function instead
" highlight default link ISwapSnipe Search
" highlight default link ISwapGrey Comment

command ISwap lua require('iswap').iswap()
command ISwapWith lua require('iswap').iswap_with()
command ISwapNode lua require('iswap').iswap_node()
command ISwapNodeWith lua require('iswap').iswap_node_with()
command ISwapNodeWithRight lua require('iswap').iswap_node_with('right')
command ISwapNodeWithLeft lua require('iswap').iswap_node_with('left')

" <Plug>ISwap will delay because it becomes <Plug>ISwapWith prefix sequence.
" Use <Plug>ISwapNormal instead and etc for others
nnoremap <Plug>ISwapNormal <Cmd>lua require('iswap').iswap()<CR>
nnoremap <Plug>ISwapWith <Cmd>lua require('iswap').iswap_with()<CR>
nnoremap <Plug>ISwapNodeNormal <Cmd>lua require('iswap').iswap_node()<CR>
nnoremap <Plug>ISwapNodeWithNormal <Cmd>lua require('iswap').iswap_node_with()<CR>
nnoremap <Plug>ISwapNodeWithRight <Cmd>lua require('iswap').iswap_node_with('right')<CR>
nnoremap <Plug>ISwapNodeWithLeft <Cmd>lua require('iswap').iswap_node_with('left')<CR>
