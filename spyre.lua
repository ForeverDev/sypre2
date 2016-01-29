-- entry point to be called from main.c
-- 'file' is relative path to .spy file
function main(file, output)
    local input = io.open(file, "r")
    local contents = input:read("*all")
    input:close()

    local lex = dofile("slex.lua")
    local parse = dofile("sparse.lua")
    local compile = dofile("scompile.lua")

	contents = contents:gsub("#using \".-\"", function(match)
		local include = io.open(match:match("\"(.-)\""), "r")
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
