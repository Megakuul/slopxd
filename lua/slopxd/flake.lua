-- flake.nix-aware completion. nixd has no idea about the flake schema (the
-- attribute names a flake's `inputs` / `outputs` may contain are not types it
-- can evaluate), so we hardcode it here: context-aware attribute names plus
-- ready-to-use, system-agnostic snippets for the things you actually scaffold
-- in a flake (packages, devShells, modules, systems, ...).
local M = {}

local Kind = vim.lsp.protocol.CompletionItemKind

local function md(value)
  return { kind = 'markdown', value = value }
end

-- A snippet completion item. `body` is LSP snippet syntax: `${1:foo}` are tab
-- stops, `${0}` is the final cursor. Literal Nix interpolation (`${system}`)
-- must be written as `\${system}` in the body so it is not eaten as a tab stop.
local function snip(label, detail, body, doc)
  return {
    label = label,
    kind = Kind.Snippet,
    detail = detail,
    insertText = body,
    insertTextFormat = 2, -- 2 = Snippet
    documentation = doc and md(doc) or nil,
    sortText = '0' .. label,
  }
end

-- ---------------------------------------------------------------------------
-- Snippet libraries, keyed by the position they apply to.

-- Top-level keys of a flake: `{ description; inputs; outputs; nixConfig; }`.
M.toplevel_items = {
  snip('flake', 'complete system-agnostic flake skeleton', [[
{
  description = "${1:A Nix flake}";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.\${system});
    in
    {
      ${0}
    };
}]], [[
**A complete, system-agnostic flake skeleton.**

Defines a `forAllSystems` helper (via `nixpkgs.lib.genAttrs`) so per-system
outputs like `packages`/`devShells` work on every platform without depending on
`flake-utils`. Fill the `in { ... }` body with output snippets.]]),
  snip('description', 'flake description', 'description = "${0}";'),
  snip('inputs', 'flake inputs', [[
inputs = {
  nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  ${0}
};]]),
  snip('outputs', 'flake outputs (system-agnostic)', [[
outputs =
  { self, nixpkgs, ... }:
  let
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.\${system});
  in
  {
    ${0}
  };]]),
  snip('nixConfig', 'flake-level nix settings', [[
nixConfig = {
  extra-substituters = [ "${0}" ];
};]]),
}

-- Common flake inputs, written inside `inputs = { ... }`.
M.input_items = {
  snip('nixpkgs', 'nixpkgs (unstable)', 'nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";'),
  snip('nixpkgs-release', 'nixpkgs (release branch)', 'nixpkgs.url = "github:NixOS/nixpkgs/nixos-${0:24.11}";'),
  snip('flake-utils', 'numtide/flake-utils', 'flake-utils.url = "github:numtide/flake-utils";'),
  snip('flake-parts', 'hercules-ci/flake-parts', 'flake-parts.url = "github:hercules-ci/flake-parts";'),
  snip('systems', 'nix-systems/default', 'systems.url = "github:nix-systems/default";'),
  snip('home-manager', 'nix-community/home-manager', [[
home-manager = {
  url = "github:nix-community/home-manager";
  inputs.nixpkgs.follows = "nixpkgs";
};]]),
  snip('nix-darwin', 'LnL7/nix-darwin', [[
nix-darwin = {
  url = "github:LnL7/nix-darwin";
  inputs.nixpkgs.follows = "nixpkgs";
};]]),
  snip('rust-overlay', 'oxalica/rust-overlay', [[
rust-overlay = {
  url = "github:oxalica/rust-overlay";
  inputs.nixpkgs.follows = "nixpkgs";
};]]),
  snip('treefmt-nix', 'numtide/treefmt-nix', [[
treefmt-nix = {
  url = "github:numtide/treefmt-nix";
  inputs.nixpkgs.follows = "nixpkgs";
};]]),
}

-- Attributes of a single input, after `someInput.` inside `inputs = { ... }`.
M.input_member_items = {
  snip('url', 'flake reference URL', 'url = "${0}";'),
  snip('follows', 'deduplicate a transitive input', 'follows = "${0:nixpkgs}";'),
  snip('inputs', 'override a transitive input', 'inputs.${1:nixpkgs}.follows = "${2:nixpkgs}";'),
  snip('flake', 'treat input as a plain (non-flake) source', 'flake = ${0:false};'),
}

-- The flake output schema, written inside the `outputs = { ... }: { ... }`
-- return set. The per-system ones assume the `forAllSystems` helper from the
-- `outputs`/`flake` snippet above (or your own equivalent).
M.output_items = {
  snip('packages', 'per-system packages (system-agnostic)', [[
packages = forAllSystems (pkgs: {
  default = pkgs.stdenv.mkDerivation {
    pname = "${1:myapp}";
    version = "${2:0.1.0}";

    src = ./.;

    nativeBuildInputs = [ ];
    buildInputs = [ ];

    ${0}
  };
});]], [[
**`packages.<system>.<name>`** — buildable outputs (`nix build`, `nix run`).

Wrapped in `forAllSystems` so it is defined for every platform. `default` is
what `nix build` / `nix run` use with no attribute path.]]),
  snip('devShells', 'per-system dev shells (system-agnostic)', [[
devShells = forAllSystems (pkgs: {
  default = pkgs.mkShell {
    packages = [
      ${1:pkgs.hello}
    ];

    shellHook = ''
      ${0}
    '';
  };
});]], [[
**`devShells.<system>.<name>`** — environments for `nix develop`.

`packages` are tools put on `$PATH`; use `inputsFrom = [ self.packages.\${system}.default ]`
to inherit a package's build environment.]]),
  snip('formatter', 'per-system formatter (nix fmt)', [[
formatter = forAllSystems (pkgs: pkgs.${0:nixfmt-rfc-style});]], [[
**`formatter.<system>`** — the package run by `nix fmt`.]]),
  snip('apps', 'per-system runnable apps', [[
apps = forAllSystems (pkgs: {
  default = {
    type = "app";
    program = "\${pkgs.${1:hello}}/bin/${2:hello}";
  };
});]], [[
**`apps.<system>.<name>`** — `nix run .#name`. `program` is an absolute path to
an executable.]]),
  snip('checks', 'per-system checks (nix flake check)', [[
checks = forAllSystems (pkgs: {
  ${0}
});]], '**`checks.<system>.<name>`** — derivations built by `nix flake check`.'),
  snip('nixosConfigurations', 'a NixOS system', [[
nixosConfigurations.${1:hostname} = nixpkgs.lib.nixosSystem {
  system = "${2:x86_64-linux}";
  modules = [
    ./configuration.nix
    ${0}
  ];
};]], [[
**`nixosConfigurations.<host>`** — built with
`nixos-rebuild switch --flake .#host`.]]),
  snip('homeConfigurations', 'a home-manager configuration', [[
homeConfigurations.${1:user} = home-manager.lib.homeManagerConfiguration {
  pkgs = nixpkgs.legacyPackages.${2:x86_64-linux};
  modules = [
    ./home.nix
    ${0}
  ];
};]], [[
**`homeConfigurations.<name>`** — needs the `home-manager` input. Built with
`home-manager switch --flake .#name`.]]),
  snip('darwinConfigurations', 'a nix-darwin (macOS) system', [[
darwinConfigurations.${1:hostname} = nix-darwin.lib.darwinSystem {
  modules = [
    ./darwin.nix
    ${0}
  ];
};]], '**`darwinConfigurations.<host>`** — needs the `nix-darwin` input.'),
  snip('overlays', 'an overlay', [[
overlays.default = final: prev: {
  ${0}
};]], '**`overlays.<name>`** — `final: prev: { ... }` extending nixpkgs.'),
  snip('nixosModules', 'a reusable NixOS module', [[
nixosModules.default =
  { config, lib, pkgs, ... }:
  {
    ${0}
  };]], '**`nixosModules.<name>`** — a module other flakes can import.'),
  snip('templates', 'a flake template', [[
templates.default = {
  path = ./.;
  description = "${1:template description}";
};]], '**`templates.<name>`** — scaffolds via `nix flake init -t .#name`.'),
  snip('lib', 'a library of helper functions', [[
lib = {
  ${0}
};]], '**`lib`** — arbitrary functions/values exposed for other flakes.'),
}

-- ---------------------------------------------------------------------------
-- Context detection.

function M.is_flake(bufnr)
  return vim.api.nvim_buf_get_name(bufnr):match('flake%.nix$') ~= nil
end

local function text_to_cursor(bufnr, row, col)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, row + 1, false)
  if #lines == 0 then
    return ''
  end
  lines[#lines] = lines[#lines]:sub(1, col)
  return table.concat(lines, '\n')
end

-- Are we inside a `<pattern> { ... }` block at the cursor? Finds the last match
-- of `pattern`, then walks brace depth from its opening `{`: if depth returns to
-- zero before the cursor the block already closed, otherwise we are inside it.
-- Brace counting ignores strings and comments — good enough for a real flake.
local function inside_block(text, pattern)
  local last, from = nil, 1
  while true do
    local s = text:find(pattern, from)
    if not s then
      break
    end
    last, from = s, s + 1
  end
  if not last then
    return false
  end
  local open_pos = text:find('{', last, true)
  if not open_pos then
    return false
  end
  local depth = 0
  for i = open_pos, #text do
    local c = text:sub(i, i)
    if c == '{' then
      depth = depth + 1
    elseif c == '}' then
      depth = depth - 1
      if depth == 0 then
        return false -- the block closed before the cursor
      end
    end
  end
  return depth > 0
end

--- Returns 'inputs' | 'outputs' | 'toplevel'.
function M.context(bufnr, row, col)
  local text = text_to_cursor(bufnr, row, col)
  if inside_block(text, 'inputs%s*=%s*{') then
    return 'inputs'
  end
  -- `outputs` is a function, so we can't reliably brace-match its body; if the
  -- cursor is anywhere past the `outputs =` assignment we treat it as outputs.
  if text:find('outputs%s*=') then
    return 'outputs'
  end
  return 'toplevel'
end

-- ---------------------------------------------------------------------------

local function push(into, seen, list)
  for _, entry in ipairs(list) do
    if not seen[entry.label] then
      seen[entry.label] = true
      into[#into + 1] = entry
    end
  end
end

--- Add flake-aware items to `into`/`seen`. Returns 'exclusive' when these are
--- the only sensible completions (caller should stop), or nil to also include
--- the normal Nix vocabulary.
function M.add_items(bufnr, row, col, parts, into, seen)
  local ctx = M.context(bufnr, row, col)

  -- `someInput.` inside the inputs block -> its member attributes.
  if ctx == 'inputs' and #parts >= 1 then
    push(into, seen, M.input_member_items)
    return 'exclusive'
  end

  -- Only handle the bare-identifier position otherwise; dotted paths fall
  -- through to nixd / the normal nixpkgs resolution.
  if #parts > 0 then
    return nil
  end

  if ctx == 'inputs' then
    push(into, seen, M.input_items)
    return 'exclusive'
  elseif ctx == 'outputs' then
    push(into, seen, M.output_items)
    return nil -- still offer the standard vocabulary (forAllSystems, lib, ...)
  else
    push(into, seen, M.toplevel_items)
    return 'exclusive'
  end
end

return M
