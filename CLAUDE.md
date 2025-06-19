# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Neovim plugin written in Lua that appears to be designed for previewing files on the console. The plugin is currently in early development.

## Architecture

- **Main Module**: `lua/preview-on-console.lua` - Contains the core plugin functionality
- **Daemon Command**: `preview-on-console` - To preview images on console
- **Plugin Structure**: Follows standard Neovim plugin conventions with a `lua/` directory containing the main module

## Key Components

### Neovim Plugin

- `M.setup()`: Initializes the plugin by creating an autocmd for cursor movement
- `M.on_cursor_moved()`: Callback function triggered on cursor movement
- `M.get_cursor_file_path()`: Referenced but not yet implemented - this function should extract file paths from cursor position

### Shell Command

- `prevew_on_console`: Read the path from the FIFO file and preview that file.

## Development Notes

- The plugin is incomplete - `M.get_cursor_file_path()` function is called but not defined
- The plugin creates an autocmd that triggers on every cursor movement
- Current behavior prints file path or "No file path found at cursor position" message

## Plugin Installation Pattern

This plugin follows the standard Neovim plugin structure where users would typically:
1. Install via plugin manager 
2. Call `require('preview-on-console').setup()` in their config


# Development Guidelines

- After any changes, commit them by git.
