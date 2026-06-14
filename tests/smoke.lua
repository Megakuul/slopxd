-- Headless smoke test:
--   nvim --headless -u dev/init.lua example/demo.nix -c "luafile tests/smoke.lua"
-- Exits 0 on success, 1 on failure, printing what it checked.
local failures = {}

local function check(name, cond, extra)
  if cond then
    print(('OK   %s'):format(name))
  else
    failures[#failures + 1] = name
    print(('FAIL %s%s'):format(name, extra and (' — ' .. extra) or ''))
  end
end

local bufnr = vim.api.nvim_get_current_buf()

-- 1. Wait for the in-process server to attach.
local attached = vim.wait(10000, function()
  return #vim.lsp.get_clients({ bufnr = bufnr, name = 'slopxd' }) > 0
end, 100)
check('slopxd client attached', attached)

-- Give the background nix evals a chance on a warm cache (non-fatal if slow).
vim.wait(15000, function()
  local s = require('slopxd.store').state
  return s.toplevel ~= nil and s.lib ~= nil
end, 200)
local store_state = require('slopxd.store').state

local function request_completion(row, col)
  local client = vim.lsp.get_clients({ bufnr = bufnr, name = 'slopxd' })[1]
  if not client then
    return nil
  end
  local result
  client:request('textDocument/completion', {
    textDocument = { uri = vim.uri_from_bufnr(bufnr) },
    position = { line = row, character = col },
  }, function(err, res)
    result = { err = err, res = res }
  end, bufnr)
  vim.wait(5000, function()
    return result ~= nil
  end, 50)
  return result and result.res or nil
end

local function labels_of(res)
  local set = {}
  for _, it in ipairs(res and res.items or {}) do
    set[it.label] = it
  end
  return set
end

-- 2. Type "mkD" on a fresh line at the top level and complete.
vim.api.nvim_buf_set_lines(bufnr, 2, 2, false, { 'foo = mkD' })
local res = request_completion(2, 9)
local labels = labels_of(res)
check('completion returns items', res ~= nil and #res.items > 0, res and ('items=' .. tostring(#res.items)) or 'no response')
check('mkDerivation offered with docs', labels.mkDerivation ~= nil and labels.mkDerivation.documentation ~= nil)

-- 3. lib. completion.
vim.api.nvim_buf_set_lines(bufnr, 3, 3, false, { 'bar = lib.' })
res = request_completion(3, 10)
labels = labels_of(res)
check('lib.mkIf offered with docs', labels.mkIf ~= nil and labels.mkIf.documentation ~= nil)
if store_state.lib then
  check('dynamic lib attrs present (e.g. pipe)', labels.pipe ~= nil or labels.composeManyExtensions ~= nil)
else
  print('SKIP dynamic lib attrs (harvest still running — fine on cold cache)')
end

-- 4. builtins. completion.
vim.api.nvim_buf_set_lines(bufnr, 4, 4, false, { 'baz = builtins.' })
res = request_completion(4, 15)
labels = labels_of(res)
check('builtins.tryEval offered', labels.tryEval ~= nil)

-- 5. Inside mkDerivation braces: derivation attribute suggestions.
local function find_line(pat)
  for i, l in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    if l:find(pat) then
      return i - 1, l
    end
  end
end

local pname_row = find_line('pname = ')
res = request_completion(pname_row, 2) -- at indentation, inside the braces
labels = labels_of(res)
check('mkDerivation attrs offered inside braces', labels.nativeBuildInputs ~= nil and labels.installPhase ~= nil)

-- 6. Hover on stdenv.mkDerivation.
local mkdrv_row, mkdrv_line = find_line('stdenv%.mkDerivation')
local hover_col = mkdrv_line:find('mkDerivation') + 2 -- somewhere inside the word
local client = vim.lsp.get_clients({ bufnr = bufnr, name = 'slopxd' })[1]
local hover
client:request('textDocument/hover', {
  textDocument = { uri = vim.uri_from_bufnr(bufnr) },
  position = { line = mkdrv_row, character = hover_col },
}, function(_, r)
  hover = r or false
end, bufnr)
vim.wait(5000, function()
  return hover ~= nil
end, 50)
check('hover has content', type(hover) == 'table' and hover.contents ~= nil)

-- 7. Top-level dynamic package names (only when harvest finished).
if store_state.toplevel then
  vim.api.nvim_buf_set_lines(bufnr, 5, 5, false, { 'qux = ripgre' })
  res = request_completion(5, 12)
  labels = labels_of(res)
  check('dynamic top-level pkgs present (ripgrep)', labels.ripgrep ~= nil)
else
  print('SKIP dynamic top-level pkgs (harvest still running — fine on cold cache)')
end

print(('---\n%d failure(s)'):format(#failures))
vim.cmd(#failures > 0 and 'cquit!' or 'quit!')
