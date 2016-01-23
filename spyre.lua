-- entry point to be called from main.c
-- 'file' is relative path to .spy file
function main(file)
    local input = io.open(file, "r")
    local contents = input:read("*all")
    input:close()

    local lex = dofile("slex.lua")
    local parse = dofile("sparse.lua")
    local compile = dofile("scompile.lua")

    return compile(parse(lex(contents)))
end
