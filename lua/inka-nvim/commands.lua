local M = {}
local config = require('inka-nvim.config')
local markers = require('inka-nvim.markers')
local visual = require('inka-nvim.visual')

local function debug_log(msg)
    if config.is_debug() then
        print("inka-nvim [commands]: " .. msg)
    end
end

-- InkaEdit command implementation
local function inka_edit_command()
    local bufnr = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()
    local cursor_line = vim.api.nvim_win_get_cursor(win)[1]
    
    debug_log("InkaEdit command called at line " .. cursor_line)
    
    -- Check if file is markdown
    local filetype = vim.bo[bufnr].filetype
    if filetype ~= "markdown" then
        vim.notify("InkaEdit can only be used in markdown files", vim.log.levels.ERROR)
        return
    end
    
    -- Check if already in editing mode
    if markers.is_in_editing_mode(bufnr) then
        vim.notify("Already in inka editing mode. Use :InkaSave to exit.", vim.log.levels.WARN)
        return
    end
    
    -- Start editing mode
    local success, error_msg = markers.start_editing_mode(bufnr, cursor_line)
    if not success then
        vim.notify("Failed to enter inka editing mode: " .. (error_msg or "unknown error"), vim.log.levels.ERROR)
        return
    end
    
    -- Enable visual indicators
    visual.enable_editing_mode(bufnr, win)
    
    vim.notify("Entered inka editing mode. Use :InkaSave to restore answer markers.", vim.log.levels.INFO)
    debug_log("InkaEdit command completed successfully")
end

-- InkaSave command implementation
local function inka_save_command()
    local bufnr = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()
    
    debug_log("InkaSave command called")
    
    -- Check if in editing mode
    if not markers.is_in_editing_mode(bufnr) then
        vim.notify("Not currently in inka editing mode. Use :InkaEdit to enter editing mode.", vim.log.levels.WARN)
        return
    end
    
    -- End editing mode
    local success, error_msg = markers.end_editing_mode(bufnr)
    if not success then
        vim.notify("Failed to exit inka editing mode: " .. (error_msg or "unknown error"), vim.log.levels.ERROR)
        return
    end
    
    -- Disable visual indicators
    visual.disable_editing_mode(bufnr, win)
    
    vim.notify("Exited inka editing mode. Answer markers restored.", vim.log.levels.INFO)
    debug_log("InkaSave command completed successfully")
end

-- InkaStatus command implementation (for debugging)
local function inka_status_command()
    local bufnr = vim.api.nvim_get_current_buf()
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    
    print("=== Inka-nvim Status ===")
    print("Current buffer: " .. bufnr)
    print("Current line: " .. cursor_line)
    print("File type: " .. vim.bo[bufnr].filetype)
    print("In editing mode: " .. tostring(markers.is_in_editing_mode(bufnr)))
    print("Visual mode active: " .. tostring(visual.is_editing_mode_active(bufnr)))
    
    -- Try to detect card bounds at cursor
    local detection = require('inka-nvim.detection')
    local in_inka_section = detection.is_in_inka_section(bufnr, cursor_line)
    print("In inka2 section: " .. tostring(in_inka_section))
    
    if in_inka_section then
        local card_bounds, err = detection.find_card_bounds(bufnr, cursor_line)
        if card_bounds then
            print("Card bounds found:")
            print("  Start line: " .. card_bounds.start_line)
            print("  Question line: " .. card_bounds.question_line)
            print("  Answer start: " .. tostring(card_bounds.answer_start_line))
            print("  End line: " .. card_bounds.end_line)
        else
            print("Card bounds error: " .. (err or "unknown"))
        end
    end
    
    -- Check for editing region
    local region = markers.find_editing_region(bufnr)
    if region then
        print("Editing region found:")
        print("  Edit start: " .. region.edit_start_line)
        print("  Answer start: " .. tostring(region.answer_start_line))
        print("  Edit end: " .. region.edit_end_line)
    end
    
    print("Config debug mode: " .. tostring(config.is_debug()))
    print("========================")
end

-- Setup function to register commands
function M.setup(user_config)
    debug_log("Setting up commands")
    
    -- Register InkaEdit command
    vim.api.nvim_create_user_command("InkaEdit", inka_edit_command, {
        desc = "Enter inka2 editing mode for the flashcard under cursor",
        nargs = 0,
    })
    
    -- Register InkaSave command
    vim.api.nvim_create_user_command("InkaSave", inka_save_command, {
        desc = "Exit inka2 editing mode and restore answer markers",
        nargs = 0,
    })
    
    -- Register InkaStatus command (for debugging)
    vim.api.nvim_create_user_command("InkaStatus", inka_status_command, {
        desc = "Show inka-nvim status and debug information",
        nargs = 0,
    })
    
    -- Override common save commands during editing mode
    local function create_save_guard(cmd_name, original_cmd)
        vim.api.nvim_create_user_command(cmd_name, function(opts)
            local bufnr = vim.api.nvim_get_current_buf()
            local visual = require('inka-nvim.visual')
            if visual.is_editing_mode_active(bufnr) then
                vim.notify(
                    "❌ Cannot save while in inka editing mode.\n" ..
                    "Use :InkaSave to exit editing mode first, then " .. cmd_name:lower() .. ".",
                    vim.log.levels.WARN,
                    { title = "inka-nvim" }
                )
                return
            end
            -- Execute original command
            vim.cmd(original_cmd .. (opts.args and " " .. opts.args or ""))
        end, {
            desc = "Save command with inka editing mode protection",
            nargs = "*",
            force = true, -- Override existing commands
        })
    end
    
    -- Guard common save commands
    create_save_guard("W", "w")
    create_save_guard("Write", "write")
    create_save_guard("Wall", "wall")
    create_save_guard("Wq", "wq")
    create_save_guard("Wqall", "wqall")
    
    -- Guard normal mode save commands (ZZ, ZQ)
    local function create_normal_mode_guard(key, description)
        vim.keymap.set('n', key, function()
            local bufnr = vim.api.nvim_get_current_buf()
            local visual = require('inka-nvim.visual')
            if visual.is_editing_mode_active(bufnr) then
                vim.notify(
                    "❌ Cannot save while in inka editing mode.\n" ..
                    "Use :InkaSave to exit editing mode first, then " .. key .. ".",
                    vim.log.levels.WARN,
                    { title = "inka-nvim" }
                )
                return
            end
            -- Execute original command
            vim.cmd("normal! " .. key)
        end, { desc = description })
    end
    
    create_normal_mode_guard("ZZ", "Save and quit with inka editing mode protection")
    create_normal_mode_guard("ZQ", "Quit without save with inka editing mode protection")
    
    debug_log("Commands registered successfully")
end

-- Expose command functions for testing
M.inka_edit = inka_edit_command
M.inka_save = inka_save_command
M.inka_status = inka_status_command

return M