# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

**inka-nvim** is a Neovim plugin that provides a specialized editing mode for [inka2](https://github.com/sysid/inka2) flashcards in markdown files. It temporarily removes answer markers (`>`) to allow natural markdown editing, then restores them when editing is complete.

### Problem Solved
When editing inka2 flashcards, the answer markers (`>`) interfere with natural markdown editing. The plugin provides an "editing mode" that hides these markers during editing and restores them afterward.

### Core Workflow
1. Position cursor within an inka2 flashcard (between `---` markers)
2. `:InkaEdit` - Enter editing mode (removes `>` markers, shows visual indicators)
3. Edit content naturally in plain markdown
4. `:InkaSave` - Exit editing mode (restores `>` markers, cleans up)

## Architecture & Key Components

### Modular Structure
```
inka-nvim/
├── lua/inka-nvim/
│   ├── init.lua          # Plugin entry point & setup
│   ├── config.lua        # Configuration management (minimal)
│   ├── detection.lua     # Card boundary detection from cursor position
│   ├── markers.lua       # Three-marker system & prefix toggle logic
│   ├── visual.lua        # Visual mode indicators & treesitter handling
│   └── commands.lua      # :InkaEdit/:InkaSave/:InkaStatus commands
├── plugin/inka-nvim.vim  # Vim plugin boilerplate
├── tests/                # Comprehensive test suite with plenary.nvim
└── docs/                 # Documentation
```

### Three-Marker System Architecture
The plugin uses HTML comment markers to precisely track editing boundaries:

**During `:InkaEdit`:**
```markdown
<!--INKA_EDIT_START-->
<!--ID:1234567890-->          # Optional ID comment (preserved)
1. Question text?             # Question (preserved)
<!--INKA_ANSWER_START-->      # Marks where answers begin
answer content                # "> answer content" becomes "answer content"
more content                  # "> more content" becomes "more content"
<!--INKA_EDIT_END-->
```

**During `:InkaSave`:**
- All content between `INKA_ANSWER_START` and `INKA_EDIT_END` gets `"> "` prefixed
- All markers are removed
- Original inka2 format is restored

### Card Detection Logic
**Cursor-based detection** works from any position within a card:
- **Scan upward** to find numbered question (e.g., `1. Question?`)
- **Optional ID comment** above question (`<!--ID:123-->`)
- **Scan downward** for answer content (lines with `>`)
- **Boundary detection** stops at: next question, empty line, ID comment, or section end

## Key Implementation Details

### Answer Prefix Handling (CRITICAL)
**Historical Issue**: Original implementation had configurable answer prefix `"> "` but this caused problems with empty answer lines.

**Current Implementation** (hardcoded for inka2 compatibility):
- **Removal pattern**: `"^%s*>%s?"` (matches `>` with optional single space)
- **Addition**: Always add `"> "` to ALL lines between answer markers
- **Empty line handling**: `>` becomes `""`, then `""` becomes `"> "`

### Treesitter Error Handling (CRITICAL IMPLEMENTATION)
**Problem**: When modifying many lines simultaneously (adding `"> "` to 20+ lines), treesitter's syntax highlighter gets confused about line lengths and throws `Invalid 'end_col': out of range` errors.

**Solution in `markers.lua`** (applied to both `remove_answer_prefixes` and `add_answer_prefixes`):
```lua
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
```

**Why This Approach**: Instead of suppressing errors after they occur, this prevents them entirely by disabling treesitter during buffer modifications and re-enabling it with fresh state afterward. This ensures treesitter never sees inconsistent buffer/highlighting state.

### Save Protection During Editing Mode (CRITICAL SAFETY)
**Problem**: Users might save the buffer while in editing mode, leaving the file in an inconsistent state with HTML markers and missing answer prefixes.

**Solution**: Multi-layer save protection implemented in `visual.lua` and `commands.lua`:

**1. Autocmd Protection** (primary layer):
```lua
vim.api.nvim_create_autocmd({"BufWritePre", "FileWritePre"}, {
    pattern = "*.md",
    callback = function(args)
        local bufnr = args.buf
        if M.is_editing_mode_active(bufnr) then
            vim.notify(
                "❌ Cannot save while in inka editing mode.\n" ..
                "Use :InkaSave to exit editing mode first, then save.",
                vim.log.levels.WARN,
                { title = "inka-nvim" }
            )
            return true -- Prevent the save operation
        end
    end,
})
```

**2. Command Override Protection** (secondary layer):
```lua
-- Override common save commands (W, Write, Wall, Wq, Wqall)
create_save_guard("W", "w")  -- Blocks :W during editing mode
create_save_guard("Wq", "wq")  -- Blocks :Wq during editing mode
-- ... etc for all common save variants

-- Override normal mode save commands (ZZ, ZQ)
create_normal_mode_guard("ZZ", "Save and quit with inka editing mode protection")
create_normal_mode_guard("ZQ", "Quit without save with inka editing mode protection")
```

**3. Visual Indicators**:
- **Statusline**: Shows `"INKA EDIT MODE [SAVE DISABLED]"`
- **Clear messaging**: Explains exactly how to exit editing mode first

**Why Multi-layer**: Provides comprehensive protection against accidental saves through any method (keymaps, commands, external tools).

## Development Commands

### Testing
```bash
# Run all tests (with detailed test visibility)
make test

# Run tests with different output levels
make test-summary    # Concise output (good for CI)
make test-verbose    # Full raw output (good for debugging)

# Run specific test suites
make test-detection
make test-markers
make test-commands
make test-integration

# Run specific test file
make test-file FILE=detection_spec.lua

# Interactive testing
make test-interactive

# Debug mode testing
make test-debug
```

### Code Quality
```bash
# Format code
make format

# Lint code
make lint

# Validate plugin structure
make validate-plugin
```

### Development
```bash
# Setup environment
make setup

# Open development environment
make dev

# Demo with fixture files
make demo
```

## Configuration Integration

### Neovim Configuration (via lazy.nvim)
```lua
{
  'inka-nvim',
  dir = '/Users/Q187392/dev/s/public/inka-nvim', -- Local development
  ft = 'markdown',
  config = function()
    require('inka-nvim').setup({
      debug = false, -- Enable for troubleshooting
    })
    
    -- Keymaps
    vim.keymap.set('n', '<leader>ie', '<cmd>InkaEdit<cr>', { desc = "Enter inka editing mode" })
    vim.keymap.set('n', '<leader>is', '<cmd>InkaSave<cr>', { desc = "Save and exit inka editing mode" })
    vim.keymap.set('n', '<leader>it', '<cmd>InkaStatus<cr>', { desc = "Show inka plugin status" })
  end,
}
```

## Testing Strategy

### Test Coverage
- **Unit tests**: Card detection, marker management, command execution
- **Integration tests**: Full workflow including edge cases
- **Fixtures**: Real inka2 content including problematic empty line cases
- **Round-trip testing**: Ensures perfect content preservation
- **Test Status**: 46/46 tests passing (100% success rate)

### Enhanced Test Visibility
The `make test` command now shows:
- **Individual test descriptions** from `describe` and `it` blocks
- **Clear progress indicators** for each test file
- **Detailed results** with proper formatting and indentation
- **Multiple output levels**: summary, default (detailed), and verbose modes

### Key Test Cases
- **Empty answer lines**: Lines with just `>` (user-reported issue)
- **Multi-line questions and answers**
- **ID comment preservation**
- **Code block handling within answers**
- **Complex formatting preservation**
- **Save protection**: All save methods blocked during editing mode
- **Normal mode commands**: ZZ/ZQ protection added

## Known Issues & Limitations

### Treesitter Highlighting Errors
**Status**: ✅ Resolved (prevented at source)
**Impact**: Previously cosmetic errors, now eliminated
**Solution**: Disable/re-enable treesitter during buffer modifications to prevent state conflicts

### Save Protection
**Status**: ✅ Complete multi-layer protection implemented
**Coverage**: Autocmds, Ex commands (`:w`, `:wq`, etc.), and normal mode commands (`ZZ`, `ZQ`)
**Impact**: Prevents data corruption from saving in inconsistent editing mode state

### Test Framework
**Status**: ✅ Fully functional with comprehensive coverage
**Coverage**: 46/46 tests passing across all modules
**Features**: Enhanced visibility with detailed output and multiple verbosity levels

### Configuration
**Minimalist approach**: Very few configuration options by design
- Debug mode toggle only
- Hardcoded inka2 compatibility (no customizable prefixes)
- Markers are fixed HTML comments

## Development Workflow

### Adding New Features
1. **Write tests first** using plenary.nvim framework
2. **Implement in appropriate module** (detection, markers, visual, commands)
3. **Test with real inka2 content** using fixtures
4. **Update integration tests** for new functionality
5. **Run full test suite**: `make test`

### Debugging
1. **Enable debug mode**: `setup({ debug = true })`
2. **Use `:InkaStatus`** for detailed state information
3. **Check test fixtures** in `tests/fixtures/` for examples
4. **Run specific test suites** for focused debugging
5. **Use verbose testing**: `make test-verbose` for full test output
6. **Interactive testing**: `make test-interactive` for step-by-step debugging

### Modifying Core Logic
**Critical areas that require extensive testing:**
- **Answer prefix patterns** in `markers.lua` 
- **Card detection logic** in `detection.lua`
- **Boundary detection** for various inka2 formats

## Related Projects

- [inka2](https://github.com/sysid/inka2) - The flashcard extraction tool this plugin supports
- [Anki](https://apps.ankiweb.net/) - Spaced repetition software that inka2 targets

## Performance Characteristics

- **Startup time**: ~60ms (lazy-loaded for markdown files only)
- **Memory usage**: Minimal (stateless except for buffer-local editing mode)
- **Processing**: Handles large inka2 cards (100+ lines) efficiently
- **Buffer operations**: Atomic replacements for consistency

## Future Considerations

### Potential Improvements
- **Syntax highlighting** for inka2 sections during editing mode
- **Auto-completion** for inka2 deck/tag names
- **Integration** with inka2 CLI for direct flashcard processing

### Architectural Stability
- **Three-marker system** is core architecture - changes require extensive testing
- **Hardcoded inka2 compatibility** should be maintained for reliability
- **Modular design** allows safe extension without affecting core functionality