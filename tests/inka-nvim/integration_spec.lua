local helpers = require('tests.test_helpers')
local commands = require('inka-nvim.commands')

describe("inka-nvim integration", function()
    local bufnr
    local original_notify
    
    before_each(function()
        bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(bufnr)
        
        -- Suppress notifications for cleaner test output
        original_notify = vim.notify
        vim.notify = function() end
    end)
    
    after_each(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
        end
        
        vim.notify = original_notify
    end)
    
    describe("complete workflow", function()
        it("should handle full InkaEdit -> modify -> InkaSave cycle", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            -- Find and position on a question
            local question_line = helpers.find_line_containing(bufnr, "What is the answer")
            helpers.set_cursor(question_line)
            
            -- Store original content for comparison
            local original_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            local original_answer_count = helpers.count_answer_lines(bufnr)
            
            -- 1. Enter editing mode
            commands.inka_edit()
            helpers.assert_in_editing_mode(bufnr)
            
            -- Verify answer prefixes were removed
            local editing_answer_count = helpers.count_answer_lines(bufnr)
            assert.is_true(editing_answer_count < original_answer_count)
            
            -- 2. Modify the content (simulate user editing)
            local answer_start_line = helpers.find_line_containing(bufnr, "INKA_ANSWER_START")
            assert.is_not_nil(answer_start_line)
            
            -- Add new content after the answer start marker
            vim.api.nvim_buf_set_lines(bufnr, answer_start_line, answer_start_line, false, {
                "Modified answer content",
                "Additional line added during editing"
            })
            
            -- 3. Save and exit editing mode
            commands.inka_save()
            helpers.assert_not_in_editing_mode(bufnr)
            
            -- 4. Verify results
            local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            local final_content = table.concat(final_lines, "\n")
            
            -- Markers should be gone
            assert.does_not_match("INKA_EDIT_START", final_content)
            assert.does_not_match("INKA_ANSWER_START", final_content)
            assert.does_not_match("INKA_EDIT_END", final_content)
            
            -- New content should have answer prefixes
            assert.matches("> Modified answer content", final_content)
            assert.matches("> Additional line added during editing", final_content)
            
            -- Should have more answer lines than when in editing mode
            local final_answer_count = helpers.count_answer_lines(bufnr)
            assert.is_true(final_answer_count > editing_answer_count)
        end)
        
        it("should handle card with ID comment correctly", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            local question_line = helpers.find_line_containing(bufnr, "what is 2 %+ 2")
            helpers.set_cursor(question_line)
            
            -- Enter editing mode
            commands.inka_edit()
            helpers.assert_in_editing_mode(bufnr)
            
            -- Verify ID comment is preserved and outside edit region
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            local id_line_index = nil
            local edit_start_index = nil
            
            for i, line in ipairs(lines) do
                if line:match("<!%-%-ID:") then
                    id_line_index = i
                elseif line:match("INKA_EDIT_START") then
                    edit_start_index = i
                end
            end
            
            assert.is_not_nil(id_line_index)
            assert.is_not_nil(edit_start_index)
            assert.is_true(edit_start_index < id_line_index)
            
            -- Exit editing mode
            commands.inka_save()
            helpers.assert_not_in_editing_mode(bufnr)
            
            -- ID comment should still be present
            local final_content = helpers.get_buffer_content(bufnr)
            assert.matches("<!%-%-ID:%d+%-%-", final_content)
        end)
        
        it("should handle multi-line questions and answers", function()
            helpers.load_fixture_into_buffer(bufnr, "complex_cards.md")
            
            local question_line = helpers.find_line_containing(bufnr, "Multi%-line question")
            if question_line then
                helpers.set_cursor(question_line)
                
                commands.inka_edit()
                helpers.assert_in_editing_mode(bufnr)
                
                -- Verify multi-line answers are handled correctly
                local answer_start_line = helpers.find_line_containing(bufnr, "INKA_ANSWER_START")
                local edit_end_line = helpers.find_line_containing(bufnr, "INKA_EDIT_END")
                
                assert.is_not_nil(answer_start_line)
                assert.is_not_nil(edit_end_line)
                assert.is_true(edit_end_line > answer_start_line)
                
                commands.inka_save()
                helpers.assert_not_in_editing_mode(bufnr)
                
                -- Multi-line answer should be properly restored
                local final_content = helpers.get_buffer_content(bufnr)
                local answer_line_count = 0
                for line in final_content:gmatch("[^\n]*") do
                    if line:match("^%s*>") then
                        answer_line_count = answer_line_count + 1
                    end
                end
                assert.is_true(answer_line_count > 0)
            end
        end)
        
        it("should handle multiple cards in same buffer", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            -- Test first card
            local question1 = helpers.find_line_containing(bufnr, "What is the answer")
            helpers.set_cursor(question1)
            
            commands.inka_edit()
            helpers.assert_in_editing_mode(bufnr)
            commands.inka_save()
            helpers.assert_not_in_editing_mode(bufnr)
            
            -- Test second card  
            local question2 = helpers.find_line_containing(bufnr, "What color is the sky")
            if question2 then
                helpers.set_cursor(question2)
                
                commands.inka_edit()
                helpers.assert_in_editing_mode(bufnr)
                commands.inka_save()
                helpers.assert_not_in_editing_mode(bufnr)
            end
            
            -- Both cards should maintain their structure
            local final_content = helpers.get_buffer_content(bufnr)
            assert.matches("> 42", final_content)
            assert.matches("> Blue", final_content)
        end)
        
        it("should handle empty lines in answers correctly", function()
            helpers.load_fixture_into_buffer(bufnr, "complex_cards.md")
            
            local question_line = helpers.find_line_containing(bufnr, "followed by empty line")
            if question_line then
                helpers.set_cursor(question_line)
                
                commands.inka_edit()
                
                -- Add content with empty lines
                local answer_start_line = helpers.find_line_containing(bufnr, "INKA_ANSWER_START")
                vim.api.nvim_buf_set_lines(bufnr, answer_start_line, answer_start_line, false, {
                    "Line with content",
                    "",
                    "After empty line"
                })
                
                commands.inka_save()
                
                local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
                local found_prefixed = false
                local found_empty = false
                
                for _, line in ipairs(final_lines) do
                    if line == "> Line with content" then
                        found_prefixed = true
                    elseif line == "" then
                        found_empty = true
                    end
                end
                
                assert.is_true(found_prefixed)
                assert.is_true(found_empty)
            end
        end)
    end)
    
    describe("empty answer lines handling", function()
        it("should handle round-trip with empty answer lines correctly", function()
            helpers.load_fixture_into_buffer(bufnr, "empty_lines_test.md")
            
            local question_line = helpers.find_line_containing(bufnr, "How to create a mutable global Config singleton")
            helpers.set_cursor(question_line)
            
            -- Store original content for verification
            local original_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            local original_content = table.concat(original_lines, "\n")
            
            -- Verify we have empty answer lines in original (lines with just ">")
            local empty_answer_lines = 0
            for _, line in ipairs(original_lines) do
                if line == ">" then
                    empty_answer_lines = empty_answer_lines + 1
                end
            end
            assert.is_true(empty_answer_lines > 0, "Test fixture should contain empty answer lines (just '>')")
            
            -- 1. Enter editing mode
            commands.inka_edit()
            helpers.assert_in_editing_mode(bufnr)
            
            local editing_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            local editing_content = table.concat(editing_lines, "\n")
            
            -- Verify empty answer lines are now truly empty (no ">" should remain)
            for _, line in ipairs(editing_lines) do
                assert.does_not_match("^%s*>%s*$", line, "No standalone '>' should remain after InkaEdit")
            end
            
            -- 2. Save and exit editing mode
            commands.inka_save()
            helpers.assert_not_in_editing_mode(bufnr)
            
            local final_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            local final_content = table.concat(final_lines, "\n")
            
            -- 3. Verify round-trip correctness
            
            -- All original empty answer lines should be restored as "> "
            local restored_empty_lines = 0
            for _, line in ipairs(final_lines) do
                if line == "> " then
                    restored_empty_lines = restored_empty_lines + 1
                end
            end
            assert.equals(empty_answer_lines, restored_empty_lines, "Empty answer lines should be restored as '> '")
            
            -- Original content lines should be preserved
            assert.matches("use config::Config", final_content)
            assert.matches("lazy_static!", final_content)
            assert.matches("SETTINGS%.write", final_content)
            
            -- No markers should remain
            assert.does_not_match("INKA_EDIT_START", final_content)
            assert.does_not_match("INKA_ANSWER_START", final_content)
            assert.does_not_match("INKA_EDIT_END", final_content)
        end)
    end)
    
    describe("error handling", function()
        it("should gracefully handle malformed content", function()
            helpers.load_fixture_into_buffer(bufnr, "edge_cases.md")
            
            -- Try to edit a question without proper answer
            local question_line = helpers.find_line_containing(bufnr, "Question without answer")
            if question_line then
                helpers.set_cursor(question_line)
                
                -- This should either work or fail gracefully
                commands.inka_edit()
                
                -- If it succeeded, we should be able to save
                if helpers.has_markers(bufnr) then
                    commands.inka_save()
                    helpers.assert_not_in_editing_mode(bufnr)
                end
            end
        end)
        
        it("should handle cursor at section boundaries", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            -- Find section start line
            local section_start = helpers.find_line_containing(bufnr, "^%-%-%-$")
            if section_start then
                helpers.set_cursor(section_start)
                
                -- This should fail gracefully
                commands.inka_edit()
                helpers.assert_not_in_editing_mode(bufnr)
            end
        end)
    end)
end)