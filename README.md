# inka-nvim

A Neovim plugin for editing [inka2](https://github.com/sysid/inka2) flashcards with improved markdown editing experience.

## Overview

**inka-nvim** provides a specialized editing mode for inka2 flashcards in markdown files. It temporarily removes answer markers (`> `) to allow natural markdown editing, then restores them when you're done editing.

### Problem

When editing inka2 flashcards, the answer markers (`> `) can interfere with natural markdown editing:

```markdown
---
Deck: Programming

1. What is a closure in JavaScript?

> A closure is a function that has access to variables
> from an outer scope even after the outer function
> has finished executing.
---
```

The `> ` prefixes make it harder to edit, format, and read the answer content.

### Solution

**inka-nvim** provides an "editing mode" that:
1. Detects the flashcard under your cursor
2. Temporarily removes the `> ` markers with invisible HTML comments
3. Lets you edit naturally in plain markdown
4. Restores the `> ` markers when you save

## Installation

### Using lazy.nvim

```lua
{
  'inka-nvim',
  ft = 'markdown',
  config = function()
    require('inka-nvim').setup()
  end,
}
```

### Using packer.nvim

```lua
use {
  'inka-nvim',
  ft = 'markdown',
  config = function()
    require('inka-nvim').setup()
  end,
}
```

## Usage

### Basic Workflow

1. **Position cursor** anywhere within an inka2 flashcard (between `---` markers)
2. **Enter editing mode**: `:InkaEdit`
   - Answer markers (`> `) are temporarily removed
   - Visual indicator shows you're in editing mode
3. **Edit naturally** in plain markdown
4. **Save changes**: `:InkaSave`
   - Answer markers are restored
   - Visual indicators are cleared

### Commands

- `:InkaEdit` - Enter inka editing mode for the card under cursor
- `:InkaSave` - Exit inka editing mode and restore answer markers  
- `:InkaStatus` - Show debug information about current state

### Example

**Before `:InkaEdit`:**
```markdown
---
Deck: Programming

1. What is a closure?

> A function that captures variables
> from its outer scope.

2. Next question...
---
```

**During editing mode (after `:InkaEdit`):**
```markdown
---
Deck: Programming

<!--INKA_EDIT_START-->
1. What is a closure?

<!--INKA_ANSWER_START-->
A function that captures variables
from its outer scope.
<!--INKA_EDIT_END-->

2. Next question...
---
```

**After `:InkaSave`:**
```markdown
---
Deck: Programming

1. What is a closure?

> A function that captures variables
> from its outer scope.

2. Next question...
---
```

## Features

### Intelligent Card Detection
- **Cursor-based detection**: Works when cursor is anywhere in the card (question or answer)
- **Multi-line support**: Handles questions and answers spanning multiple lines
- **ID comment support**: Preserves `<!--ID:123-->` comments
- **Boundary detection**: Correctly identifies card boundaries using empty lines, next questions, or section markers

### Robust Marker System
- **Three-marker approach**: `EDIT_START`, `ANSWER_START`, `EDIT_END` for precise restoration
- **Safe editing**: Markers are HTML comments that don't interfere with inka2 processing
- **Content preservation**: Handles complex formatting, code blocks, and nested markdown

### Visual Feedback
- **Status line indicator**: Shows "INKA EDIT MODE" when active
- **Buffer-local state**: Tracks editing mode per file
- **Clear notifications**: Success/error messages for all operations

### Safety Features
- **Validation**: Ensures cursor is in valid inka2 section
- **Error handling**: Graceful failures with helpful error messages
- **State management**: Prevents conflicts when switching between buffers

## Configuration

### Default Configuration

```lua
require('inka-nvim').setup({
  -- Marker strings used to delimit editing regions
  markers = {
    edit_start = "<!--INKA_EDIT_START-->",
    answer_start = "<!--INKA_ANSWER_START-->", 
    edit_end = "<!--INKA_EDIT_END-->",
  },
  
  -- Visual indicators for editing mode
  visual = {
    statusline_text = "INKA EDIT MODE",
    highlight_group = "InkaEditMode",
    line_highlight = "InkaEditLine",
  },
  
  -- Answer prefix that gets toggled
  answer_prefix = "> ",
  
  -- Enable debug output
  debug = false,
})
```

### Custom Configuration

```lua
require('inka-nvim').setup({
  -- Use custom markers
  markers = {
    edit_start = "<!-- EDITING MODE START -->",
    answer_start = "<!-- ANSWERS START -->",
    edit_end = "<!-- EDITING MODE END -->",
  },
  
  -- Custom visual indicators
  visual = {
    statusline_text = "📝 EDITING INKA CARD",
  },
  
  -- Enable debug mode for troubleshooting
  debug = true,
})
```

## Supported Inka2 Features

### Card Types
- **Basic Q&A cards**: Questions with `> ` prefixed answers
- **Cloze deletion cards**: Cards with `{{c1::text}}` syntax
- **Multi-line content**: Questions and answers spanning multiple lines

### Card Elements
- **ID comments**: `<!--ID:123-->` comments are preserved
- **Deck headers**: `Deck: Name` declarations
- **Tags**: `Tags: tag1 tag2` declarations
- **Complex formatting**: Code blocks, lists, links, and other markdown

### Section Handling
- **Multiple sections**: Files with multiple `---` delimited sections
- **Mixed content**: Text outside inka2 sections is ignored
- **Boundary detection**: Proper card separation using various markers

## Development

### Requirements
- Neovim >= 0.8.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) (for testing)
- [inka2](https://github.com/sysid/inka2) (optional, for end-to-end testing)

### Development Setup

```bash
# Clone the repository
git clone https://github.com/your-username/inka-nvim.git
cd inka-nvim

# Set up development environment
make setup

# Run tests
make test

# Format code
make format

# Open in development mode
make dev
```

### Testing

The plugin includes comprehensive tests using plenary.nvim:

```bash
# Run all tests
make test

# Run specific test files
make test-detection
make test-markers
make test-commands
make test-integration

# Interactive testing
make test-interactive

# Test with debug output
make test-debug
```

### Project Structure

```
inka-nvim/
├── lua/inka-nvim/
│   ├── init.lua          # Plugin entry point
│   ├── config.lua        # Configuration management
│   ├── detection.lua     # Card boundary detection
│   ├── markers.lua       # Marker insertion/removal
│   ├── visual.lua        # Visual mode indicators
│   └── commands.lua      # Command implementations
├── plugin/
│   └── inka-nvim.vim     # Vim plugin boilerplate
├── tests/
│   ├── fixtures/         # Test inka2 content
│   └── inka-nvim/        # Test suites
└── doc/
    └── inka-nvim.txt     # Vim help documentation
```

## Troubleshooting

### Enable Debug Mode
```lua
require('inka-nvim').setup({ debug = true })
```

### Check Status
Use `:InkaStatus` to see detailed information about:
- Current buffer state
- Cursor position
- Card detection results
- Editing mode status

### Common Issues

**"Not within an inka2 section"**
- Ensure cursor is between `---` markers
- Check that the section has proper inka2 format

**"Could not find numbered question"** 
- Ensure there's a numbered question (e.g., `1. Question?`) above cursor
- Check for proper question formatting

**Visual indicators not showing**
- Check your statusline configuration
- Try `:InkaStatus` to verify plugin state

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b my-feature`
3. Make changes and add tests
4. Run the test suite: `make test`
5. Format code: `make format`
6. Submit a pull request

## License

MIT License - see LICENSE file for details.

## Related Projects

- [inka2](https://github.com/sysid/inka2) - The flashcard extraction tool this plugin supports
- [Anki](https://apps.ankiweb.net/) - The spaced repetition software that inka2 targets# inka-nvim
