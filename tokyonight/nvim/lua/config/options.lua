-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Wrap long lines at the right edge of the window instead of running off screen.
-- LazyVim sets `wrap = false` by default, so we turn it back on here.
vim.opt.wrap = true
-- `linebreak` (already on in LazyVim) wraps at convenient points, not mid-word.

-- Indent wrapped continuation lines to match the start of the original line.
vim.opt.breakindent = true
-- Marker shown at the start of wrapped continuation lines.
vim.opt.showbreak = "↳ "
