local M = {}

-- Default configuration values
M.defaults = {
    -- Marker strings used to delimit editing regions
    markers = {
        edit_start = "<!--INKA_EDIT_START-->",
        answer_start = "<!--INKA_ANSWER_START-->", 
        edit_end = "<!--INKA_EDIT_END-->",
    },
    -- Visual indicators for editing mode
    visual = {
        statusline_text = "INKA EDIT MODE",
        highlight_group = "InkaEditMode",
        line_highlight = "InkaEditLine",
    },
    -- Debug mode
    debug = false,
}

-- Current active configuration
M.config = {}

function M.setup(user_config)
    M.config = vim.tbl_deep_extend("force", M.defaults, user_config or {})
    
    if M.config.debug then
        print("inka-nvim: Configuration loaded")
        print(vim.inspect(M.config))
    end
    
    return M.config
end

function M.get()
    -- If config is empty (setup not called), return defaults
    if not next(M.config) then
        return M.defaults
    end
    return M.config
end

function M.get_markers()
    return M.config.markers or M.defaults.markers
end

function M.get_visual()
    return M.config.visual or M.defaults.visual
end

function M.is_debug()
    return M.config.debug or M.defaults.debug
end

return M