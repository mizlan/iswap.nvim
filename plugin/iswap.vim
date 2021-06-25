lua require("iswap").init()

" Use the setup() function instead
" highlight default link ISwapSnipe Search
" highlight default link ISwapGrey Comment

command ISwap lua require('iswap').iswap()
command ISwapWith lua require('iswap').iswap_with()
