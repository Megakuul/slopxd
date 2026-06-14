-- Detect where to get nixpkgs from, so evaluation "just works".
-- Priority: user override > project flake.lock > NIX_PATH > flake registry > channel tarball.
local M = {}

local function find_flake_dir(startpath)
  local found = vim.fs.find('flake.nix', { upward = true, path = startpath, type = 'file' })[1]
  return found and vim.fs.dirname(found) or nil
end

local function flake_has_nixpkgs_input(dir)
  local f = io.open(dir .. '/flake.lock', 'r')
  if not f then
    return false
  end
  local content = f:read('*a')
  f:close()
  local ok, lock = pcall(vim.json.decode, content)
  if not ok or type(lock) ~= 'table' or type(lock.nodes) ~= 'table' then
    return false
  end
  local root = lock.nodes[lock.root or 'root']
  return type(root) == 'table'
    and type(root.inputs) == 'table'
    and root.inputs.nixpkgs ~= nil
end

--- @param opts table|nil  may contain `nixpkgs_expr` to override detection
--- @return table { expr: string, source: string, flake_dir: string|nil }
function M.detect(opts)
  opts = opts or {}
  local flake_dir = find_flake_dir(vim.fn.getcwd())

  if opts.nixpkgs_expr then
    return { expr = opts.nixpkgs_expr, source = 'user override', flake_dir = flake_dir }
  end

  if flake_dir and flake_has_nixpkgs_input(flake_dir) then
    return {
      expr = ('import (builtins.getFlake "%s").inputs.nixpkgs { }'):format(flake_dir),
      source = 'flake input: ' .. flake_dir,
      flake_dir = flake_dir,
    }
  end

  local nix_path = vim.env.NIX_PATH or ''
  if nix_path:find('nixpkgs=', 1, true) or nix_path:find('/nixpkgs', 1, true) then
    return { expr = 'import <nixpkgs> { }', source = 'NIX_PATH', flake_dir = flake_dir }
  end

  if vim.fn.executable('nix') == 1 then
    -- Resolved through the flake registry; nix downloads nixpkgs on demand.
    return {
      expr = 'import (builtins.getFlake "nixpkgs") { }',
      source = 'flake registry (nixpkgs)',
      flake_dir = flake_dir,
    }
  end

  return {
    expr = 'import (builtins.fetchTarball "channel:nixos-unstable") { }',
    source = 'channel tarball fallback',
    flake_dir = flake_dir,
  }
end

return M
