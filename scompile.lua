-- Spyre lexer
-- arguments:   abstract syntax tree, datatypes
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
    {"PUSHARG", 1, 1},      {"CALL", 2, 3},             {"RET", 0, -3},
    {"JMP", 1, 0},          {"JIT", 1, -1},             {"JIF", 1, -1},
    {"MALLOC", 1, 1},       {"SETMEM", 0, -2}
}

compile.pres = {

    ["ASSIGN"]      = 0;

    ["PLUS"]        = 1;
    ["MINUS"]       = 1;

    ["MULTIPLY"]    = 2;
    ["DIVIDE"]      = 2;


}

function compile:init(tree, datatypes)
    self.tree                   = tree
    self.datatypes              = datatypes
    self.at                     = tree[1]
    self.atblock                = tree[1].block
    self.offset                 = 0
    self.done                   = false
    self.bytecode               = {}
    self.locals                 = {}
    self.locals[self.atblock]   = {}
end

function compile:throw(msgformat, ...)
    local message = string.format(msgformat, ...)
    print(string.format("\nSPYRE COMPILE ERROR: \n\tMESSAGE: %s\n", message))
    os.exit()
end

function compile:assertLocal(l, name)
    if not l then
        self:throw("Attempt to use non-existant variable '%s'", name)
    end
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
        local hex = self:getHexcode(v)
        if hex then
            table.insert(self.bytecode, self:toHex(hex))
            self.offset = self.offset + self:getOpcode(hex)[3]
        else
            table.insert(self.bytecode, self:toHex(v))
        end
    end
end

function compile:pushLocal(identifier, datatype)
    table.insert(self.locals[self.atblock], {
        identifier = identifier,
        offset = self.offset,
        datatype = datatype
    })
end

function compile:getLocal(identifier)
    local now = self.atblock
    while true do
        if not self.locals[now] then
            return nil
        end
        for i, v in ipairs(self.locals[now]) do
            if v.identifier == identifier then
                return v.offset
            end
        end
        if not now.parent_chunk then
            return nil
        end
        now = now.parent_chunk.parent_block
    end
end

function compile:compileExpression(expression, just_get_rpn)
    local rpn = {}
    local operators = {}
    local i = 1
    while i <= #expression do
        local v = expression[i]
        if v.typeof == "IDENTIFIER" or v.typeof == "NUMBER" or v.typeof == "STRING" then
            table.insert(rpn, v)
        elseif v.typeof == "OPENPAR" then
            table.insert(operators, v)
        elseif compile.pres[v.typeof] then
            while #operators > 0 and operators[#operators].typeof ~= "OPENPAR" and compile.pres[v.typeof] <= compile.pres[operators[#operators].typeof] do
                table.insert(rpn, table.remove(operators, #operators))
            end
            table.insert(operators, v)
        elseif v.typeof == "CLOSEPAR" then
            while #operators > 0 and operators[#operators].typeof ~= "OPENPAR" do
                table.insert(rpn, table.remove(operators, #operators))
            end
            table.remove(operators, #operators)
        end
        i = i + 1
    end
    while #operators > 0 do
        table.insert(rpn, table.remove(operators, #operators))
    end
    if just_get_rpn then
        return rpn
    end
    local queue = {}
    local hasop = false
    local function figure(v)
        local args = {}
        if hasop then
            args[1] = table.remove(queue, #queue)
        else
            args[1] = table.remove(queue, #queue)
            args[2] = table.remove(queue, #queue)
            hasop = true
        end
        for q, k in ipairs(args) do
            if k.typeof == "IDENTIFIER" then
                self:push("PUSHLOCAL", self:getLocal(k.word))
            elseif k.typeof == "NUMBER" then
                self:push("PUSHNUM", k.word)
            end
        end
        local op = (
            v.typeof == "PLUS" and "ADD" or
            v.typeof == "MINUS" and "SUB" or
            v.typeof == "MULTIPLY" and "MUL" or
            v.typeof == "DIVIDE" and "DIV" or nil
        )
        if op then
            self:push(op)
        end
    end
    local function push(v)
        local t = v.typeof
        if t == "IDENTIFIER" or t == "NUMBER" or t == "STRING" then
            table.insert(queue, v)
        else
            if t == "ASSIGN" then
                if hasop then
                    local a = table.remove(queue, #queue)
                    local l = self:getLocal(a.word)
                    self:assertLocal(l, a.word)
                    self:push("SETLOCAL", l)
                    --self:push("PUSHLOCAL", l)
                else
                    local b = table.remove(queue, #queue)
                    local a = table.remove(queue, #queue)
                    if b.typeof == "NUMBER" then
                        self:push("PUSHNUM", b.word)
                    elseif b.typeof == "IDENTIFIER" then
                        local l = self:getLocal(b.word)
                        self:assertLocal(l, b.word)
                        self:push("PUSHLOCAL", l)
                    end
                    local l = self:getLocal(a.word)
                    self:assertLocal(l, a.word)
                    self:push("SETLOCAL", l)
                end
            else
                figure(v)
            end
            hasop = true
        end
    end
    if #rpn == 1 then
        table.insert(queue, rpn[1])
        figure(rpn[1])
        return
    end
    for i, v in ipairs(rpn) do
        push(v)
    end
    for i, v in ipairs(queue) do
        figure(v)
    end
end

function compile:compileVariableDeclaration()
    self:push("PUSHNUM", 0);
    self:pushLocal(self.at.identifier, self.at.datatype)
end

function compile:compileVariableAssignment()
    self:compileExpression(self.at.expression);
    self:pushLocal(self.at.identifier, self.at.datatype)
end

function compile:branch()
    if self.at.block and self.at.block[1] then
        self.atblock = self.at.block
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
    if not self.locals[self.atblock] then
        self.locals[self.atblock] = {}
    end
    local t = self.at.typeof
    if t == "VARIABLE_DECLARATION" then
        self:compileVariableDeclaration()
    elseif t == "VARIABLE_ASSIGNMENT" then
        self:compileVariableAssignment()
    elseif t == "EXPRESSION" then
        self:compileExpression(self.at.expression)
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

return function(tree, datatypes)

    local compile_state = setmetatable({}, {__index = compile})


    compile_state:init(tree, datatypes)
    compile_state:main()
    compile_state:dump()

    return table.concat(compile_state.bytecode, " ")

end

