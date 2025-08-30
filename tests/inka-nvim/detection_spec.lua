local helpers = require('tests.test_helpers')
local detection = require('inka-nvim.detection')

describe("inka-nvim detection", function()
    local bufnr
    
    before_each(function()
        bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(bufnr)
    end)
    
    after_each(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
        end
    end)
    
    describe("is_in_inka_section", function()
        it("should detect cursor within inka2 section", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            -- Test line 6 (within first section)
            assert.is_true(detection.is_in_inka_section(bufnr, 6))
            
            -- Test line 10 (within first section)
            assert.is_true(detection.is_in_inka_section(bufnr, 10))
            
            -- Test line 2 (outside section)
            assert.is_false(detection.is_in_inka_section(bufnr, 2))
        end)
        
        it("should handle multiple inka2 sections", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            -- Find line numbers for second section
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            local second_section_start = nil
            local in_first_section = false
            
            for i, line in ipairs(lines) do
                if line:match("^%-%-%-$") then
                    if in_first_section then
                        -- This is the end of first section
                        in_first_section = false
                    else
                        if second_section_start then
                            -- This is start of second section
                            in_first_section = true
                        else
                            second_section_start = i
                        end
                    end
                end
            end
            
            -- Test that we can detect being in second section
            if second_section_start then
                assert.is_true(detection.is_in_inka_section(bufnr, second_section_start + 3))
            end
        end)
    end)
    
    describe("find_card_bounds", function()
        it("should find bounds of basic card without ID", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            -- Find line with "What is the answer" question
            local question_line = helpers.find_line_containing(bufnr, "What is the answer")
            assert.is_not_nil(question_line)
            
            local card_bounds = detection.find_card_bounds(bufnr, question_line)
            
            assert.is_not_nil(card_bounds)
            assert.equals(question_line, card_bounds.question_line)
            assert.equals(question_line, card_bounds.start_line) -- No ID comment
            assert.is_not_nil(card_bounds.answer_start_line)
            assert.is_not_nil(card_bounds.end_line)
            assert.is_true(card_bounds.end_line > card_bounds.question_line)
        end)
        
        it("should find bounds of card with ID comment", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            -- Find line with "what is 2 + 2" question (has ID)
            local question_line = helpers.find_line_containing(bufnr, "what is 2 %+ 2")
            assert.is_not_nil(question_line)
            
            local card_bounds = detection.find_card_bounds(bufnr, question_line)
            
            assert.is_not_nil(card_bounds)
            assert.equals(question_line, card_bounds.question_line)
            assert.equals(question_line - 1, card_bounds.start_line) -- ID comment line
            assert.is_not_nil(card_bounds.answer_start_line)
            
            -- Verify ID comment is actually there
            local id_line = vim.api.nvim_buf_get_lines(bufnr, card_bounds.start_line - 1, card_bounds.start_line, false)[1]
            assert.matches("<!%-%-ID:%d+%-%-", id_line)
        end)
        
        it("should detect from cursor in answer section", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            -- Find line with answer content
            local answer_line = helpers.find_line_containing(bufnr, "> 42")
            assert.is_not_nil(answer_line)
            
            local card_bounds = detection.find_card_bounds(bufnr, answer_line)
            
            assert.is_not_nil(card_bounds)
            assert.is_not_nil(card_bounds.question_line)
            assert.is_true(card_bounds.answer_start_line <= answer_line)
            assert.is_true(card_bounds.end_line >= answer_line)
        end)
        
        it("should handle multi-line questions", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            -- Find line with multi-line question
            local question_line = helpers.find_line_containing(bufnr, "Multi%-line question")
            assert.is_not_nil(question_line)
            
            local card_bounds = detection.find_card_bounds(bufnr, question_line + 1) -- cursor on second line of question
            
            assert.is_not_nil(card_bounds)
            assert.equals(question_line, card_bounds.question_line)
        end)
        
        it("should return error when cursor outside inka2 section", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            local card_bounds, error_msg = detection.find_card_bounds(bufnr, 1) -- First line of file
            
            assert.is_nil(card_bounds)
            assert.is_string(error_msg)
            assert.matches("not within an inka2 section", error_msg)
        end)
        
        it("should handle card at end of section", function()
            helpers.load_fixture_into_buffer(bufnr, "edge_cases.md")
            
            -- Find the last question in a section
            local question_line = helpers.find_line_containing(bufnr, "Last question with ID")
            if question_line then
                local card_bounds = detection.find_card_bounds(bufnr, question_line)
                
                assert.is_not_nil(card_bounds)
                assert.equals(question_line, card_bounds.question_line)
                assert.is_not_nil(card_bounds.end_line)
            end
        end)
    end)
    
    describe("find_answer_lines", function()
        it("should find all answer lines in a card", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            local question_line = helpers.find_line_containing(bufnr, "What color is the sky")
            local card_bounds = detection.find_card_bounds(bufnr, question_line)
            
            assert.is_not_nil(card_bounds)
            
            local answer_lines = detection.find_answer_lines(bufnr, card_bounds)
            
            assert.is_true(#answer_lines >= 2) -- Should have multiple answer lines
        end)
        
        it("should return empty table when no answers exist", function()
            helpers.load_fixture_into_buffer(bufnr, "edge_cases.md")
            
            -- Find question without answer
            local question_line = helpers.find_line_containing(bufnr, "Question without answer")
            if question_line then
                local card_bounds = detection.find_card_bounds(bufnr, question_line)
                if card_bounds then
                    local answer_lines = detection.find_answer_lines(bufnr, card_bounds)
                    assert.equals(0, #answer_lines)
                end
            end
        end)
    end)
    
    describe("pattern recognition", function()
        it("should have correct patterns", function()
            local patterns = detection.get_patterns()
            
            assert.is_table(patterns)
            assert.is_string(patterns.numbered_question)
            assert.is_string(patterns.answer_line)
            assert.is_string(patterns.id_comment)
        end)
        
        it("should match numbered questions correctly", function()
            local patterns = detection.get_patterns()
            
            -- Test various question formats
            local test_cases = {
                { "1. Simple question?", should_match = true },
                { "  2. Indented question", should_match = true },
                { "123. High number question", should_match = true },
                { "Not a question", should_match = false },
                { "1 Missing period", should_match = false },
            }
            
            for _, case in ipairs(test_cases) do
                local matches = case[1]:match(patterns.numbered_question) ~= nil
                assert.equals(case.should_match, matches, "Pattern test failed for: " .. case[1])
            end
        end)
    end)
end)