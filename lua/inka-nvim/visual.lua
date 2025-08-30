local M = {}
local config = require('inka-nvim.config')

-- Buffer-local state for tracking editing mode
local EDITING_MODE_VAR = "inka_nvim_editing_mode"
local ORIGINAL_STATUSLINE_VAR = "inka_nvim_original_statusline"

local function debug_log(msg)
    if config.is_debug() then
        print("inka-nvim [visual]: " .. msg)
    end
end

-- Set up highlight groups
local function setup_highlights()
    local visual_config = config.get_visual()
    
    -- Main editing mode highlight (for statusline)
    vim.api.nvim_set_hl(0, "InkaEditMode", { 
        fg = "#ff6b6b", 
        bg = "#2d2d2d", 
        bold = true 
    })
    
    -- Line highlight for editing region (optional)
    vim.api.nvim_set_hl(0, "InkaEditLine", { 
        bg = "#3c3836", 
        italic = true 
    })
end

-- Get current editing mode state for buffer
function M.is_editing_mode_active(bufnr)
    bufnr = bufnr or 0
    return vim.b[bufnr][EDITING_MODE_VAR] == true
end

-- Enable visual editing mode indicators
function M.enable_editing_mode(bufnr, win)
    bufnr = bufnr or 0
    win = win or 0
    local visual_config = config.get_visual()
    
    debug_log("Enabling visual editing mode for buffer " .. bufnr)
    
    -- Mark buffer as being in editing mode
    vim.b[bufnr][EDITING_MODE_VAR] = true
    
    -- Save original statusline if we're going to modify it
    local original_statusline = vim.wo[win].statusline
    vim.b[bufnr][ORIGINAL_STATUSLINE_VAR] = original_statusline
    
    -- Create editing mode statusline with save protection indicator
    local editing_statusline = string.format(
        "%%#InkaEditMode# %s [SAVE DISABLED] %%* %%f%%m%%r%%h%%w %%=%%l,%%c %%P",
        visual_config.statusline_text
    )
    
    -- Set the statusline for the current window
    vim.wo[win].statusline = editing_statusline
    
    -- Trigger statusline refresh
    vim.cmd("redrawstatus")
    
    debug_log("Visual editing mode enabled")
end

-- Disable visual editing mode indicators
function M.disable_editing_mode(bufnr, win)
    bufnr = bufnr or 0
    win = win or 0
    
    debug_log("Disabling visual editing mode for buffer " .. bufnr)
    
    -- Clear editing mode flag
    vim.b[bufnr][EDITING_MODE_VAR] = false
    
    -- Restore original statusline
    local original_statusline = vim.b[bufnr][ORIGINAL_STATUSLINE_VAR]
    if original_statusline then
        vim.wo[win].statusline = original_statusline
        vim.b[bufnr][ORIGINAL_STATUSLINE_VAR] = nil
    else
        -- Reset to default statusline
        vim.wo[win].statusline = ""
    end
    
    -- Simple statusline refresh (treesitter errors should be handled in markers.lua)
    pcall(vim.cmd, "redrawstatus")
    
    debug_log("Visual editing mode disabled")
end

-- Set up autocommands for visual mode management
local function setup_autocommands()
    -- Create augroup for inka-nvim visual indicators
    local augroup = vim.api.nvim_create_augroup("InkaNvimVisual", { clear = true })
    
    -- Prevent buffer saves during inka editing mode
    vim.api.nvim_create_autocmd({"BufWritePre", "FileWritePre"}, {
        group = augroup,
        pattern = "*.md",
        callback = function(args)
            local bufnr = args.buf
            if M.is_editing_mode_active(bufnr) then
                -- Prevent save and show informative message
                vim.notify(
                    "❌ Cannot save while in inka editing mode.\n" ..
                    "Use :InkaSave to exit editing mode first, then save.",
                    vim.log.levels.WARN,
                    { title = "inka-nvim" }
                )
                -- Prevent the save operation
                return true
            end
        end,
    })
    
    -- Clean up visual state when buffer is deleted
    vim.api.nvim_create_autocmd("BufDelete", {
        group = augroup,
        callback = function(args)
            local bufnr = args.buf
            if M.is_editing_mode_active(bufnr) then
                debug_log("Cleaning up visual state for deleted buffer " .. bufnr)
                vim.b[bufnr][EDITING_MODE_VAR] = nil
                vim.b[bufnr][ORIGINAL_STATUSLINE_VAR] = nil
            end
        end,
    })
    
    -- Update statusline when switching windows/buffers
    vim.api.nvim_create_autocmd({"WinEnter", "BufEnter"}, {
        group = augroup,
        pattern = "*.md",
        callback = function(args)
            local bufnr = args.buf
            local win = vim.api.nvim_get_current_win()
            
            -- If this buffer is in editing mode, make sure statusline reflects it
            if M.is_editing_mode_active(bufnr) then
                M.enable_editing_mode(bufnr, win)
            end
        end,
    })
end

-- Get statusline component for editing mode (for custom statuslines)
function M.get_statusline_component()
    local bufnr = vim.api.nvim_get_current_buf()
    if M.is_editing_mode_active(bufnr) then
        local visual_config = config.get().visual
        return string.format("%%#InkaEditMode# %s [SAVE DISABLED] %%*", visual_config.statusline_text)
    end
    return ""
end

-- Check if any buffer is currently in editing mode (for global status)
function M.has_active_editing_mode()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(bufnr) and M.is_editing_mode_active(bufnr) then
            return true, bufnr
        end
    end
    return false
end

-- Setup function called by main init
function M.setup(user_config)
    debug_log("Setting up visual indicators")
    
    setup_highlights()
    setup_autocommands()
    
    debug_log("Visual indicators setup complete")
end

-- Toggle editing mode visual indicators (for testing/debugging)
function M.toggle_editing_mode(bufnr, win)
    bufnr = bufnr or 0
    win = win or 0
    
    if M.is_editing_mode_active(bufnr) then
        M.disable_editing_mode(bufnr, win)
        return false
    else
        M.enable_editing_mode(bufnr, win)
        return true
    end
end

return M