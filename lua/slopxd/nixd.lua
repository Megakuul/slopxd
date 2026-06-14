-- Configure nixd with a working nixpkgs expression and auto-detected
-- NixOS / home-manager option sets.
local M = {}

local function push_settings(extra)
  -- For future clients.
  vim.lsp.config('nixd', { settings = extra })
  -- For already-running ones.
  for _, client in ipairs(vim.lsp.get_clients({ name = 'nixd' })) do
    client.settings = vim.tbl_deep_extend('force', client.settings or {}, extra)
    client:notify('workspace/didChangeConfiguration', { settings = client.settings })
  end
end

-- Find nixosConfigurations / homeConfigurations / darwinConfigurations in the
-- project flake and point nixd's option completion at the first of each.
local function detect_options(flake_dir)
  local expr = ([[
let f = builtins.getFlake "%s"; in {
  nixos = builtins.attrNames (f.nixosConfigurations or { });
  homeManager = builtins.attrNames (f.homeConfigurations or { });
  darwin = builtins.attrNames (f.darwinConfigurations or { });
}
]]):format(flake_dir)
  vim.system({
    'nix', 'eval', '--impure', '--json',
    '--extra-experimental-features', 'nix-command flakes',
    '--option', 'warn-dirty', 'false',
    '--expr', expr,
  }, { text = true, timeout = 120000 }, function(out)
    vim.schedule(function()
      if out.code ~= 0 or not out.stdout or out.stdout == '' then
        return
      end
      local ok, data = pcall(vim.json.decode, out.stdout)
      if not ok then
        return
      end
      local options = {}
      if data.nixos and data.nixos[1] then
        options.nixos = {
          expr = ('(builtins.getFlake "%s").nixosConfigurations.%s.options'):format(flake_dir, data.nixos[1]),
        }
      end
      if data.homeManager and data.homeManager[1] then
        options.home_manager = {
          expr = ('(builtins.getFlake "%s").homeConfigurations.%s.options'):format(flake_dir, data.homeManager[1]),
        }
      end
      if data.darwin and data.darwin[1] then
        options['nix-darwin'] = {
          expr = ('(builtins.getFlake "%s").darwinConfigurations.%s.options'):format(flake_dir, data.darwin[1]),
        }
      end
      if next(options) then
        M.detected_options = options
        push_settings({ nixd = { options = options } })
      end
    end)
  end)
end

--- @param detected table result of slopxd.nixpkgs.detect()
--- @param opts table|nil user opts (settings are deep-merged last)
function M.setup(detected, opts)
  opts = opts or {}
  if vim.fn.executable('nixd') ~= 1 then
    M.unavailable = true
    return
  end

  local settings = vim.tbl_deep_extend('force', {
    nixd = {
      nixpkgs = { expr = detected.expr },
    },
  }, opts.nixd_settings or {})

  -- Non-flake NixOS machines: enable option completion via <nixpkgs/nixos>.
  if not detected.flake_dir and (vim.env.NIX_PATH or ''):find('nixpkgs=', 1, true) and vim.uv.fs_stat('/etc/nixos') then
    settings.nixd.options = settings.nixd.options or {}
    settings.nixd.options.nixos = settings.nixd.options.nixos
      or { expr = '(import <nixpkgs/nixos> { configuration = { }; }).options' }
  end

  vim.lsp.config('nixd', {
    cmd = { 'nixd' },
    filetypes = { 'nix' },
    root_markers = { 'flake.nix', 'default.nix', 'shell.nix', '.git' },
    settings = settings,
  })
  vim.lsp.enable('nixd')

  if detected.flake_dir then
    detect_options(detected.flake_dir)
  end
end

return M
