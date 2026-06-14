-- slopxd — Nix LSP support that just works.
--
-- * configures nixd (modern vim.lsp.config API) with an auto-detected nixpkgs
-- * runs a companion in-process LSP with curated docs + attribute names
--   harvested from your actual nixpkgs
-- * wires up as-you-type completion and <C-Space>
local M = {}

M.defaults = {
  nixpkgs_expr = nil, -- override nixpkgs detection, e.g. 'import <nixpkgs> { }'
  nixd = true, -- configure + enable nixd
  nixd_settings = nil, -- extra settings deep-merged into nixd's
  completion = true, -- enable vim.lsp.completion wiring
  autotrigger = true, -- completion as you type (in-process server)
  keymaps = true, -- <C-Space> in insert mode in nix buffers
  completeopt = true, -- set a completion-friendly 'completeopt'
}

function M.setup(opts)
  M.opts = vim.tbl_deep_extend('force', M.defaults, opts or {})
  local first_setup = not M.did_setup
  M.did_setup = true

  M.detected = require('slopxd.nixpkgs').detect(M.opts)
  require('slopxd.store').setup(M.detected.expr)

  if M.opts.nixd then
    require('slopxd.nixd').setup(M.detected, M.opts)
  end

  vim.lsp.config('slopxd', {
    cmd = require('slopxd.server').cmd,
    filetypes = { 'nix' },
    root_markers = { 'flake.nix', 'default.nix', 'shell.nix', '.git' },
  })
  vim.lsp.enable('slopxd')

  if M.opts.completeopt then
    vim.opt.completeopt:append({ 'menuone', 'noselect', 'popup', 'fuzzy' })
    vim.opt.completeopt:remove('preview')
  end

  if not first_setup then
    return
  end

  local group = vim.api.nvim_create_augroup('slopxd', { clear = true })

  if M.opts.completion then
    vim.api.nvim_create_autocmd('LspAttach', {
      group = group,
      callback = function(args)
        local client = vim.lsp.get_client_by_id(args.data.client_id)
        if not client or (client.name ~= 'slopxd' and client.name ~= 'nixd') then
          return
        end
        if client:supports_method('textDocument/completion') then
          vim.lsp.completion.enable(true, client.id, args.buf, {
            autotrigger = M.opts.autotrigger,
          })
        end
        if M.opts.keymaps then
          vim.keymap.set('i', '<C-Space>', function()
            vim.lsp.completion.get()
          end, { buffer = args.buf, desc = 'slopxd: trigger completion' })
        end
      end,
    })
  end

  vim.api.nvim_create_user_command('NixmaxStatus', function()
    local store = require('slopxd.store')
    local s = store.status()
    local lines = {
      'slopxd status',
      '  nixpkgs source : ' .. (M.detected.source or '?'),
      '  nixpkgs expr   : ' .. (s.expr or '?'),
      '  flake dir      : ' .. (M.detected.flake_dir or '-'),
      ('  harvested      : %d top-level pkgs, %d lib attrs, %d builtins'):format(s.toplevel, s.lib, s.builtins),
      '  cached paths   : ' .. (#s.paths > 0 and table.concat(s.paths, ', ') or '-'),
      '  evaluating     : ' .. (#s.inflight > 0 and table.concat(s.inflight, ', ') or '-'),
    }
    local nixd_opts = require('slopxd.nixd').detected_options
    if nixd_opts then
      lines[#lines + 1] = '  nixd options   : ' .. table.concat(vim.tbl_keys(nixd_opts), ', ')
    end
    local clients = {}
    for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
      clients[#clients + 1] = c.name
    end
    lines[#lines + 1] = '  clients (buf)  : ' .. (#clients > 0 and table.concat(clients, ', ') or 'none')
    for key, err in pairs(s.errors) do
      lines[#lines + 1] = ('  eval error [%s]: %s'):format(key, err:gsub('\n', ' | '))
    end
    vim.notify(table.concat(lines, '\n'))
  end, { desc = 'slopxd: show detection / harvest status' })

  vim.api.nvim_create_user_command('NixmaxRefresh', function()
    require('slopxd.store').setup(M.detected.expr, true)
    vim.notify('slopxd: re-harvesting nixpkgs attribute data in the background')
  end, { desc = 'slopxd: drop caches and re-harvest nixpkgs data' })
end

return M
