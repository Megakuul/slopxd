-- Auto-setup with defaults on the first nix file, unless the user already
-- called require('slopxd').setup() or opted out via vim.g.slopxd_auto = false.
if vim.g.loaded_slopxd then
  return
end
vim.g.loaded_slopxd = true

if vim.g.slopxd_auto == false then
  return
end

vim.api.nvim_create_autocmd('FileType', {
  pattern = 'nix',
  group = vim.api.nvim_create_augroup('slopxd.bootstrap', { clear = true }),
  callback = function()
    local slopxd = require('slopxd')
    if not slopxd.did_setup then
      slopxd.setup()
    end
  end,
})
