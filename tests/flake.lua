-- Headless flake.nix completion test:
--   nvim --headless -u dev/init.lua example/flake.nix -c "luafile tests/flake.lua"
-- Exits 0 on success, 1 on failure.
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

local attached = vim.wait(10000, function()
  return #vim.lsp.get_clients({ bufnr = bufnr, name = 'slopxd' }) > 0
end, 100)
check('slopxd client attached', attached)

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

local function find_line(pat)
  for i, l in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    if l:find(pat) then
      return i - 1, l
    end
  end
end

-- 1. Inside the outputs return set -> flake output schema + snippets.
local pkgs_row = find_line('packages = forAllSystems')
local res = request_completion(pkgs_row, 6) -- on the indentation inside `in { ... }`
local labels = labels_of(res)
check('outputs: devShells snippet offered', labels.devShells ~= nil and labels.devShells.insertTextFormat == 2,
  labels.devShells and ('fmt=' .. tostring(labels.devShells.insertTextFormat)) or 'missing')
check('outputs: nixosConfigurations snippet offered', labels.nixosConfigurations ~= nil)
check('outputs: packages snippet documented', labels.packages ~= nil and labels.packages.documentation ~= nil)
check('outputs: snippet body is system-agnostic (forAllSystems)',
  labels.devShells ~= nil and labels.devShells.insertText:find('forAllSystems', 1, true) ~= nil)
check('outputs: standard vocab still present (builtins)', labels.builtins ~= nil)

-- 2. Inside the inputs block -> input names as snippets, no nixpkgs vocab spam.
local inputs_row = find_line('nixpkgs%.url')
res = request_completion(inputs_row, 4)
labels = labels_of(res)
check('inputs: home-manager snippet offered', labels['home-manager'] ~= nil and labels['home-manager'].insertTextFormat == 2)
check('inputs: flake-utils snippet offered', labels['flake-utils'] ~= nil)
check('inputs: exclusive (no stray builtins)', labels.builtins == nil,
  'builtins should not appear inside inputs block')

-- 3. After `someInput.` inside inputs -> member attributes.
vim.api.nvim_buf_set_lines(bufnr, inputs_row + 1, inputs_row + 1, false, { '    flake-utils.' })
res = request_completion(inputs_row + 1, 16)
labels = labels_of(res)
check('inputs member: follows offered', labels.follows ~= nil and labels.follows.insertTextFormat == 2)
vim.api.nvim_buf_set_lines(bufnr, inputs_row + 1, inputs_row + 2, false, {}) -- undo

-- 4. Top-level of a fresh empty flake -> full skeleton + keys.
local scratch = vim.api.nvim_create_buf(false, false)
vim.api.nvim_buf_set_name(scratch, vim.fn.getcwd() .. '/flake.nix')
vim.bo[scratch].filetype = 'nix'
local flake = require('slopxd.flake')
check('toplevel context detected on empty flake', flake.context(scratch, 0, 0) == 'toplevel')
local items, seen = {}, {}
flake.add_items(scratch, 0, 0, {}, items, seen)
local top = {}
for _, it in ipairs(items) do
  top[it.label] = it
end
check('toplevel: full flake skeleton snippet offered', top.flake ~= nil and top.flake.insertText:find('outputs', 1, true) ~= nil)
check('toplevel: outputs/inputs/description keys offered',
  top.outputs ~= nil and top.inputs ~= nil and top.description ~= nil)

print(('---\n%d failure(s)'):format(#failures))
vim.cmd(#failures > 0 and 'cquit!' or 'quit!')
