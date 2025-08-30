local M = {}
local config = require('inka-nvim.config')

-- Patterns for detecting different parts of inka2 cards
local PATTERNS = {
    inka_section_start = "^%-%-%-$",  -- Start of inka2 section
    inka_section_end = "^%-%-%-$",    -- End of inka2 section  
    id_comment = "^%s*<!%-%-ID:(%d+)%-%->[^>]*$",  -- <!--ID:123-->
    numbered_question = "^%s*(%d+)%.%s+(.*)$",     -- 1. Question text
    answer_line = "^%s*>%s*(.*)$",                 -- > Answer text
    empty_line = "^%s*$",                          -- Empty line
}

local function debug_log(msg)
    if config.is_debug() then
        print("inka-nvim [detection]: " .. msg)
    end
end

function M.is_in_inka_section(bufnr, lnum)
    bufnr = bufnr or 0
    lnum = lnum or vim.api.nvim_win_get_cursor(0)[1]
    
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local in_section = false
    
    for i, line in ipairs(lines) do
        if line:match(PATTERNS.inka_section_start) then
            in_section = true
        elseif line:match(PATTERNS.inka_section_end) and in_section and i > 1 then
            in_section = false
        end
        
        if i == lnum and in_section then
            return true
        end
    end
    
    return false
end

function M.find_card_bounds(bufnr, cursor_line)
    bufnr = bufnr or 0
    cursor_line = cursor_line or vim.api.nvim_win_get_cursor(0)[1]
    
    debug_log("Finding card bounds from line " .. cursor_line)
    
    if not M.is_in_inka_section(bufnr, cursor_line) then
        debug_log("Cursor not in inka2 section")
        return nil, "Cursor is not within an inka2 section (between --- markers)"
    end
    
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local card_start = nil
    local question_line = nil
    local answer_start = nil
    local card_end = nil
    
    -- First, find which numbered question we're in by scanning upward
    for i = cursor_line, 1, -1 do
        local line = lines[i]
        
        -- Check if this is a numbered question
        local question_num, question_text = line:match(PATTERNS.numbered_question)
        if question_num then
            question_line = i
            break
        end
        
        -- Stop if we hit another card's answer or section boundary
        if line:match(PATTERNS.inka_section_start) and i < cursor_line then
            break
        end
    end
    
    if not question_line then
        debug_log("No numbered question found above cursor")
        return nil, "Could not find a numbered question above cursor position"
    end
    
    debug_log("Found question at line " .. question_line)
    
    -- Look for optional ID comment above the question
    card_start = question_line
    if question_line > 1 then
        local prev_line = lines[question_line - 1]
        if prev_line:match(PATTERNS.id_comment) then
            card_start = question_line - 1
            debug_log("Found ID comment at line " .. card_start)
        end
    end
    
    -- Find where answers start (first > line after question)
    answer_start = nil
    for i = question_line + 1, #lines do
        local line = lines[i]
        
        if line:match(PATTERNS.answer_line) then
            answer_start = i
            debug_log("Found answer start at line " .. answer_start)
            break
        end
        
        -- If we hit another question or section end, answers might not exist yet
        if line:match(PATTERNS.numbered_question) or 
           line:match(PATTERNS.inka_section_end) then
            break
        end
    end
    
    -- Find card end (next question, section end, or empty line after answer)
    card_end = #lines
    local found_answer = false
    
    for i = question_line + 1, #lines do
        local line = lines[i]
        
        -- Track if we've found answers
        if line:match(PATTERNS.answer_line) then
            found_answer = true
        end
        
        -- End at next numbered question
        local next_question_num = line:match(PATTERNS.numbered_question)
        if next_question_num then
            card_end = i - 1
            debug_log("Card ends before next question at line " .. i)
            break
        end
        
        -- End at next ID comment (start of next card)
        if line:match(PATTERNS.id_comment) then
            card_end = i - 1
            debug_log("Card ends before next ID at line " .. i)
            break
        end
        
        -- End at section boundary
        if line:match(PATTERNS.inka_section_end) then
            card_end = i - 1
            debug_log("Card ends at section end line " .. i)
            break
        end
        
        -- Only end at empty line if we've found answers (avoid cutting off cards with empty lines before answers)
        if line:match(PATTERNS.empty_line) and found_answer then
            -- Look ahead to see if there are more answer lines or if this is truly the end
            local has_more_answers = false
            for j = i + 1, math.min(i + 3, #lines) do -- Look ahead up to 3 lines
                if lines[j]:match(PATTERNS.answer_line) then
                    has_more_answers = true
                    break
                elseif not lines[j]:match(PATTERNS.empty_line) then
                    -- Non-empty, non-answer line - stop looking
                    break
                end
            end
            
            if not has_more_answers then
                card_end = i - 1
                debug_log("Card ends at empty line " .. i .. " (after answers)")
                break
            end
        end
    end
    
    -- Ensure card_end is not before question_line
    if card_end < question_line then
        card_end = question_line
    end
    
    local card_bounds = {
        start_line = card_start,
        question_line = question_line,
        answer_start_line = answer_start,
        end_line = card_end,
    }
    
    debug_log("Card bounds: " .. vim.inspect(card_bounds))
    return card_bounds
end

function M.find_answer_lines(bufnr, card_bounds)
    if not card_bounds.answer_start_line then
        debug_log("No answer start line found")
        return {}
    end
    
    bufnr = bufnr or 0
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local answer_lines = {}
    
    for i = card_bounds.answer_start_line, card_bounds.end_line do
        local line = lines[i]
        if line:match(PATTERNS.answer_line) then
            table.insert(answer_lines, i)
        end
    end
    
    debug_log("Found " .. #answer_lines .. " answer lines")
    return answer_lines
end

function M.get_patterns()
    return PATTERNS
end

return M