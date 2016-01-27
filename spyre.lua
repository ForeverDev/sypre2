-- entry point to be called from main.c
-- 'file' is relative path to .spy file
function main(file, output)
    local input = io.open(file, "r")
    local contents = input:read("*all")
    input:close()

    local lex = dofile("slex.lua")
    local parse = dofile("sparse.lua")
    local compile = dofile("scompile.lua")

	local tree, datatypes = parse(lex(contents))

    return compile(tree, datatypes, output)
end
