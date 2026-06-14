-- Dynamic attribute harvesting from the real nixpkgs via `nix eval`,
-- cached on disk so completion is instant after the first run.
local M = {}

M.state = {
	expr = nil, -- nixpkgs expression all evals are based on
	toplevel = nil, -- list of top-level pkgs attr names
	lib = nil, -- map: name -> { type = "lambda"|"set"|..., args = {...} }
	builtins = nil, -- list of builtins attr names
	paths = {}, -- map: "python3Packages" -> list of attr names
	inflight = {},
	errors = {},
}

local IDENT = "^[A-Za-z_][A-Za-z0-9_'%-]*$"

local function cache_dir()
	local dir = vim.fn.stdpath("cache") .. "/slopxd"
	vim.fn.mkdir(dir, "p")
	return dir
end

local function cache_file(key)
	return cache_dir() .. "/" .. vim.fn.sha256((M.state.expr or "") .. "\0" .. key) .. ".json"
end

local function read_cache(key)
	local f = io.open(cache_file(key), "r")
	if not f then
		return nil
	end
	local content = f:read("*a")
	f:close()
	local ok, data = pcall(vim.json.decode, content)
	if ok then
		return data
	end
end

local function write_cache(key, data)
	local ok, encoded = pcall(vim.json.encode, data)
	if not ok then
		return
	end
	local f = io.open(cache_file(key), "w")
	if f then
		f:write(encoded)
		f:close()
	end
end

local function nix_eval(key, expr, cb)
	if M.state.inflight[key] then
		return
	end
	M.state.inflight[key] = true
	vim.system({
		"nix",
		"eval",
		"--impure",
		"--json",
		"--extra-experimental-features",
		"nix-command flakes",
		"--option",
		"warn-dirty",
		"false",
		"--expr",
		expr,
	}, { text = true, timeout = 300000 }, function(out)
		vim.schedule(function()
			M.state.inflight[key] = nil
			if out.code == 0 and out.stdout and out.stdout ~= "" then
				local ok, data = pcall(vim.json.decode, out.stdout)
				if ok then
					M.state.errors[key] = nil
					write_cache(key, data)
					cb(data)
					return
				end
			end
			M.state.errors[key] = vim.trim((out.stderr or "unknown error"):sub(-1500))
			cb(nil)
		end)
	end)
end

-- Cache-first fetch; falls back to a background nix eval.
local function fetch(key, expr, assign, force)
	if not force then
		local cached = read_cache(key)
		if cached then
			assign(cached)
			return
		end
	end
	nix_eval(key, expr, function(data)
		if data then
			assign(data)
		end
	end)
end

local function lib_expr(expr)
	return ([[
let
  pkgs = (%s);
  info = v:
    let t = builtins.tryEval (builtins.typeOf v);
    in if !t.success then { type = "error"; args = [ ]; }
       else {
         type = t.value;
         args = if t.value == "lambda"
                then builtins.attrNames (builtins.functionArgs v)
                else [ ];
       };
in builtins.mapAttrs (n: v: info v) pkgs.lib
]]):format(expr)
end

function M.setup(expr, force)
	M.state.expr = expr
	if force then
		M.state.toplevel, M.state.lib, M.state.builtins, M.state.paths = nil, nil, nil, {}
	end
	fetch("builtins", "builtins.attrNames builtins", function(d)
		M.state.builtins = d
	end, force)
	fetch("toplevel", ("builtins.attrNames (%s)"):format(expr), function(d)
		M.state.toplevel = d
	end, force)
	fetch("lib", lib_expr(expr), function(d)
		M.state.lib = d
	end, force)
end

--- Attr names for a dotted path below nixpkgs (or nixpkgs.lib when lib_root).
--- Returns the cached list immediately if available; otherwise starts a
--- background eval and returns nil (results show up on the next trigger).
--- @param parts string[] e.g. { "python3Packages" } or { "strings" } with lib_root
--- @param lib_root boolean|nil
function M.get_path(parts, lib_root)
	if not M.state.expr or #parts == 0 then
		return nil
	end
	for _, p in ipairs(parts) do
		if not p:match(IDENT) then
			return nil
		end
	end
	local key = (lib_root and "lib." or "pkgs.") .. table.concat(parts, ".")
	if M.state.paths[key] then
		return M.state.paths[key]
	end
	local base = lib_root and ("(%s).lib"):format(M.state.expr) or ("(%s)"):format(M.state.expr)
	local expr = ([[
let v = %s.%s or null;
in if builtins.isAttrs v then builtins.attrNames v else [ ]
]]):format(base, table.concat(parts, "."))
	fetch(key, expr, function(d)
		M.state.paths[key] = d
	end)
	return M.state.paths[key]
end

function M.status()
	local lib_count = 0
	if M.state.lib then
		for _ in pairs(M.state.lib) do
			lib_count = lib_count + 1
		end
	end
	local cached_paths = vim.tbl_keys(M.state.paths)
	table.sort(cached_paths)
	return {
		expr = M.state.expr,
		toplevel = M.state.toplevel and #M.state.toplevel or 0,
		lib = lib_count,
		builtins = M.state.builtins and #M.state.builtins or 0,
		paths = cached_paths,
		inflight = vim.tbl_keys(M.state.inflight),
		errors = M.state.errors,
	}
end

return M
