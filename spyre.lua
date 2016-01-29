-- entry point to be called from main.c
-- 'file' is relative path to .spy file

local abspath = "/usr/local/bin/spyre/"

function main(file, output, wd)
	print(wd, file)
    local input = io.open(wd .. "/" .. file, "r")
    local contents = input:read("*all")
    input:close()

    local lex = dofile(abspath .. "slex.lua")
    local parse = dofile(abspath .. "sparse.lua")
    local compile = dofile(abspath .. "scompile.lua")


	contents = contents:gsub("using \".-\"", function(match)
		print(file, match)
		local include = io.open(wd .. "/" .. (file:match("(.+)/.-$") or "") .. "/" .. match:match("\"(.-)\""), "r")
		if include then
			local cont = include:read("*all")
			include:close()
			return cont
		end
		return ""
	end)

	print(contents)

	local tree, datatypes = parse(lex(contents))

    return compile(tree, datatypes, output)
end
