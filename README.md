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

## flake.nix scaffolding

nixd cannot evaluate the flake schema, so slopxd hardcodes it for `flake.nix`
files (see `lua/slopxd/flake.lua`). Completion is context-aware:

- **empty / top level** — `description`, `inputs`, `outputs`, `nixConfig`, plus a
  `flake` snippet that drops a complete, system-agnostic skeleton.
- **inside `inputs = { ... }`** — common inputs (`nixpkgs`, `flake-utils`,
  `home-manager`, `nix-darwin`, ...) as snippets, and member attrs (`url`,
  `follows`, ...) after `someInput.`.
- **inside `outputs = { ... }: { ... }`** — the output schema (`packages`,
  `devShells`, `nixosConfigurations`, `homeConfigurations`, `apps`, `formatter`,
  `overlays`, `nixosModules`, `checks`, ...) as ready-to-use snippets, alongside
  the normal Nix vocabulary.

The per-system snippets are system-agnostic: they use a `forAllSystems` helper
(`nixpkgs.lib.genAttrs`) defined by the `flake`/`outputs` snippets, so no
`flake-utils` dependency is needed. Snippet expansion requires a snippet engine
(`vim.snippet`, the builtin, or your nvim-cmp snippet provider).

