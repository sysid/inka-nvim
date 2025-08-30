local M = {}

-- Load a fixture file into a buffer
function M.load_fixture_into_buffer(bufnr, fixture_name)
    local fixture_path = vim.fn.getcwd() .. "/tests/fixtures/" .. fixture_name
    local lines = vim.fn.readfile(fixture_path)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = "markdown"
end

-- Find the first line containing a pattern
function M.find_line_containing(bufnr, pattern)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for i, line in ipairs(lines) do
        if line:match(pattern) then
            return i
        end
    end
    return nil
end

-- Find all lines containing a pattern
function M.find_lines_containing(bufnr, pattern)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local matching_lines = {}
    for i, line in ipairs(lines) do
        if line:match(pattern) then
            table.insert(matching_lines, i)
        end
    end
    return matching_lines
end

-- Get line content at specific line number
function M.get_line(bufnr, line_num)
    local lines = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)
    return lines[1]
end

-- Set cursor to specific line and column
function M.set_cursor(line, col)
    col = col or 0
    vim.api.nvim_win_set_cursor(0, {line, col})
end

-- Create a test buffer with specific content
function M.create_test_buffer(content_lines)
    local bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content_lines)
    vim.bo[bufnr].filetype = "markdown"
    return bufnr
end

-- Check if a line matches a specific pattern
function M.line_matches(bufnr, line_num, pattern)
    local line = M.get_line(bufnr, line_num)
    return line and line:match(pattern) ~= nil
end

-- Count lines matching a pattern
function M.count_lines_matching(bufnr, pattern)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local count = 0
    for _, line in ipairs(lines) do
        if line:match(pattern) then
            count = count + 1
        end
    end
    return count
end

-- Get buffer content as string (for debugging)
function M.get_buffer_content(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    return table.concat(lines, "\n")
end

-- Print buffer content with line numbers (for debugging)
function M.print_buffer_debug(bufnr, title)
    title = title or "Buffer Content"
    print("=== " .. title .. " ===")
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    for i, line in ipairs(lines) do
        print(string.format("%3d: %s", i, line))
    end
    print("=== End " .. title .. " ===")
end

-- Check if buffer contains specific markers
function M.has_markers(bufnr)
    local content = M.get_buffer_content(bufnr)
    return content:find("<!--INKA_EDIT_START-->", 1, true) and
           content:find("<!--INKA_EDIT_END-->", 1, true)
end

-- Count answer lines (lines starting with "> ")
function M.count_answer_lines(bufnr)
    return M.count_lines_matching(bufnr, "^%s*>%s")
end

-- Create a minimal inka2 card for testing
function M.create_minimal_card()
    return {
        "---",
        "",
        "Deck: Test",
        "",
        "1. Test question?",
        "",
        "> Test answer",
        "",
        "---"
    }
end

-- Create a complex inka2 card for testing
function M.create_complex_card()
    return {
        "---",
        "",
        "Deck: Complex Test",
        "",
        "Tags: testing",
        "",
        "<!--ID:1234-->",
        "1. Multi-line question",
        "   with additional context?",
        "",
        "> Multi-line answer",
        "> with multiple lines",
        "> and various content",
        "",
        "2. Second question?",
        "",
        "> Second answer",
        "",
        "---"
    }
end

-- Assertion helpers for common inka-nvim checks
function M.assert_in_editing_mode(bufnr)
    local markers = require('inka-nvim.markers')
    local visual = require('inka-nvim.visual')
    
    assert(markers.is_in_editing_mode(bufnr), "Buffer should be in editing mode")
    assert(visual.is_editing_mode_active(bufnr), "Visual editing mode should be active")
end

function M.assert_not_in_editing_mode(bufnr)
    local markers = require('inka-nvim.markers')
    local visual = require('inka-nvim.visual')
    
    assert.is_false(markers.is_in_editing_mode(bufnr), "Buffer should not be in editing mode")
    assert.is_false(visual.is_editing_mode_active(bufnr), "Visual editing mode should not be active")
end

return M