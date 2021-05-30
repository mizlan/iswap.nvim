local queries = require "nvim-treesitter.query"

local M = {}

function M.init()
  require "nvim-treesitter".define_modules {
    iargs = {
      module_path = "iargs.internal",
      is_supported = function(lang)
        -- TODO: you don't want your queries to be named `awesome-query`, do you ?
        return queries.get_query(lang, 'awesome-query') ~= nil
      end
    }
  }
end

return M
