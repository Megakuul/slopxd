-- Minimal config to try the plugin straight from this repo:
--
--   nvim -u dev/init.lua example/demo.nix
--
local here = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h")
local root = vim.fn.fnamemodify(here, ":h")
vim.opt.runtimepath:prepend(root)

vim.o.swapfile = false
vim.o.shortmess = vim.o.shortmess .. "c"

require("slopxd").setup()
