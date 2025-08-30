-- Minimal init file for testing inka-nvim
-- This sets up the minimal Neovim environment needed for tests

-- Add current plugin to runtime path
vim.opt.rtp:prepend(vim.fn.getcwd())

-- Add plenary.nvim to runtime path (assuming it's installed via lazy.nvim or similar)
local plenary_path = vim.fn.stdpath("data") .. "/lazy/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 1 then
    vim.opt.rtp:prepend(plenary_path)
else
    -- Try alternative common locations
    local alt_paths = {
        vim.fn.expand("~/.local/share/nvim/lazy/plenary.nvim"),
        vim.fn.expand("~/.local/share/nvim/site/pack/packer/start/plenary.nvim"),
    }
    
    for _, path in ipairs(alt_paths) do
        if vim.fn.isdirectory(path) == 1 then
            vim.opt.rtp:prepend(path)
            break
        end
    end
end

-- Set up basic vim options for testing
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.writebackup = false
vim.opt.updatetime = 100

-- Enable filetype detection and plugins
vim.cmd([[
filetype plugin indent on
syntax on
]])

-- Load plenary and verify it's working
local plenary_ok, plenary = pcall(require, 'plenary')
if not plenary_ok then
    error("plenary.nvim is required for testing but not found in runtime path")
end

-- Load plenary busted commands
pcall(require, 'plenary.busted')

-- Manually create the PlenaryBustedFile command since --noplugin prevents plugin/*.vim from loading
vim.api.nvim_create_user_command('PlenaryBustedFile', function(opts)
    require('plenary.test_harness').test_file(opts.args)
end, { nargs = 1, complete = 'file' })

vim.api.nvim_create_user_command('PlenaryBustedDirectory', function(opts)
    require('plenary.test_harness').test_directory_command(opts.args)
end, { nargs = '+', complete = 'file' })

-- Verify PlenaryBustedFile command exists
if vim.fn.exists(':PlenaryBustedFile') ~= 2 then
    error("PlenaryBustedFile command not available after manual creation")
end

-- Initialize inka-nvim with debug mode for testing
require('inka-nvim').setup({
    debug = true,
})

print("Minimal test environment initialized for inka-nvim")
print("Plenary commands available: " .. tostring(vim.fn.exists(':PlenaryBustedFile') == 2))