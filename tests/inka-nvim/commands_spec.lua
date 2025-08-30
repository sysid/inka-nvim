local helpers = require('tests.test_helpers')
local commands = require('inka-nvim.commands')
local markers = require('inka-nvim.markers')

describe("inka-nvim commands", function()
    local bufnr
    local original_notify
    local notify_messages
    
    before_each(function()
        bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_set_current_buf(bufnr)
        
        -- Mock vim.notify to capture messages
        notify_messages = {}
        original_notify = vim.notify
        vim.notify = function(msg, level)
            table.insert(notify_messages, { msg = msg, level = level })
        end
    end)
    
    after_each(function()
        if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_delete(bufnr, { force = true })
        end
        
        -- Restore original vim.notify
        vim.notify = original_notify
    end)
    
    describe("InkaEdit command", function()
        it("should enter editing mode successfully", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            -- Position cursor on a question
            local question_line = helpers.find_line_containing(bufnr, "What is the answer")
            helpers.set_cursor(question_line)
            
            -- Execute InkaEdit command
            commands.inka_edit()
            
            -- Verify editing mode is active
            helpers.assert_in_editing_mode(bufnr)
            
            -- Check notification
            assert.is_true(#notify_messages > 0)
            local success_msg = notify_messages[#notify_messages]
            assert.matches("Entered inka editing mode", success_msg.msg)
        end)
        
        it("should fail on non-markdown files", function()
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {"test content"})
            vim.bo[bufnr].filetype = "text"
            
            commands.inka_edit()
            
            -- Check error notification
            assert.is_true(#notify_messages > 0)
            local error_msg = notify_messages[#notify_messages]
            assert.matches("can only be used in markdown files", error_msg.msg)
            assert.equals(vim.log.levels.ERROR, error_msg.level)
        end)
        
        it("should warn when already in editing mode", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            local question_line = helpers.find_line_containing(bufnr, "What is the answer")
            helpers.set_cursor(question_line)
            
            -- Enter editing mode first time
            commands.inka_edit()
            helpers.assert_in_editing_mode(bufnr)
            
            -- Clear previous messages
            notify_messages = {}
            
            -- Try again
            commands.inka_edit()
            
            -- Check warning notification
            assert.is_true(#notify_messages > 0)
            local warn_msg = notify_messages[#notify_messages]
            assert.matches("Already in inka editing mode", warn_msg.msg)
            assert.equals(vim.log.levels.WARN, warn_msg.level)
        end)
        
        it("should fail when cursor not in inka2 section", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            -- Position cursor outside inka2 section
            helpers.set_cursor(1) -- First line of file
            
            commands.inka_edit()
            
            -- Check error notification
            assert.is_true(#notify_messages > 0)
            local error_msg = notify_messages[#notify_messages]
            assert.matches("Failed to enter inka editing mode", error_msg.msg)
            assert.equals(vim.log.levels.ERROR, error_msg.level)
        end)
    end)
    
    describe("InkaSave command", function()
        it("should exit editing mode successfully", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            local question_line = helpers.find_line_containing(bufnr, "What is the answer")
            helpers.set_cursor(question_line)
            
            -- Enter editing mode first
            commands.inka_edit()
            helpers.assert_in_editing_mode(bufnr)
            
            -- Clear previous messages
            notify_messages = {}
            
            -- Exit editing mode
            commands.inka_save()
            
            helpers.assert_not_in_editing_mode(bufnr)
            
            -- Check success notification
            assert.is_true(#notify_messages > 0)
            local success_msg = notify_messages[#notify_messages]
            assert.matches("Exited inka editing mode", success_msg.msg)
            assert.matches("Answer markers restored", success_msg.msg)
        end)
        
        it("should warn when not in editing mode", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            commands.inka_save()
            
            -- Check warning notification
            assert.is_true(#notify_messages > 0)
            local warn_msg = notify_messages[#notify_messages]
            assert.matches("Not currently in inka editing mode", warn_msg.msg)
            assert.equals(vim.log.levels.WARN, warn_msg.level)
        end)
    end)
    
    describe("InkaStatus command", function()
        it("should show status information", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            local question_line = helpers.find_line_containing(bufnr, "What is the answer")
            helpers.set_cursor(question_line)
            
            -- Capture print output
            local print_output = {}
            local original_print = print
            print = function(...)
                table.insert(print_output, table.concat({...}, " "))
            end
            
            commands.inka_status()
            
            -- Restore print
            print = original_print
            
            -- Check that status information was printed
            assert.is_true(#print_output > 0)
            local status_text = table.concat(print_output, "\n")
            assert.matches("Inka%-nvim Status", status_text)
            assert.matches("Current buffer:", status_text)
            assert.matches("File type: markdown", status_text)
            assert.matches("In inka2 section:", status_text)
        end)
        
        it("should show card bounds when cursor is on card", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            local question_line = helpers.find_line_containing(bufnr, "What is the answer")
            helpers.set_cursor(question_line)
            
            local print_output = {}
            local original_print = print
            print = function(...)
                table.insert(print_output, table.concat({...}, " "))
            end
            
            commands.inka_status()
            print = original_print
            
            local status_text = table.concat(print_output, "\n")
            assert.matches("Card bounds found:", status_text)
            assert.matches("Start line:", status_text)
            assert.matches("Question line:", status_text)
        end)
        
        it("should show editing region when in editing mode", function()
            helpers.load_fixture_into_buffer(bufnr, "basic_cards.md")
            
            local question_line = helpers.find_line_containing(bufnr, "What is the answer")
            helpers.set_cursor(question_line)
            
            -- Enter editing mode
            commands.inka_edit()
            
            local print_output = {}
            local original_print = print
            print = function(...)
                table.insert(print_output, table.concat({...}, " "))
            end
            
            commands.inka_status()
            print = original_print
            
            local status_text = table.concat(print_output, "\n")
            assert.matches("In editing mode: true", status_text)
            assert.matches("Editing region found:", status_text)
            assert.matches("Edit start:", status_text)
            assert.matches("Edit end:", status_text)
        end)
    end)
end)