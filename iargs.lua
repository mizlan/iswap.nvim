local queries = require "nvim-treesitter.query"

local M = {}

function M.init()
  require "nvim-treesitter".define_modules {
    iargs = {
      module_path = "iargs.internal",
      is_supported = function(lang)
        return queries.get_query(lang, 'iargs-list') ~= nil
      end
    }
  }
end

return M
