-- Spyre lexer
-- arguments:   abstract syntax tree
-- returns:     Spyre bytecode
-- gives to:    main.c

local compile = {}

-- format: <name> <numargs (-1 = TBD)> <stack offset>
compile.opcodes = {
    {"NULL", 0, 0},         {"PUSHNUM", 1, 1},          {"PUSHSTR", -1, 1},
    {"PUSHPTR", 0, 0},      {"POP", 0, -1},             {"ADD", 0, -1},
    {"SUB", 0, -1},         {"MUL", 0, -1},             {"DIV", 0, -1},
    {"AND", 0, -1},         {"OR", 0, -1},              {"NOT", 0, -1},
    {"EQ", 0, -1},          {"PUSHLOCAL", 1, 1},        {"SETLOCAL", 1, -1},
    {"PUSHARG", 1, 1},      {"CALL", 2, 3},             {"RET", 0, -2},
    {"JMP", 1, 0},          {"JIT", 1, -1},             {"JIF", 1, -1}
}

function compile:init(tree)
    self.tree       = tree
    self.at         = tree[1]
    self.done       = false
    self.bytecode   = {}
end

function compile:dump()
    local i = 1
    while i <= #self.bytecode do
        local opcode = self:getOpcode(tonumber(self.bytecode[i]))
        if opcode then
            io.write(opcode[1] .. " ")
            if opcode[2] > 0 then
                for j = 1, opcode[2] do
                    i = i + 1
                    io.write(self.bytecode[i] .. " ")
                end
            end
            print()
        end
        i = i + 1
    end
end

-- gives hexcode from opcode
function compile:getHexcode(opcode)
    for i, v in ipairs(compile.opcodes) do
        if v[1] == opcode then
            return i - 1
        end
    end
    return nil
end

-- gives opcode from hexcode (the whole table)
function compile:getOpcode(hexcode)
    if not tonumber(hexcode) then
        return
    end
    return compile.opcodes[tonumber(hexcode) + 1]
end

function compile:toHex(n)
    return string.format("0x%04x", tonumber(n))
end

function compile:push(...)
    for i, v in ipairs{...} do
        table.insert(self.bytecode, self:toHex(self:getHexcode(v) or v))
    end
end

function compile:expression(expression)

end

function compile:branch()
    if self.at.block and self.at.block[1] then
        self.at = self.at.block[1]
    else
        while not self.at.parent_block[self.at.block_index + 1] do
            self.at = self.at.parent_block.parent_chunk
            if not self.at.parent_block then
                self.done = true
                return
            end
        end
        self.at = self.at.parent_block[self.at.block_index + 1]
    end
    local t = self.at.typeof
    if t == "IF" then

    end
end

function compile:main()
    while true do
        self:branch()
        if self.done then
            break
        end
    end
    self:push("NULL", "NULL", "NULL")
end

return function(tree)

    local compile_state = setmetatable({}, {__index = compile})


    compile_state:init(tree)
    compile_state:main()
    --compile_state:dump()

    return compile_state.bytecode

end

