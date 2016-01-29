-- entry point to be called from main.c
-- 'file' is relative path to .spy file
function main(file, output, wd)
    local input = io.open(wd .. "/" .. file, "r")
    local contents = input:read("*all")
    input:close()

    local lex = dofile("slex.lua")
    local parse = dofile("sparse.lua")
    local compile = dofile("scompile.lua")

	contents = contents:gsub("using \".-\"", function(match)
		local include = io.open(wd .. "/" .. (file:match("(.+)/") or file) .. "/" .. match:match("\"(.-)\""), "r")
		if include then
			local cont = include:read("*all")
			include:close()
			return cont
		end
		return ""
	end)

	local tree, datatypes = parse(lex(contents))

    return compile(tree, datatypes, output)
end
