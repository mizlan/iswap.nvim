# iswap.nvim

Interactively select and swap: function arguments, list elements, function
parameters, and more. Powered by tree-sitter.

![iswap demo](./assets/better_demo.gif)

## installation

For vim-plug:

```vim
Plug 'mizlan/iswap.nvim'
```

## usage

Run the command `:ISwap` when your cursor is in a location that is suitable for
swapping around things. These include lists/arrays, function arguments, and
parameters in function definitions. Then, hit two keys corresponding to the
items you wish to be swapped. After both keys are hit, the text should
immediately swap in the buffer. See the gif above for example usage.

Use `:ISwapWith` if you want to have the element your cursor is over
automatically as one of the elements. This way, you only need one keypress to
make a swap.

## configuration

In your `init.lua`:

```lua
require('iswap').setup{
  -- The keys that will be used as a selection, in order
  -- ('asdfghjklqwertyuiopzxcvbnm' by default)
  keys = 'qwertyuiop',

  -- Grey out the rest of the text when making a selection
  -- (enabled by default)
  grey = 'disable',

  -- Highlight group for the sniping value (asdf etc.)
  -- default 'Search'
  hl_snipe = 'ErrorMsg',

  -- Highlight group for the visual selection of terms
  -- default 'Visual'
  hl_selection = 'WarningMsg',

  -- Highlight group for the greyed background
  -- default 'Comment'
  hl_grey = 'LineNr',

  -- Highlight priority for the greyed background
  -- default '1000'
  hl_grey_priority = '200',

  -- Automatically swap with only two arguments
  -- default nil
  autoswap = true
}
```

inspired by [hop.nvim](https://github.com/phaazon/hop.nvim) and
[nvim-treesitter-textobjects](https://github.com/nvim-treesitter/nvim-treesitter-textobjects)

## todo

- add angle bracket stuff
- add docs and stuff
