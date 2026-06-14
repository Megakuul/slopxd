-- In-process LSP server providing context-aware, documented completion and
-- hover for Nix. Runs next to nixd and fills its gaps: curated docs for the
-- standard vocabulary plus attribute names harvested from the real nixpkgs.
local docs = require('slopxd.docs')
local store = require('slopxd.store')

local M = {}

local Kind = vim.lsp.protocol.CompletionItemKind

-- Letters are trigger characters on purpose: it gives as-you-type completion
-- with the builtin vim.lsp.completion autotrigger. All requests are served
-- in-process from Lua tables, so this is cheap.
local triggers = { '.', '"', "'", '/', '<' }
for c in ('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_'):gmatch('.') do
  triggers[#triggers + 1] = c
end

local function md(value)
  return { kind = 'markdown', value = value }
end

local function item(label, kind, detail, doc, sort_group)
  return {
    label = label,
    kind = kind,
    detail = detail,
    documentation = doc and md(doc) or nil,
    sortText = (sort_group or '5') .. label,
  }
end

local function map_items(tbl, kind, sort_group, into, seen, label_prefix)
  for name, entry in pairs(tbl) do
    local label = (label_prefix or '') .. name
    if not seen[label] then
      seen[label] = true
      into[#into + 1] = item(label, kind, entry.detail, entry.doc, sort_group)
    end
  end
end

local function list_items(names, kind, detail, sort_group, into, seen)
  for _, name in ipairs(names or {}) do
    if not seen[name] then
      seen[name] = true
      into[#into + 1] = item(name, kind, detail, nil, sort_group)
    end
  end
end

--- Extract the dotted chain immediately before the cursor.
--- "foo = pkgs.python3Pack" -> context {"pkgs"}, prefix "python3Pack"
local function chain_before(line, col)
  local before = line:sub(1, col)
  local chain = before:match("[%w_'%-%.]*$") or ''
  local parts = vim.split(chain, '.', { plain = true })
  local prefix = table.remove(parts)
  -- Drop garbage segments (numbers from arithmetic like `1.5`, empty from `..`).
  for _, p in ipairs(parts) do
    if not p:match("^[A-Za-z_][A-Za-z0-9_'%-]*$") then
      return {}, prefix
    end
  end
  return parts, prefix
end

--- Heuristic: are we inside the attrset argument of one of the given
--- builders? Scans up to `lookback` lines above the cursor for the last
--- builder occurrence and counts unbalanced braces from there.
local function inside_call(bufnr, row, col, patterns, lookback)
  local start = math.max(0, row - (lookback or 120))
  local lines = vim.api.nvim_buf_get_lines(bufnr, start, row + 1, false)
  if #lines == 0 then
    return false
  end
  lines[#lines] = lines[#lines]:sub(1, col)
  local text = table.concat(lines, '\n')
  local pos = nil
  for _, pat in ipairs(patterns) do
    local last = nil
    local from = 1
    while true do
      local s = text:find(pat, from)
      if not s then
        break
      end
      last = s
      from = s + 1
    end
    if last and (not pos or last > pos) then
      pos = last
    end
  end
  if not pos then
    return false
  end
  local after = text:sub(pos)
  local _, open = after:gsub('{', '')
  local _, close = after:gsub('}', '')
  return open > close
end

local BUILDER_PATTERNS = {
  'mkDerivation', 'mkShellNoCC', 'mkShell', 'buildPythonPackage',
  'buildGoModule', 'buildRustPackage', 'buildNpmPackage', 'runCommand',
}
local META_PATTERNS = { 'meta%s*=%s*' }
local OPTION_PATTERNS = { 'mkOption%s*' }

local function completion_items(bufnr, row, col)
  local line = (vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]) or ''
  local parts, _ = chain_before(line, col)
  local items, seen = {}, {}
  local last = parts[#parts]

  -- flake.nix gets a hardcoded schema (inputs/outputs attribute names) plus
  -- system-agnostic scaffolding snippets that nixd cannot provide.
  local flake = require('slopxd.flake')
  if flake.is_flake(bufnr) then
    if flake.add_items(bufnr, row, col, parts, items, seen) == 'exclusive' then
      return items
    end
  end

  if #parts == 0 then
    -- Context-sensitive attribute suggestions first.
    if inside_call(bufnr, row, col, META_PATTERNS, 40) then
      map_items(docs.metaAttrs, Kind.Field, '0', items, seen)
    end
    if inside_call(bufnr, row, col, BUILDER_PATTERNS, 200) then
      map_items(docs.mkDerivationAttrs, Kind.Field, '1', items, seen)
    end
    if inside_call(bufnr, row, col, OPTION_PATTERNS, 30) then
      for _, name in ipairs({ 'type', 'default', 'defaultText', 'example', 'description', 'apply', 'internal', 'readOnly' }) do
        if not seen[name] then
          seen[name] = true
          items[#items + 1] = item(name, Kind.Field, 'mkOption attribute', nil, '0')
        end
      end
    end
    -- The standard vocabulary, always.
    map_items(docs.toplevel, Kind.Function, '2', items, seen)
    for _, kw in ipairs(docs.keywords) do
      if not seen[kw] then
        seen[kw] = true
        items[#items + 1] = item(kw, Kind.Keyword, 'keyword', docs.keywordDocs[kw], '3')
      end
    end
    for _, name in ipairs(docs.global_builtins) do
      if not seen[name] then
        seen[name] = true
        local entry = docs.builtins[name]
        items[#items + 1] = item(name, Kind.Function, entry and entry.detail or 'builtin', entry and entry.doc, '3')
      end
    end
    -- Everything nixpkgs exports at the top level (with pkgs; / callPackage scope).
    list_items(store.state.toplevel, Kind.Value, 'nixpkgs', '7', items, seen)
    return items
  end

  if last == 'builtins' then
    map_items(docs.builtins, Kind.Function, '0', items, seen)
    list_items(store.state.builtins, Kind.Function, 'builtin', '5', items, seen)
    return items
  end

  if last == 'types' then
    map_items(docs.types, Kind.Class, '0', items, seen)
    local dyn = store.get_path({ 'types' }, true)
    list_items(dyn, Kind.Class, 'lib.types', '5', items, seen)
    return items
  end

  if last == 'lib' then
    map_items(docs.lib, Kind.Function, '0', items, seen)
    if store.state.lib then
      for name, info in pairs(store.state.lib) do
        if not seen[name] then
          seen[name] = true
          local detail
          if info.type == 'lambda' then
            detail = #info.args > 0 and ('lib.%s { %s }'):format(name, table.concat(info.args, ', '))
              or ('lib.%s (function)'):format(name)
          else
            detail = ('lib.%s (%s)'):format(name, info.type)
          end
          items[#items + 1] = item(name, info.type == 'set' and Kind.Module or Kind.Function, detail, nil, '5')
        end
      end
    end
    return items
  end

  if last == 'stdenv' then
    items[#items + 1] = item('mkDerivation', Kind.Function, docs.toplevel.mkDerivation.detail, docs.toplevel.mkDerivation.doc, '0')
    for _, name in ipairs({ 'hostPlatform', 'buildPlatform', 'targetPlatform', 'isLinux', 'isDarwin', 'isAarch64', 'isx86_64', 'cc', 'shell', 'system' }) do
      items[#items + 1] = item(name, Kind.Field, 'stdenv attribute', nil, '1')
    end
    local dyn = store.get_path({ 'stdenv' })
    list_items(dyn, Kind.Field, 'pkgs.stdenv', '5', items, seen)
    return items
  end

  if last == 'meta' then
    map_items(docs.metaAttrs, Kind.Field, '0', items, seen)
    return items
  end

  -- Generic dotted path: resolve below nixpkgs (or nixpkgs.lib).
  local path = vim.deepcopy(parts)
  local lib_root = false
  if path[1] == 'pkgs' or path[1] == 'nixpkgs' then
    table.remove(path, 1)
  end
  if path[1] == 'lib' then
    table.remove(path, 1)
    lib_root = true
  end
  if #path == 0 then
    -- Bare `pkgs.` — top-level names plus curated builders.
    map_items(docs.toplevel, Kind.Function, '0', items, seen)
    list_items(store.state.toplevel, Kind.Value, 'nixpkgs', '5', items, seen)
    return items
  end
  local dyn = store.get_path(path, lib_root)
  list_items(dyn, Kind.Value, table.concat(parts, '.'), '5', items, seen)
  return items
end

-- ---------------------------------------------------------------------------
-- Hover

local doc_index -- lazily built: name -> doc string
local function build_doc_index()
  if doc_index then
    return doc_index
  end
  doc_index = {}
  local function add(prefix, tbl)
    for name, entry in pairs(tbl) do
      if entry.doc then
        doc_index[prefix .. name] = entry.doc
        if not doc_index[name] then
          doc_index[name] = entry.doc
        end
      end
    end
  end
  add('lib.', docs.lib)
  add('builtins.', docs.builtins)
  add('types.', docs.types)
  add('lib.types.', docs.types)
  add('', docs.toplevel)
  add('stdenv.', { mkDerivation = docs.toplevel.mkDerivation })
  add('meta.', docs.metaAttrs)
  for name, entry in pairs(docs.mkDerivationAttrs) do
    if not doc_index[name] then
      doc_index[name] = entry.doc
    end
  end
  for kw, doc in pairs(docs.keywordDocs) do
    doc_index[kw] = doc
  end
  return doc_index
end

local function hover_result(bufnr, row, col)
  local line = (vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]) or ''
  -- Find the identifier chain covering the cursor column (0-based col).
  local target_s, target_e, target = nil, nil, nil
  local init = 1
  while true do
    local s, e = line:find("[%w_'%-%.]+", init)
    if not s then
      break
    end
    if s <= col + 1 and e >= col + 1 then
      target_s, target_e, target = s, e, line:sub(s, e)
      break
    end
    init = e + 1
  end
  if not target then
    return nil
  end
  local index = build_doc_index()
  -- Word under the cursor within the chain, plus its qualifier.
  local rel = col + 2 - target_s -- 1-based offset of cursor inside chain
  local segs = vim.split(target, '.', { plain = true })
  local off, word, qual = 1, nil, nil
  for i, seg in ipairs(segs) do
    if rel >= off and rel <= off + #seg then
      word = seg
      qual = i > 1 and segs[i - 1] or nil
      break
    end
    off = off + #seg + 1
  end
  if not word or word == '' then
    return nil
  end
  local candidates = {}
  if qual then
    candidates[#candidates + 1] = qual .. '.' .. word
  end
  candidates[#candidates + 1] = word
  for _, key in ipairs(candidates) do
    if index[key] then
      return { contents = md(index[key]) }
    end
  end
  return nil
end

-- ---------------------------------------------------------------------------
-- LSP plumbing

local function buf_pos(params)
  local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
  local row = params.position.line
  local line = (vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]) or ''
  local ok, col = pcall(vim.str_byteindex, line, 'utf-16', params.position.character, false)
  if not ok then
    col = math.min(params.position.character, #line)
  end
  return bufnr, row, col
end

--- `cmd` for vim.lsp.config: an in-process server.
function M.cmd(dispatchers)
  local closing = false
  local request_id = 0
  local srv = {}

  function srv.request(method, params, callback)
    request_id = request_id + 1
    local function reply(err, result)
      vim.schedule(function()
        callback(err, result)
      end)
    end
    if method == 'initialize' then
      reply(nil, {
        capabilities = {
          completionProvider = { triggerCharacters = triggers, resolveProvider = false },
          hoverProvider = true,
        },
        serverInfo = { name = 'slopxd', version = '0.1.0' },
      })
    elseif method == 'shutdown' then
      reply(nil, nil)
    elseif method == 'textDocument/completion' then
      local ok, bufnr, row, col = pcall(buf_pos, params)
      if not ok then
        reply(nil, nil)
      else
        local ok2, items = pcall(completion_items, bufnr, row, col)
        reply(nil, ok2 and { isIncomplete = false, items = items } or nil)
      end
    elseif method == 'textDocument/hover' then
      local ok, bufnr, row, col = pcall(buf_pos, params)
      local result = nil
      if ok then
        local ok2, res = pcall(hover_result, bufnr, row, col)
        result = ok2 and res or nil
      end
      reply(nil, result)
    else
      reply(nil, nil)
    end
    return true, request_id
  end

  function srv.notify(method, _params)
    if method == 'exit' then
      closing = true
      if dispatchers.on_exit then
        dispatchers.on_exit(0, 15)
      end
    end
    return true
  end

  function srv.is_closing()
    return closing
  end

  function srv.terminate()
    closing = true
  end

  return srv
end

return M
