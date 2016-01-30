-- entry point to be called from main.c
-- 'file' is relative path to .spy file

local abs = "/usr/local/share/spyre/"

function main(file, output, wd)
    local input = io.open(wd .. "/" .. file, "r")
    local contents = input:read("*all")
    input:close()
	
    local lex = dofile(abs .. "slex.lua")
    local parse = dofile(abs .. "sparse.lua")
    local compile = dofile(abs .. "scompile.lua")
	
	-- first we lex the imports.  we do this so
	-- that lines in included files are preserved
	local tokens = {}

	-- keep a dictionary of included files.  use this
	-- so that the user doesn't need header guards
	-- like they would to in C
	local included = {}

	contents = contents:gsub("using \".-\"", function(match)
		local filename = wd .. "/" .. (file:match("(.+)/.-$") or "") .. "/" .. match:match("\"(.-)\"")
		if included[filename] then
			return ""
		end
		local include = io.open(filename, "r")
		if include then
			included[filename] = true
			local cont = include:read("*all")
			include:close()
			for i, v in ipairs(lex(cont)) do
				table.insert(tokens, v)
			end
		end
		return ""
	end)

	for i, v in ipairs(lex(contents)) do
		table.insert(tokens, v)	
	end
	
	local tree, datatypes = parse(tokens, include)

    return compile(tree, datatypes, wd .. "/" .. output)
end
