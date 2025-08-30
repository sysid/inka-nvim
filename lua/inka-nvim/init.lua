local M = {}
local config = require('inka-nvim.config')

M.version = '0.2.0'

function M.setup(user_config)
    -- Setup configuration first
    config.setup(user_config or {})
    
    -- Load and setup commands
    require('inka-nvim.commands').setup()
    
    -- Initialize visual indicators module
    require('inka-nvim.visual').setup()
    
    return M
end

function M.get_config()
    return config.get()
end

return M