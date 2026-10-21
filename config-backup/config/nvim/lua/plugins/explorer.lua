-- Show dotfiles in the snacks explorer and in file pickers (LazyVim hides them by default).
return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = { hidden = true },
          files = { hidden = true },
        },
      },
    },
  },
}
