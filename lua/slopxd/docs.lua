-- Curated, hand-written documentation for the Nix standard vocabulary.
-- These entries are always available, independent of nixd or evaluation state.
local M = {}

M.keywords = { 'let', 'in', 'with', 'inherit', 'rec', 'if', 'then', 'else', 'assert', 'or', 'true', 'false', 'null' }

-- Builtins that are available in the global scope (without the `builtins.` prefix).
M.global_builtins = {
  'builtins', 'import', 'derivation', 'abort', 'throw', 'map', 'toString',
  'baseNameOf', 'dirOf', 'removeAttrs', 'fetchTarball', 'fetchGit', 'fromTOML',
  'isNull', 'placeholder',
}

-- Top-level builders / fetchers / helpers from pkgs. Reachable directly when
-- using `with pkgs;` or `callPackage` injection.
M.toplevel = {
  mkDerivation = {
    detail = 'stdenv.mkDerivation { pname, version, src, ... }',
    doc = [[
**stdenv.mkDerivation** — the main way to build a package.

```nix
stdenv.mkDerivation (finalAttrs: {
  pname = "hello";
  version = "1.0";
  src = fetchurl {
    url = "mirror://gnu/hello/hello-${finalAttrs.version}.tar.gz";
    hash = "sha256-...";
  };
  buildInputs = [ zlib ];
  nativeBuildInputs = [ pkg-config ];
})
```

Runs the generic builder phases: `unpackPhase`, `patchPhase`, `configurePhase`,
`buildPhase`, `checkPhase`, `installPhase`, `fixupPhase`. Any phase can be
overridden as a string attribute. Complete inside the attrset to see common
arguments (`pname`, `src`, `buildInputs`, `installPhase`, `meta`, ...).]],
  },
  mkShell = {
    detail = 'pkgs.mkShell { packages, ... }',
    doc = [[
**pkgs.mkShell** — create a development shell for `nix develop` / `nix-shell`.

```nix
pkgs.mkShell {
  packages = [ pkgs.go pkgs.gopls ];
  shellHook = ''
    export FOO=bar
  '';
}
```

`packages` is for tools you want on `$PATH`; `inputsFrom = [ drv ]` pulls in
the build environment of another derivation.]],
  },
  mkShellNoCC = {
    detail = 'pkgs.mkShellNoCC { ... }',
    doc = '**pkgs.mkShellNoCC** — like `mkShell` but without a C compiler in the environment. Faster and smaller when you do not need `cc`.',
  },
  callPackage = {
    detail = 'pkgs.callPackage ./pkg.nix { overrides }',
    doc = [[
**pkgs.callPackage** — import a function and auto-fill its arguments from `pkgs`.

```nix
myTool = pkgs.callPackage ./my-tool.nix { };
```

where `my-tool.nix` is `{ stdenv, fetchurl, zlib }: stdenv.mkDerivation { ... }`.
The second argument overrides individual inputs. The result supports
`.override { zlib = ...; }`.]],
  },
  fetchurl = {
    detail = 'fetchurl { url, hash }',
    doc = [[
**pkgs.fetchurl** — download a file at build time (fixed-output derivation).

```nix
src = fetchurl {
  url = "https://example.org/foo-1.0.tar.gz";
  hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
};
```

Use a wrong/empty hash once, copy the correct one from the error message.]],
  },
  fetchzip = {
    detail = 'fetchzip { url, hash }',
    doc = '**pkgs.fetchzip** — like `fetchurl` but unpacks the archive; the hash covers the *extracted* content, making it stable across re-compressions.',
  },
  fetchgit = {
    detail = 'fetchgit { url, rev, hash }',
    doc = '**pkgs.fetchgit** — clone a git repository at a fixed `rev`. Supports `fetchSubmodules = true;` and `leaveDotGit`.',
  },
  fetchFromGitHub = {
    detail = 'fetchFromGitHub { owner, repo, rev/tag, hash }',
    doc = [[
**pkgs.fetchFromGitHub** — fetch a GitHub repo snapshot (preferred over fetchgit).

```nix
src = fetchFromGitHub {
  owner = "neovim";
  repo = "neovim";
  tag = "v0.12.0";        # or rev = "<commit sha>";
  hash = "sha256-...";
};
```]],
  },
  fetchFromGitLab = {
    detail = 'fetchFromGitLab { owner, repo, rev, hash }',
    doc = '**pkgs.fetchFromGitLab** — like `fetchFromGitHub` for GitLab; supports `domain` for self-hosted instances.',
  },
  fetchPypi = {
    detail = 'fetchPypi { pname, version, hash }',
    doc = '**fetchPypi** — fetch an sdist from PyPI (usually via `python3Packages.fetchPypi`).',
  },
  runCommand = {
    detail = 'runCommand "name" { env } "script"',
    doc = [[
**pkgs.runCommand** — tiny one-off derivation from a shell script.

```nix
runCommand "hello.txt" { } ''
  echo hello > $out
''
```

The script must produce `$out`. Use `runCommandLocal` for cheap commands that
should not go through a remote builder.]],
  },
  runCommandLocal = {
    detail = 'runCommandLocal "name" { } "script"',
    doc = '**pkgs.runCommandLocal** — `runCommand` with `preferLocalBuild = true` and no substitution; for trivial scripts.',
  },
  writeText = {
    detail = 'writeText "name" "content"',
    doc = '**pkgs.writeText** — create a store file with the given content; returns its path.',
  },
  writeTextFile = {
    detail = 'writeTextFile { name, text, executable?, destination? }',
    doc = '**pkgs.writeTextFile** — general file writer; `destination = "/bin/foo"` plus `executable = true` builds tiny packages.',
  },
  writeShellScript = {
    detail = 'writeShellScript "name" "script"',
    doc = '**pkgs.writeShellScript** — store an executable bash script; returns the file path (not a `bin/` package).',
  },
  writeShellScriptBin = {
    detail = 'writeShellScriptBin "name" "script"',
    doc = [[
**pkgs.writeShellScriptBin** — package containing `bin/<name>` with the script.

```nix
hi = writeShellScriptBin "hi" ''
  echo hi "$@"
'';
```]],
  },
  writeShellApplication = {
    detail = 'writeShellApplication { name, runtimeInputs, text }',
    doc = [[
**pkgs.writeShellApplication** — robust shell script package: runs shellcheck,
sets `set -euo pipefail`, and puts `runtimeInputs` on `PATH`.

```nix
writeShellApplication {
  name = "deploy";
  runtimeInputs = [ curl jq ];
  text = ''curl -s ... | jq .'';
}
```]],
  },
  symlinkJoin = {
    detail = 'symlinkJoin { name, paths }',
    doc = '**pkgs.symlinkJoin** — merge several packages into one tree of symlinks (e.g. to bundle a tool with plugins).',
  },
  buildEnv = {
    detail = 'buildEnv { name, paths, pathsToLink? }',
    doc = '**pkgs.buildEnv** — build a profile-like environment from multiple packages; `pathsToLink = [ "/bin" ]` restricts what gets linked.',
  },
  buildGoModule = {
    detail = 'buildGoModule { pname, src, vendorHash, ... }',
    doc = [[
**pkgs.buildGoModule** — build a Go module package.

```nix
buildGoModule {
  pname = "tool"; version = "1.0";
  src = ./.;
  vendorHash = "sha256-..."; # or null when vendor/ is committed
}
```]],
  },
  buildNpmPackage = {
    detail = 'buildNpmPackage { pname, src, npmDepsHash, ... }',
    doc = '**pkgs.buildNpmPackage** — build an npm project; needs `npmDepsHash` (fixed-output hash of the dependency tarball cache).',
  },
  buildPythonPackage = {
    detail = 'buildPythonPackage { pname, src, pyproject = true, ... }',
    doc = [[
**buildPythonPackage** (from `python3Packages`) — build a Python package.

```nix
python3Packages.buildPythonPackage {
  pname = "mylib"; version = "0.1";
  pyproject = true;
  build-system = [ python3Packages.setuptools ];
  src = ./.;
}
```]],
  },
  rustPlatform = {
    detail = 'pkgs.rustPlatform.buildRustPackage { cargoHash, ... }',
    doc = '**pkgs.rustPlatform** — Rust build helpers; `rustPlatform.buildRustPackage { pname, version, src, cargoHash }` is the main entry point.',
  },
  stdenv = {
    detail = 'pkgs.stdenv',
    doc = '**pkgs.stdenv** — the standard build environment. Most used: `stdenv.mkDerivation`, `stdenv.hostPlatform`, `stdenv.isLinux`, `stdenv.isDarwin`, `stdenv.cc`.',
  },
  stdenvNoCC = {
    detail = 'pkgs.stdenvNoCC',
    doc = '**pkgs.stdenvNoCC** — stdenv without a C compiler; use `stdenvNoCC.mkDerivation` for pure-data or script packages.',
  },
  lib = {
    detail = 'pkgs.lib — the nixpkgs function library',
    doc = '**lib** — the nixpkgs library: option helpers (`mkIf`, `mkOption`), string/list/attrset functions, `lib.types`, `lib.licenses`, `lib.platforms`. Complete after `lib.` for the full set.',
  },
  makeWrapper = {
    detail = 'nativeBuildInputs = [ makeWrapper ]',
    doc = '**pkgs.makeWrapper** — setup hook providing `wrapProgram $out/bin/foo --set VAR val --prefix PATH : ${lib.makeBinPath [ ... ]}` in build phases.',
  },
  dockerTools = {
    detail = 'pkgs.dockerTools.buildLayeredImage { ... }',
    doc = '**pkgs.dockerTools** — build OCI/Docker images with Nix; main entry points: `buildLayeredImage`, `buildImage`, `streamLayeredImage`.',
  },
  nixosTest = {
    detail = 'pkgs.nixosTest { nodes, testScript }',
    doc = '**pkgs.nixosTest** — run a NixOS VM integration test with a Python `testScript` driving one or more `nodes`.',
  },
  replaceVars = {
    detail = 'replaceVars ./file { var = value; }',
    doc = '**pkgs.replaceVars** — copy a file substituting `@var@` placeholders (successor of `substituteAll`).',
  },
}

-- lib.* functions.
M.lib = {
  mkIf = {
    detail = 'lib.mkIf cond attrs',
    doc = [[
**lib.mkIf** — conditionally include module config *without* infinite recursion.

```nix
config = lib.mkIf config.services.foo.enable {
  systemd.services.foo = { ... };
};
```

Unlike `if cond then ... else {}`, the condition is pushed down to each leaf,
so it may depend on other option values.]],
  },
  mkMerge = {
    detail = 'lib.mkMerge [ attrs1 attrs2 ]',
    doc = '**lib.mkMerge** — merge multiple configuration fragments inside one module:\n```nix\nconfig = lib.mkMerge [ { a = 1; } (lib.mkIf cond { b = 2; }) ];\n```',
  },
  mkForce = {
    detail = 'lib.mkForce value',
    doc = '**lib.mkForce** — set an option value with priority 50, overriding normal definitions (priority 100) and `mkDefault` (1000).',
  },
  mkDefault = {
    detail = 'lib.mkDefault value',
    doc = '**lib.mkDefault** — set an option value with low priority (1000) so users can override it without `mkForce`.',
  },
  mkOverride = {
    detail = 'lib.mkOverride priority value',
    doc = '**lib.mkOverride** — set an option value with an explicit priority (lower wins). `mkForce` = 50, default = 100, `mkDefault` = 1000.',
  },
  mkBefore = {
    detail = 'lib.mkBefore value',
    doc = '**lib.mkBefore** — order a list/lines option value before normally-ordered ones (`mkAfter` for the opposite).',
  },
  mkAfter = {
    detail = 'lib.mkAfter value',
    doc = '**lib.mkAfter** — order a list/lines option value after normally-ordered ones.',
  },
  mkOption = {
    detail = 'lib.mkOption { type, default, description, ... }',
    doc = [[
**lib.mkOption** — declare a module option.

```nix
options.services.foo.port = lib.mkOption {
  type = lib.types.port;
  default = 8080;
  description = "Port to listen on.";
};
```

Common attrs: `type`, `default`, `defaultText`, `example`, `description`, `apply`.]],
  },
  mkEnableOption = {
    detail = 'lib.mkEnableOption "thing"',
    doc = '**lib.mkEnableOption** — shorthand for a `boolean` option defaulting to `false` with description "Whether to enable *thing*.":\n```nix\noptions.services.foo.enable = lib.mkEnableOption "foo";\n```',
  },
  mkPackageOption = {
    detail = 'lib.mkPackageOption pkgs "name" { }',
    doc = '**lib.mkPackageOption** — declare a `package` option defaulting to `pkgs.name`:\n```nix\npackage = lib.mkPackageOption pkgs "nginx" { };\n```',
  },
  types = {
    detail = 'lib.types — option type constructors',
    doc = '**lib.types** — option types: `str`, `lines`, `int`, `port`, `bool`, `path`, `package`, `enum [ ... ]`, `listOf t`, `attrsOf t`, `nullOr t`, `submodule { options = ...; }`, `either a b`, `oneOf [ ... ]`, `anything`, `raw`.',
  },
  optional = {
    detail = 'lib.optional cond elem -> [ elem ] | [ ]',
    doc = '**lib.optional** — one-element list if cond is true, else empty:\n```nix\nbuildInputs = [ zlib ] ++ lib.optional stdenv.isLinux systemd;\n```',
  },
  optionals = {
    detail = 'lib.optionals cond list -> list | [ ]',
    doc = '**lib.optionals** — the given list if cond is true, else `[ ]`.',
  },
  optionalString = {
    detail = 'lib.optionalString cond str -> str | ""',
    doc = '**lib.optionalString** — the string if cond is true, else `""`. Handy in phases:\n```nix\npostInstall = lib.optionalString stdenv.isDarwin "...";\n```',
  },
  optionalAttrs = {
    detail = 'lib.optionalAttrs cond attrs -> attrs | { }',
    doc = '**lib.optionalAttrs** — the attrset if cond is true, else `{ }`.',
  },
  mapAttrs = {
    detail = 'lib.mapAttrs (name: value: ...) attrs',
    doc = '**lib.mapAttrs** — transform each value of an attrset, keeping names:\n```nix\nlib.mapAttrs (n: v: v * 2) { a = 1; b = 2; }  # => { a = 2; b = 4; }\n```',
  },
  ["mapAttrs'"] = {
    detail = "lib.mapAttrs' (name: value: nameValuePair n v) attrs",
    doc = "**lib.mapAttrs'** — like `mapAttrs` but the function returns a `nameValuePair`, so names can change too.",
  },
  mapAttrsToList = {
    detail = 'lib.mapAttrsToList (name: value: ...) attrs -> list',
    doc = '**lib.mapAttrsToList** — map an attrset to a list:\n```nix\nlib.mapAttrsToList (n: v: "${n}=${v}") { a = "1"; }  # => [ "a=1" ]\n```',
  },
  filterAttrs = {
    detail = 'lib.filterAttrs (name: value: bool) attrs',
    doc = '**lib.filterAttrs** — keep only attrs for which the predicate holds.',
  },
  genAttrs = {
    detail = 'lib.genAttrs [ names ] (name: value)',
    doc = '**lib.genAttrs** — build an attrset from a list of names:\n```nix\nlib.genAttrs [ "x86_64-linux" "aarch64-linux" ] (system: f system)\n```\nThe basis of per-system flake outputs.',
  },
  attrByPath = {
    detail = 'lib.attrByPath [ "a" "b" ] default attrs',
    doc = '**lib.attrByPath** — safe nested lookup with a default when the path is missing.',
  },
  hasAttrByPath = {
    detail = 'lib.hasAttrByPath [ "a" "b" ] attrs -> bool',
    doc = '**lib.hasAttrByPath** — whether a nested attribute path exists.',
  },
  recursiveUpdate = {
    detail = 'lib.recursiveUpdate lhs rhs',
    doc = '**lib.recursiveUpdate** — deep-merge two attrsets; rhs wins on conflicts (unlike `//` which is shallow).',
  },
  concatStringsSep = {
    detail = 'lib.concatStringsSep sep [ strings ]',
    doc = '**lib.concatStringsSep** — join strings:\n```nix\nlib.concatStringsSep ", " [ "a" "b" ]  # => "a, b"\n```',
  },
  concatMapStringsSep = {
    detail = 'lib.concatMapStringsSep sep f list',
    doc = '**lib.concatMapStringsSep** — map then join with separator.',
  },
  concatLines = {
    detail = 'lib.concatLines [ strings ]',
    doc = '**lib.concatLines** — join strings with trailing newlines (for config files).',
  },
  splitString = {
    detail = 'lib.splitString sep str -> list',
    doc = '**lib.splitString** — split a string on a separator:\n```nix\nlib.splitString "." "1.2.3"  # => [ "1" "2" "3" ]\n```',
  },
  hasPrefix = {
    detail = 'lib.hasPrefix prefix str -> bool',
    doc = '**lib.hasPrefix** — whether the string starts with prefix (`hasSuffix`, `hasInfix` exist too).',
  },
  hasSuffix = {
    detail = 'lib.hasSuffix suffix str -> bool',
    doc = '**lib.hasSuffix** — whether the string ends with suffix.',
  },
  removePrefix = {
    detail = 'lib.removePrefix prefix str',
    doc = '**lib.removePrefix** — strip prefix if present, otherwise return the string unchanged.',
  },
  removeSuffix = {
    detail = 'lib.removeSuffix suffix str',
    doc = '**lib.removeSuffix** — strip suffix if present.',
  },
  toUpper = { detail = 'lib.toUpper str', doc = '**lib.toUpper** — uppercase a string (`toLower` for the opposite).' },
  versionOlder = {
    detail = 'lib.versionOlder v1 v2 -> bool',
    doc = '**lib.versionOlder** — `true` when v1 < v2 by version-number comparison (`versionAtLeast` for >=).',
  },
  versionAtLeast = {
    detail = 'lib.versionAtLeast v1 v2 -> bool',
    doc = '**lib.versionAtLeast** — `true` when v1 >= v2.',
  },
  elem = { detail = 'lib.elem x list -> bool', doc = '**lib.elem** — list membership test.' },
  filter = { detail = 'lib.filter pred list', doc = '**lib.filter** — keep list elements matching the predicate.' },
  ["foldl'"] = {
    detail = "lib.foldl' op acc list",
    doc = "**lib.foldl'** — strict left fold; preferred over `foldl` to avoid thunk buildup.",
  },
  range = { detail = 'lib.range first last -> [ ints ]', doc = '**lib.range** — inclusive integer range:\n```nix\nlib.range 1 3  # => [ 1 2 3 ]\n```' },
  unique = { detail = 'lib.unique list', doc = '**lib.unique** — remove duplicate elements (O(n²)).' },
  flatten = { detail = 'lib.flatten nestedList', doc = '**lib.flatten** — recursively flatten nested lists into one list.' },
  listToAttrs = {
    detail = 'lib.listToAttrs [ { name, value } ... ]',
    doc = '**lib.listToAttrs** — build an attrset from `{ name, value }` pairs (see `nameValuePair`).',
  },
  nameValuePair = {
    detail = 'lib.nameValuePair name value -> { name, value }',
    doc = '**lib.nameValuePair** — construct a pair for `listToAttrs` / `mapAttrs\'`.',
  },
  attrNames = { detail = 'lib.attrNames attrs -> [ names ]', doc = '**lib.attrNames** — sorted list of attribute names (same as `builtins.attrNames`).' },
  attrValues = { detail = 'lib.attrValues attrs -> [ values ]', doc = '**lib.attrValues** — attribute values, ordered by name.' },
  getExe = {
    detail = 'lib.getExe drv -> "/nix/store/.../bin/prog"',
    doc = '**lib.getExe** — path to a package\'s main executable (uses `meta.mainProgram`). `lib.getExe\' drv "name"` picks a specific binary.',
  },
  ["getExe'"] = {
    detail = 'lib.getExe\' drv "binName"',
    doc = "**lib.getExe'** — path to a specific executable inside a package's `bin/`.",
  },
  makeBinPath = {
    detail = 'lib.makeBinPath [ drvs ] -> "p1/bin:p2/bin"',
    doc = '**lib.makeBinPath** — colon-separated `bin/` search path, typically for `wrapProgram --prefix PATH`.',
  },
  makeLibraryPath = {
    detail = 'lib.makeLibraryPath [ drvs ]',
    doc = '**lib.makeLibraryPath** — colon-separated `lib/` path for `LD_LIBRARY_PATH`-style variables.',
  },
  importJSON = { detail = 'lib.importJSON ./file.json', doc = '**lib.importJSON** — read and parse a JSON file at eval time.' },
  importTOML = { detail = 'lib.importTOML ./file.toml', doc = '**lib.importTOML** — read and parse a TOML file at eval time (e.g. `Cargo.toml`).' },
  licenses = {
    detail = 'lib.licenses.mit, .gpl3Plus, ...',
    doc = '**lib.licenses** — license metadata constants for `meta.license`, e.g. `lib.licenses.mit`, `lib.licenses.asl20`, `lib.licenses.gpl3Plus`.',
  },
  maintainers = {
    detail = 'lib.maintainers.<handle>',
    doc = '**lib.maintainers** — maintainer entries for `meta.maintainers = with lib.maintainers; [ handle ];`.',
  },
  platforms = {
    detail = 'lib.platforms.linux / .darwin / .all / .unix',
    doc = '**lib.platforms** — platform lists for `meta.platforms`.',
  },
  fileset = {
    detail = 'lib.fileset — precise source selection',
    doc = '**lib.fileset** — compose source file sets: `unions`, `difference`, `fileFilter`, then materialize with `lib.fileset.toSource { root = ./.; fileset = ...; }`. Keeps `src` minimal so rebuilds are rarer.',
  },
  strings = { detail = 'lib.strings.*', doc = '**lib.strings** — string function namespace (most are re-exported at `lib.*`). Complete after `lib.strings.` for the full list.' },
  lists = { detail = 'lib.lists.*', doc = '**lib.lists** — list function namespace.' },
  attrsets = { detail = 'lib.attrsets.*', doc = '**lib.attrsets** — attrset function namespace.' },
  cleanSource = {
    detail = 'lib.cleanSource ./.',
    doc = '**lib.cleanSource** — copy a source path filtering out `.git`, build artifacts and editor junk. See `lib.fileset` for finer control.',
  },
  evalModules = {
    detail = 'lib.evalModules { modules = [ ... ]; }',
    doc = '**lib.evalModules** — run the module system standalone; returns `{ config, options, ... }`.',
  },
  nixosSystem = {
    detail = 'lib.nixosSystem { modules = [ ... ]; }',
    doc = '**lib.nixosSystem** — build a NixOS system from modules (used in `flake.nix` for `nixosConfigurations`).',
  },
}

-- lib.types.* entries (offered after `lib.types.` / `types.`).
M.types = {
  str = { detail = 'types.str', doc = '**types.str** — a string. Multiple definitions are an error (use `types.lines` to concatenate).' },
  lines = { detail = 'types.lines', doc = '**types.lines** — string; multiple definitions are joined with newlines.' },
  bool = { detail = 'types.bool', doc = '**types.bool** — a boolean.' },
  int = { detail = 'types.int', doc = '**types.int** — a signed integer (`types.ints.unsigned`, `ints.between lo hi` for ranges).' },
  float = { detail = 'types.float', doc = '**types.float** — a floating point number.' },
  port = { detail = 'types.port', doc = '**types.port** — integer 0–65535.' },
  path = { detail = 'types.path', doc = '**types.path** — a filesystem path (copied to the store when used in derivations).' },
  package = { detail = 'types.package', doc = '**types.package** — a derivation or store path.' },
  enum = { detail = 'types.enum [ "a" "b" ]', doc = '**types.enum** — one value out of a fixed list.' },
  listOf = { detail = 'types.listOf t', doc = '**types.listOf** — a list of elements of type t; multiple definitions are concatenated.' },
  attrsOf = { detail = 'types.attrsOf t', doc = '**types.attrsOf** — an attrset whose values have type t; definitions are merged by name.' },
  nullOr = { detail = 'types.nullOr t', doc = '**types.nullOr** — either `null` or type t; commonly with `default = null;`.' },
  either = { detail = 'types.either a b', doc = '**types.either** — value of type a or type b (`oneOf` for more than two).' },
  oneOf = { detail = 'types.oneOf [ a b c ]', doc = '**types.oneOf** — value matching any of the listed types.' },
  submodule = {
    detail = 'types.submodule { options = { ... }; }',
    doc = '**types.submodule** — a nested option set; combine with `attrsOf` for keyed instances:\n```nix\ntype = types.attrsOf (types.submodule { options.port = mkOption { ... }; });\n```',
  },
  anything = { detail = 'types.anything', doc = '**types.anything** — accept any value, merging attrsets recursively. Prefer a precise type when possible.' },
  raw = { detail = 'types.raw', doc = '**types.raw** — any value, never merged or evaluated deeply.' },
}

-- builtins.* documentation.
M.builtins = {
  attrNames = { detail = 'builtins.attrNames attrs -> [ names ]', doc = '**builtins.attrNames** — sorted list of attribute names.' },
  attrValues = { detail = 'builtins.attrValues attrs -> [ values ]', doc = '**builtins.attrValues** — values sorted by attribute name.' },
  map = { detail = 'map f list', doc = '**map** — apply f to every list element. Global, no `builtins.` needed.' },
  filter = { detail = 'builtins.filter pred list', doc = '**builtins.filter** — keep elements where pred returns true.' },
  elem = { detail = 'builtins.elem x list -> bool', doc = '**builtins.elem** — list membership.' },
  elemAt = { detail = 'builtins.elemAt list n', doc = '**builtins.elemAt** — element at index n (0-based).' },
  length = { detail = 'builtins.length list -> int', doc = '**builtins.length** — number of list elements.' },
  head = { detail = 'builtins.head list', doc = '**builtins.head** — first element (error on empty list).' },
  tail = { detail = 'builtins.tail list', doc = '**builtins.tail** — all but the first element.' },
  concatLists = { detail = 'builtins.concatLists [ lists ]', doc = '**builtins.concatLists** — concatenate a list of lists.' },
  concatStringsSep = { detail = 'builtins.concatStringsSep sep list', doc = '**builtins.concatStringsSep** — join strings with a separator.' },
  toString = { detail = 'toString value', doc = '**toString** — coerce to string (paths become store paths in string context). Global.' },
  toJSON = { detail = 'builtins.toJSON value -> string', doc = '**builtins.toJSON** — serialize a value to a JSON string.' },
  fromJSON = { detail = 'builtins.fromJSON string', doc = '**builtins.fromJSON** — parse a JSON string into a Nix value.' },
  fromTOML = { detail = 'fromTOML string', doc = '**fromTOML** — parse a TOML string:\n```nix\n(fromTOML (builtins.readFile ./Cargo.toml)).package.version\n```' },
  readFile = { detail = 'builtins.readFile path -> string', doc = '**builtins.readFile** — read a file at evaluation time.' },
  readDir = { detail = 'builtins.readDir path -> { name = "regular"|"directory"|...; }', doc = '**builtins.readDir** — list a directory at eval time.' },
  pathExists = { detail = 'builtins.pathExists path -> bool', doc = '**builtins.pathExists** — whether a path exists at eval time.' },
  baseNameOf = { detail = 'baseNameOf path -> string', doc = '**baseNameOf** — final component of a path/string. Global.' },
  dirOf = { detail = 'dirOf path', doc = '**dirOf** — directory part of a path. Global.' },
  import = { detail = 'import path [args]', doc = '**import** — evaluate another Nix file. `import ./f.nix args` calls the imported function. Global.' },
  fetchTarball = {
    detail = 'fetchTarball { url, sha256? }',
    doc = '**fetchTarball** — download + unpack a tarball at eval time; returns the unpacked path. Global. Impure without `sha256`.',
  },
  fetchGit = {
    detail = 'fetchGit { url, rev?, ref?, shallow? }',
    doc = '**fetchGit** — eval-time git fetch; respects local git config/ssh (useful for private repos). Global.',
  },
  fetchurl = { detail = 'builtins.fetchurl { url, sha256? }', doc = '**builtins.fetchurl** — eval-time file download (prefer `pkgs.fetchurl` in packages).' },
  getFlake = {
    detail = 'builtins.getFlake "ref"',
    doc = '**builtins.getFlake** — evaluate a flake by reference (`"nixpkgs"`, `"github:o/r"`, `"/abs/path"`); returns its outputs + inputs. Paths/registry refs need `--impure` unless locked.',
  },
  getEnv = { detail = 'builtins.getEnv "VAR" -> string', doc = '**builtins.getEnv** — environment variable (empty string if unset). Impure: requires `--impure` in flakes.' },
  currentSystem = { detail = 'builtins.currentSystem -> "x86_64-linux"', doc = '**builtins.currentSystem** — current platform string. Impure in flake context.' },
  typeOf = { detail = 'builtins.typeOf v -> "int"|"string"|"set"|...', doc = '**builtins.typeOf** — type name of a value.' },
  isAttrs = { detail = 'builtins.isAttrs v -> bool', doc = '**builtins.isAttrs** — whether v is an attrset (`isList`, `isString`, `isInt`, `isBool`, `isFunction`, `isPath` exist too).' },
  isList = { detail = 'builtins.isList v -> bool', doc = '**builtins.isList** — whether v is a list.' },
  isString = { detail = 'builtins.isString v -> bool', doc = '**builtins.isString** — whether v is a string.' },
  isFunction = { detail = 'builtins.isFunction v -> bool', doc = '**builtins.isFunction** — whether v is a function.' },
  hasAttr = { detail = 'builtins.hasAttr "name" attrs -> bool', doc = '**builtins.hasAttr** — attribute existence; usually written `attrs ? name`.' },
  getAttr = { detail = 'builtins.getAttr "name" attrs', doc = '**builtins.getAttr** — dynamic attribute access; usually written `attrs.${name}`.' },
  removeAttrs = { detail = 'removeAttrs attrs [ "names" ]', doc = '**removeAttrs** — attrset without the listed attributes. Global.' },
  listToAttrs = { detail = 'builtins.listToAttrs [ { name, value } ]', doc = '**builtins.listToAttrs** — attrset from name/value pairs.' },
  mapAttrs = { detail = 'builtins.mapAttrs (n: v: ...) attrs', doc = '**builtins.mapAttrs** — transform attrset values.' },
  genList = { detail = 'builtins.genList f n', doc = '**builtins.genList** — list `[ (f 0) ... (f (n - 1)) ]`.' },
  ["foldl'"] = { detail = "builtins.foldl' op acc list", doc = "**builtins.foldl'** — strict left fold." },
  seq = { detail = 'builtins.seq a b', doc = '**builtins.seq** — force a (to weak head normal form), then return b.' },
  deepSeq = { detail = 'builtins.deepSeq a b', doc = '**builtins.deepSeq** — recursively force a, then return b (surfaces hidden eval errors).' },
  tryEval = {
    detail = 'builtins.tryEval e -> { success, value }',
    doc = '**builtins.tryEval** — catch *some* eval errors (`throw`/`assert`, not `abort` or missing files).',
  },
  throw = { detail = 'throw "msg"', doc = '**throw** — abort evaluation with an error message (catchable by `tryEval`). Global.' },
  abort = { detail = 'abort "msg"', doc = '**abort** — abort evaluation, never catchable. Global.' },
  trace = { detail = 'builtins.trace msg value', doc = '**builtins.trace** — print msg to stderr, return value. Debugging:\n```nix\nbuiltins.trace (builtins.toJSON x) x\n```' },
  match = {
    detail = 'builtins.match regex str -> null | [ groups ]',
    doc = '**builtins.match** — POSIX ERE match of the *whole* string; returns capture groups or null.',
  },
  split = { detail = 'builtins.split regex str', doc = '**builtins.split** — split by regex; matches appear as sub-lists between the string pieces.' },
  substring = { detail = 'builtins.substring start len str', doc = '**builtins.substring** — substring by offset/length.' },
  stringLength = { detail = 'builtins.stringLength str -> int', doc = '**builtins.stringLength** — length in bytes.' },
  replaceStrings = {
    detail = 'builtins.replaceStrings [ from ] [ to ] str',
    doc = '**builtins.replaceStrings** — parallel string replacement:\n```nix\nbuiltins.replaceStrings [ "." ] [ "-" ] "1.2.3"  # => "1-2-3"\n```',
  },
  functionArgs = { detail = 'builtins.functionArgs f -> { arg = hasDefault; }', doc = '**builtins.functionArgs** — formal arguments of a set-pattern function.' },
  derivation = { detail = 'derivation { name, system, builder, ... }', doc = '**derivation** — the raw derivation primitive; in practice use `stdenv.mkDerivation`. Global.' },
  path = { detail = 'builtins.path { path, name?, filter? }', doc = '**builtins.path** — copy a path to the store with control over name and file filter.' },
  toFile = { detail = 'builtins.toFile "name" "content"', doc = '**builtins.toFile** — create a store file at eval time (no derivation). String context restrictions apply; `pkgs.writeText` is more flexible.' },
  builtins = { detail = 'builtins', doc = '**builtins** — the attrset of all built-in functions. Complete after `builtins.` for the full list.' },
}

-- stdenv.mkDerivation / mkShell argument attributes, offered inside the
-- braces of a builder call.
M.mkDerivationAttrs = {
  pname = { detail = 'pname = "name";', doc = '**pname** — package name (combined with `version` into `name`).' },
  version = { detail = 'version = "1.2.3";', doc = '**version** — package version string.' },
  name = { detail = 'name = "pkg-1.0";', doc = '**name** — full derivation name; prefer `pname` + `version`.' },
  src = {
    detail = 'src = fetchFromGitHub { ... } | ./.;',
    doc = '**src** — the source: a fetcher result or a local path. Local paths are copied to the store (see `lib.fileset` / `lib.cleanSource` to filter).',
  },
  srcs = { detail = 'srcs = [ a b ];', doc = '**srcs** — multiple sources; use with `sourceRoot` to pick the build directory.' },
  sourceRoot = { detail = 'sourceRoot = "source/sub";', doc = '**sourceRoot** — directory to cd into after unpacking.' },
  outputs = { detail = 'outputs = [ "out" "dev" "man" ];', doc = '**outputs** — multiple store outputs; install to `$out`, `$dev`, `$man`, ...' },
  buildInputs = {
    detail = 'buildInputs = [ libs ];',
    doc = '**buildInputs** — libraries/dependencies for the *target* platform: things you link against or need at runtime.',
  },
  nativeBuildInputs = {
    detail = 'nativeBuildInputs = [ tools ];',
    doc = '**nativeBuildInputs** — build-time tools that run on the *build* machine: `cmake`, `pkg-config`, `makeWrapper`, code generators. Their setup hooks run automatically.',
  },
  propagatedBuildInputs = {
    detail = 'propagatedBuildInputs = [ libs ];',
    doc = '**propagatedBuildInputs** — like `buildInputs`, but also become inputs of any package depending on this one (Python deps use this).',
  },
  patches = { detail = 'patches = [ ./fix.patch ];', doc = '**patches** — patch files applied during `patchPhase` with `-p1`.' },
  postPatch = { detail = "postPatch = ''...'';", doc = '**postPatch** — shell snippet after patching; typical place for `substituteInPlace`.' },
  configureFlags = { detail = 'configureFlags = [ "--enable-x" ];', doc = '**configureFlags** — extra `./configure` arguments.' },
  cmakeFlags = { detail = 'cmakeFlags = [ "-DFOO=ON" ];', doc = '**cmakeFlags** — extra CMake arguments (with `cmake` in `nativeBuildInputs`).' },
  mesonFlags = { detail = 'mesonFlags = [ "-Dfoo=true" ];', doc = '**mesonFlags** — extra Meson setup arguments.' },
  makeFlags = { detail = 'makeFlags = [ "PREFIX=$(out)" ];', doc = '**makeFlags** — extra `make` arguments for build and install.' },
  installFlags = { detail = 'installFlags = [ ... ];', doc = '**installFlags** — extra `make install` arguments.' },
  buildPhase = {
    detail = "buildPhase = ''...'';",
    doc = '**buildPhase** — replace the build commands. Convention:\n```nix\nbuildPhase = \'\'\n  runHook preBuild\n  make\n  runHook postBuild\n\'\';\n```',
  },
  installPhase = {
    detail = "installPhase = ''...'';",
    doc = '**installPhase** — replace the install commands; must populate `$out`:\n```nix\ninstallPhase = \'\'\n  runHook preInstall\n  install -Dm755 tool $out/bin/tool\n  runHook postInstall\n\'\';\n```',
  },
  configurePhase = { detail = "configurePhase = ''...'';", doc = '**configurePhase** — replace the configure step.' },
  checkPhase = { detail = "checkPhase = ''...'';", doc = '**checkPhase** — test commands; only runs when `doCheck = true`.' },
  doCheck = { detail = 'doCheck = true;', doc = '**doCheck** — run the test suite during the build.' },
  doInstallCheck = { detail = 'doInstallCheck = true;', doc = '**doInstallCheck** — run `installCheckPhase` against the installed output.' },
  dontBuild = { detail = 'dontBuild = true;', doc = '**dontBuild** — skip `buildPhase`.' },
  dontConfigure = { detail = 'dontConfigure = true;', doc = '**dontConfigure** — skip `configurePhase` (handy when a project has a stray `configure` script).' },
  dontUnpack = { detail = 'dontUnpack = true;', doc = '**dontUnpack** — skip unpacking; for srcless / script derivations.' },
  preBuild = { detail = "preBuild = ''...'';", doc = '**preBuild** — shell snippet before the build phase.' },
  postBuild = { detail = "postBuild = ''...'';", doc = '**postBuild** — shell snippet after the build phase.' },
  preInstall = { detail = "preInstall = ''...'';", doc = '**preInstall** — shell snippet before install.' },
  postInstall = {
    detail = "postInstall = ''...'';",
    doc = '**postInstall** — shell snippet after install; typical place for `wrapProgram`, completions, extra files.',
  },
  postFixup = { detail = "postFixup = ''...'';", doc = '**postFixup** — last hook, after stripping/patchelf.' },
  env = { detail = 'env = { FOO = "bar"; };', doc = '**env** — explicit environment variables for the builder (strings only; preferred over loose attrs).' },
  strictDeps = { detail = 'strictDeps = true;', doc = '**strictDeps** — enforce the build-time vs run-time dependency split; required for proper cross-compilation.' },
  passthru = {
    detail = 'passthru = { updateScript, tests, ... };',
    doc = '**passthru** — extra attrs on the derivation that do not affect the build (e.g. `passthru.tests`, `passthru.updateScript`).',
  },
  meta = {
    detail = 'meta = { description, license, ... };',
    doc = '**meta** — package metadata:\n```nix\nmeta = {\n  description = "A tool";\n  homepage = "https://...";\n  license = lib.licenses.mit;\n  mainProgram = "tool";\n  platforms = lib.platforms.linux;\n};\n```',
  },
  shellHook = { detail = "shellHook = ''...'';", doc = '**shellHook** (mkShell) — shell snippet executed when entering the dev shell.' },
  packages = { detail = 'packages = [ pkgs.go ];', doc = '**packages** (mkShell) — tools to put on `$PATH` in the dev shell.' },
  inputsFrom = { detail = 'inputsFrom = [ drv ];', doc = '**inputsFrom** (mkShell) — inherit the build inputs of other derivations.' },
  hardeningDisable = { detail = 'hardeningDisable = [ "fortify" ];', doc = '**hardeningDisable** — turn off specific compiler hardening flags.' },
  separateDebugInfo = { detail = 'separateDebugInfo = true;', doc = '**separateDebugInfo** — split debug symbols into a `debug` output.' },
}

-- meta = { ... } attributes.
M.metaAttrs = {
  description = { detail = 'description = "Short summary";', doc = '**meta.description** — one-line summary; no trailing period, no leading article.' },
  longDescription = { detail = "longDescription = ''...'';", doc = '**meta.longDescription** — multi-paragraph description (markdown).' },
  homepage = { detail = 'homepage = "https://...";', doc = '**meta.homepage** — upstream URL.' },
  changelog = { detail = 'changelog = "https://.../releases";', doc = '**meta.changelog** — release notes URL for the packaged version.' },
  license = { detail = 'license = lib.licenses.mit;', doc = '**meta.license** — one of `lib.licenses.*` (or a list).' },
  maintainers = { detail = 'maintainers = with lib.maintainers; [ you ];', doc = '**meta.maintainers** — nixpkgs maintainer entries.' },
  platforms = { detail = 'platforms = lib.platforms.linux;', doc = '**meta.platforms** — supported systems (`lib.platforms.all`, `.unix`, `.linux`, `.darwin`).' },
  mainProgram = { detail = 'mainProgram = "tool";', doc = '**meta.mainProgram** — binary name for `lib.getExe` and `nix run`.' },
  broken = { detail = 'broken = stdenv.isDarwin;', doc = '**meta.broken** — mark the package unbuildable under a condition.' },
}

-- Quick docs for keywords (hover + completion detail).
M.keywordDocs = {
  ['let'] = '**let** ... **in** — bind local variables:\n```nix\nlet x = 1; y = 2; in x + y\n```',
  ['in'] = '**in** — closes a `let` binding list.',
  ['with'] = '**with** expr; — bring an attrset\'s attributes into scope:\n```nix\nwith pkgs; [ git ripgrep ]\n```',
  ['inherit'] = '**inherit** — copy variables into an attrset:\n```nix\n{ inherit src version; inherit (pkgs) lib; }\n```',
  ['rec'] = '**rec** { ... } — recursive attrset whose attributes can reference each other. In `mkDerivation`, prefer the `(finalAttrs: { ... })` pattern.',
  ['if'] = '**if** cond **then** a **else** b — expression-level conditional (else is mandatory).',
  ['assert'] = '**assert** cond; expr — abort evaluation when cond is false.',
  ['or'] = 'attrpath **or** default — fallback for missing attributes:\n```nix\nconfig.foo.bar or "fallback"\n```',
}

return M
