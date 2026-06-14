# Slopxd

Slopped Nixd neovim plugin, designed to give a proper LSP experience for nix.

> [!WARNING]
> This is 100% slop. Don't try to read or understand this code. I plan on doing something like this properly in the future; however, due to the lack of time, this exists for now.

Usage (lazy vim):

```lua
  {
    "megakuul/slopxd",
    ft = "nix",
    config = function()
      require("slopxd").setup {
        completion = false, -- nvim-cmp handles the completion UI
        keymaps = false, -- <C-Space> is already cmp.mapping.complete()
        completeopt = false,
      }
    end,
  },
```


