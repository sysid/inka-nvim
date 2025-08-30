local helpers = require('tests.test_helpers')
local markers = require('inka-nvim.markers')
local detection = require('inka-nvim.detection')

describe("inka-nvim markers", function()
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
    
    describe("is_in_editing_mode", function()
        it("should detect when buffer is not in editing mode", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            assert.is_false(markers.is_in_editing_mode(bufnr))
        end)
        
        it("should detect when buffer is in editing mode", function()
            local test_content = helpers.create_minimal_card()
            table.insert(test_content, 2, "<!--INKA_EDIT_START-->")
            table.insert(test_content, #test_content, "<!--INKA_EDIT_END-->")
            
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, test_content)
            
            assert.is_true(markers.is_in_editing_mode(bufnr))
        end)
    end)
    
    describe("insert_markers", function()
        it("should insert markers around basic card", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            local question_line = helpers.find_line_containing(bufnr, "What is the answer")
            local card_bounds = detection.find_card_bounds(bufnr, question_line)
            
            assert.is_not_nil(card_bounds)
            
            local success = markers.insert_markers(bufnr, card_bounds)
            assert.is_true(success)
            
            -- Verify markers were inserted
            assert.is_true(markers.is_in_editing_mode(bufnr))
            
            local content = helpers.get_buffer_content(bufnr)
            assert.matches("<!%-%-INKA_EDIT_START%-%-", content)
            assert.matches("<!%-%-INKA_ANSWER_START%-%-", content)
            assert.matches("<!%-%-INKA_EDIT_END%-%-", content)
        end)
        
        it("should handle card with ID comment", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            local question_line = helpers.find_line_containing(bufnr, "what is 2 %+ 2")
            local card_bounds = detection.find_card_bounds(bufnr, question_line)
            
            assert.is_not_nil(card_bounds)
            
            local success = markers.insert_markers(bufnr, card_bounds)
            assert.is_true(success)
            
            -- Verify start marker is before ID comment
            local edit_start_line = helpers.find_line_containing(bufnr, "INKA_EDIT_START")
            local id_line = helpers.find_line_containing(bufnr, "<!%-%-ID:")
            
            assert.is_true(edit_start_line < id_line)
        end)
    end)
    
    describe("remove_markers", function()
        it("should remove all markers from buffer", function()
            -- Create buffer with markers
            local test_content = helpers.create_minimal_card()
            table.insert(test_content, 2, "<!--INKA_EDIT_START-->")
            table.insert(test_content, 6, "<!--INKA_ANSWER_START-->")
            table.insert(test_content, #test_content, "<!--INKA_EDIT_END-->")
            
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, test_content)
            
            -- Verify markers exist
            assert.is_true(markers.is_in_editing_mode(bufnr))
            
            -- Remove markers
            local success = markers.remove_markers(bufnr)
            assert.is_true(success)
            
            -- Verify markers are gone
            assert.is_false(markers.is_in_editing_mode(bufnr))
            
            local content = helpers.get_buffer_content(bufnr)
            assert.does_not_match("INKA_EDIT_START", content)
            assert.does_not_match("INKA_ANSWER_START", content)
            assert.does_not_match("INKA_EDIT_END", content)
        end)
        
        it("should return false when no markers to remove", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            local success = markers.remove_markers(bufnr)
            assert.is_false(success)
        end)
    end)
    
    describe("remove_answer_prefixes", function()
        it("should remove answer prefixes between markers", function()
            -- Create buffer with markers and answer prefixes
            local test_content = {
                "<!--INKA_EDIT_START-->",
                "1. Test question?",
                "<!--INKA_ANSWER_START-->",
                "> First answer line",
                "> Second answer line",
                "> Third answer line",
                "<!--INKA_EDIT_END-->"
            }
            
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, test_content)
            
            local success = markers.remove_answer_prefixes(bufnr)
            assert.is_true(success)
            
            -- Check that prefixes were removed
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            assert.equals("First answer line", lines[4])
            assert.equals("Second answer line", lines[5])
            assert.equals("Third answer line", lines[6])
        end)
        
        it("should handle indented answer prefixes", function()
            local test_content = {
                "<!--INKA_EDIT_START-->",
                "1. Test question?",
                "<!--INKA_ANSWER_START-->",
                "  > Indented answer",
                "    > More indented answer",
                "<!--INKA_EDIT_END-->"
            }
            
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, test_content)
            
            local success = markers.remove_answer_prefixes(bufnr)
            assert.is_true(success)
            
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            assert.equals("Indented answer", lines[4])
            assert.equals("More indented answer", lines[5])
        end)
    end)
    
    describe("add_answer_prefixes", function()
        it("should add answer prefixes to lines between markers", function()
            local test_content = {
                "<!--INKA_EDIT_START-->",
                "1. Test question?",
                "<!--INKA_ANSWER_START-->",
                "First answer line",
                "Second answer line",
                "Third answer line",
                "<!--INKA_EDIT_END-->"
            }
            
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, test_content)
            
            local success = markers.add_answer_prefixes(bufnr)
            assert.is_true(success)
            
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            assert.equals("> First answer line", lines[4])
            assert.equals("> Second answer line", lines[5])
            assert.equals("> Third answer line", lines[6])
        end)
        
        it("should add prefix to empty lines", function()
            local test_content = {
                "<!--INKA_EDIT_START-->",
                "1. Test question?",
                "<!--INKA_ANSWER_START-->",
                "Answer line",
                "",
                "Another answer line",
                "<!--INKA_EDIT_END-->"
            }
            
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, test_content)
            
            markers.add_answer_prefixes(bufnr)
            
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            assert.equals("> Answer line", lines[4])
            assert.equals("> ", lines[5]) -- Empty line gets "> " prefix
            assert.equals("> Another answer line", lines[6])
        end)
        
        it("should not add prefix to lines that already have it", function()
            local test_content = {
                "<!--INKA_EDIT_START-->",
                "1. Test question?",
                "<!--INKA_ANSWER_START-->",
                "> Already prefixed",
                "Not prefixed",
                "<!--INKA_EDIT_END-->"
            }
            
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, test_content)
            
            markers.add_answer_prefixes(bufnr)
            
            local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
            assert.equals("> Already prefixed", lines[4])
            assert.equals("> Not prefixed", lines[5])
        end)
    end)
    
    describe("start_editing_mode", function()
        it("should successfully start editing mode", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            local question_line = helpers.find_line_containing(bufnr, "What is the answer")
            
            -- Count answer lines before editing mode
            local original_answer_count = helpers.count_answer_lines(bufnr)
            
            local success, error_msg = markers.start_editing_mode(bufnr, question_line)
            
            assert.is_true(success)
            assert.is_nil(error_msg)
            assert.is_true(markers.is_in_editing_mode(bufnr))
            
            -- Check that answer prefixes were removed
            local answer_count_after = helpers.count_answer_lines(bufnr)
            assert.is_true(answer_count_after < original_answer_count)
        end)
        
        it("should fail when already in editing mode", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            local question_line = helpers.find_line_containing(bufnr, "What is the answer")
            
            -- Start editing mode first time
            local success1 = markers.start_editing_mode(bufnr, question_line)
            assert.is_true(success1)
            
            -- Try to start again
            local success2, error_msg = markers.start_editing_mode(bufnr, question_line)
            assert.is_false(success2)
            assert.matches("Already in inka editing mode", error_msg)
        end)
    end)
    
    describe("end_editing_mode", function()
        it("should successfully end editing mode", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            local question_line = helpers.find_line_containing(bufnr, "What is the answer")
            
            -- Start editing mode
            markers.start_editing_mode(bufnr, question_line)
            assert.is_true(markers.is_in_editing_mode(bufnr))
            
            -- End editing mode
            local success, error_msg = markers.end_editing_mode(bufnr)
            
            assert.is_true(success)
            assert.is_nil(error_msg)
            assert.is_false(markers.is_in_editing_mode(bufnr))
        end)
        
        it("should fail when not in editing mode", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            local success, error_msg = markers.end_editing_mode(bufnr)
            
            assert.is_false(success)
            assert.matches("Not currently in inka editing mode", error_msg)
        end)
    end)
    
    describe("find_editing_region", function()
        it("should find editing region when markers present", function()
            local test_content = {
                "<!--INKA_EDIT_START-->",
                "1. Test question?",
                "<!--INKA_ANSWER_START-->",
                "Answer content",
                "<!--INKA_EDIT_END-->"
            }
            
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, test_content)
            
            local region = markers.find_editing_region(bufnr)
            
            assert.is_not_nil(region)
            assert.equals(1, region.edit_start_line)
            assert.equals(3, region.answer_start_line)
            assert.equals(5, region.edit_end_line)
        end)
        
        it("should return nil when no markers present", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            local region = markers.find_editing_region(bufnr)
            assert.is_nil(region)
        end)
    end)
end)