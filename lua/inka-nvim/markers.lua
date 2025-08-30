local M = {}
local config = require('inka-nvim.config')
local detection = require('inka-nvim.detection')

local function debug_log(msg)
    if config.is_debug() then
        print("inka-nvim [markers]: " .. msg)
    end
end

-- Check if buffer is currently in editing mode by looking for markers
function M.is_in_editing_mode(bufnr)
    bufnr = bufnr or 0
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local markers = config.get_markers()
    
    for _, line in ipairs(lines) do
        if line:find(markers.edit_start, 1, true) then
            return true
        end
    end
    
    return false
end

-- Find the editing region bounds by looking for markers
function M.find_editing_region(bufnr)
    bufnr = bufnr or 0
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local markers = config.get_markers()
    
    local edit_start = nil
    local answer_start = nil
    local edit_end = nil
    
    for i, line in ipairs(lines) do
        if line:find(markers.edit_start, 1, true) then
            edit_start = i
        elseif line:find(markers.answer_start, 1, true) then
            answer_start = i
        elseif line:find(markers.edit_end, 1, true) then
            edit_end = i
            break
        end
    end
    
    if edit_start and edit_end then
        return {
            edit_start_line = edit_start,
            answer_start_line = answer_start,
            edit_end_line = edit_end,
        }
    end
    
    return nil
end

-- Insert markers around a card to enable editing mode
function M.insert_markers(bufnr, card_bounds)
    bufnr = bufnr or 0
    local markers = config.get_markers()
    
    debug_log("Inserting markers around card")
    debug_log("Card bounds: " .. vim.inspect(card_bounds))
    
    -- Insert markers from bottom to top to preserve line numbers
    local lines_to_insert = {}
    
    -- Insert end marker after the card
    table.insert(lines_to_insert, {
        line = card_bounds.end_line + 1,
        text = markers.edit_end
    })
    
    -- Insert answer start marker if we have answers
    if card_bounds.answer_start_line then
        table.insert(lines_to_insert, {
            line = card_bounds.answer_start_line,
            text = markers.answer_start
        })
    end
    
    -- Insert start marker before the card  
    table.insert(lines_to_insert, {
        line = card_bounds.start_line,
        text = markers.edit_start
    })
    
    -- Sort by line number descending to insert from bottom to top
    table.sort(lines_to_insert, function(a, b) return a.line > b.line end)
    
    for _, insert_info in ipairs(lines_to_insert) do
        vim.api.nvim_buf_set_lines(bufnr, insert_info.line - 1, insert_info.line - 1, false, {insert_info.text})
        debug_log("Inserted marker at line " .. insert_info.line .. ": " .. insert_info.text)
    end
    
    return true
end

-- Remove all editing markers from the buffer
function M.remove_markers(bufnr)
    bufnr = bufnr or 0
    local markers = config.get_markers()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local lines_to_remove = {}
    
    -- Find all marker lines (iterate backwards to maintain line numbers)
    for i = #lines, 1, -1 do
        local line = lines[i]
        if line:find(markers.edit_start, 1, true) or
           line:find(markers.answer_start, 1, true) or
           line:find(markers.edit_end, 1, true) then
            table.insert(lines_to_remove, i)
            debug_log("Will remove marker at line " .. i .. ": " .. line)
        end
    end
    
    -- Remove lines (already sorted in descending order)
    for _, line_num in ipairs(lines_to_remove) do
        vim.api.nvim_buf_set_lines(bufnr, line_num - 1, line_num, false, {})
        debug_log("Removed marker at line " .. line_num)
    end
    
    return #lines_to_remove > 0
end

-- Remove answer prefixes ("> ") from lines between answer_start and edit_end markers
function M.remove_answer_prefixes(bufnr)
    bufnr = bufnr or 0
    local region = M.find_editing_region(bufnr)
    if not region or not region.answer_start_line then
        debug_log("No answer region found for prefix removal")
        return false
    end
    
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local modified_lines = {}
    
    debug_log("Removing answer prefixes between lines " .. region.answer_start_line .. " and " .. region.edit_end_line)
    
    for i = region.answer_start_line + 1, region.edit_end_line - 1 do
        local line = lines[i]
        -- Pattern to match ">" with optional single space after (inka2 format)
        -- This removes the ">" and at most one space to preserve markdown formatting
        local prefix_pattern = "^%s*>%s?"
        
        if line:match(prefix_pattern) then
            -- Handle removal of ">" prefix with optional single space:
            -- "> content" -> "content"  
            -- "> " -> ""
            -- ">" -> ""
            local new_line = line:gsub(prefix_pattern, "", 1)
            -- If the result is only whitespace (common for empty answer lines), make it truly empty
            if new_line:match("^%s*$") then
                new_line = ""
            end
            lines[i] = new_line
            table.insert(modified_lines, i)
            debug_log("Removed prefix from line " .. i .. ": '" .. line .. "' -> '" .. new_line .. "'")
        end
    end
    
    if #modified_lines > 0 then
        -- Disable treesitter highlighting temporarily to prevent column errors
        local ts_was_active = vim.treesitter.highlighter.active[bufnr] ~= nil
        if ts_was_active then
            pcall(vim.treesitter.stop, bufnr)
        end
        
        -- Apply buffer changes
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        
        -- Re-enable treesitter highlighting with fresh state
        if ts_was_active then
            vim.schedule(function()
                pcall(vim.treesitter.start, bufnr, 'markdown')
            end)
        end
        
        debug_log("Modified " .. #modified_lines .. " lines")
    end
    
    return #modified_lines > 0
end

-- Add answer prefixes ("> ") to ALL lines between answer_start and edit_end markers
function M.add_answer_prefixes(bufnr)
    bufnr = bufnr or 0
    local region = M.find_editing_region(bufnr)
    if not region or not region.answer_start_line then
        debug_log("No answer region found for prefix addition")
        return false
    end
    
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local modified_lines = {}
    
    debug_log("Adding answer prefixes between lines " .. region.answer_start_line .. " and " .. region.edit_end_line)
    
    for i = region.answer_start_line + 1, region.edit_end_line - 1 do
        local line = lines[i]
        -- Only add prefix if line doesn't already have one (avoid double-prefixing)
        local prefix_pattern = "^%s*>%s?"
        
        if not line:match(prefix_pattern) then
            -- Add "> " to lines without prefix (inka2 format requires this)
            -- Empty lines become "> " and content lines become "> content"
            local new_line = "> " .. line
            lines[i] = new_line
            table.insert(modified_lines, i)
            debug_log("Added prefix to line " .. i .. ": '" .. line .. "' -> '" .. new_line .. "'")
        else
            debug_log("Skipped line " .. i .. " (already has prefix): '" .. line .. "'")
        end
    end
    
    if #modified_lines > 0 then
        -- Disable treesitter highlighting temporarily to prevent column errors
        local ts_was_active = vim.treesitter.highlighter.active[bufnr] ~= nil
        if ts_was_active then
            pcall(vim.treesitter.stop, bufnr)
        end
        
        -- Apply buffer changes
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        
        -- Re-enable treesitter highlighting with fresh state
        if ts_was_active then
            vim.schedule(function()
                pcall(vim.treesitter.start, bufnr, 'markdown')
            end)
        end
        
        debug_log("Modified " .. #modified_lines .. " lines")
    end
    
    return #modified_lines > 0
end

-- Main function to enter editing mode
function M.start_editing_mode(bufnr, cursor_line)
    bufnr = bufnr or 0
    cursor_line = cursor_line or vim.api.nvim_win_get_cursor(0)[1]
    
    debug_log("Starting editing mode at line " .. cursor_line)
    
    -- Check if already in editing mode
    if M.is_in_editing_mode(bufnr) then
        return false, "Already in inka editing mode"
    end
    
    -- Find card boundaries
    local card_bounds, err = detection.find_card_bounds(bufnr, cursor_line)
    if not card_bounds then
        return false, err or "Could not detect card boundaries"
    end
    
    -- Insert markers
    if not M.insert_markers(bufnr, card_bounds) then
        return false, "Failed to insert markers"
    end
    
    -- Remove answer prefixes
    M.remove_answer_prefixes(bufnr)
    
    debug_log("Successfully started editing mode")
    return true
end

-- Main function to exit editing mode
function M.end_editing_mode(bufnr)
    bufnr = bufnr or 0
    
    debug_log("Ending editing mode")
    
    -- Check if in editing mode
    if not M.is_in_editing_mode(bufnr) then
        return false, "Not currently in inka editing mode"
    end
    
    -- Add answer prefixes back
    M.add_answer_prefixes(bufnr)
    
    -- Remove markers
    if not M.remove_markers(bufnr) then
        return false, "Failed to remove markers"
    end
    
    debug_log("Successfully ended editing mode")
    return true
end

return M