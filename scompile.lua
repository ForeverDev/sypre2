-- Spyre lexer
-- arguments:   abstract syntax tree, datatypes
-- returns:     Spyre bytecode
-- gives to:    main.c

-- find . -name '*.c' -o -name '*.h' -o -name '*.lua' -o -name '*.spy' | xargs wc -l

local compile = {}

-- format: <name> <numargs (-1 = TBD)> <stack offset>
compile.opcodes = {
    {"NULL", 0, 0},         {"PUSHNUM", 1, 1},          {"PUSHSTR", -1, 1},
    {"PUSHPTR", 0, 0},      {"POP", 0, -1},             {"ADD", 0, -1},
    {"SUB", 0, -1},         {"MUL", 0, -1},             {"DIV", 0, -1},
    {"AND", 0, -1},         {"OR", 0, -1},              {"NOT", 0, -1},
    {"EQ", 0, -1},          {"PUSHLOCAL", 1, 1},        {"SETLOCAL", 1, -2},
    {"PUSHARG", 1, 1},      {"CALL", 2, 3},             {"RET", 0, -2},
    {"JMP", 1, 0},          {"JIT", 1, -1},             {"JIF", 1, -1},
    {"MALLOC", 1, 1},       {"SETMEM", 0, -2},          {"GETMEM", 0, 0},
	{"LABEL", 1, 0},		{"GT", 0, -1},				{"GE", 0, -1},
	{"LT", 0, -1},			{"LE", 0, -1},              {"FREE", 0, -1},
    {"SETRET", 0, -1}
}

compile.pres = {

    ["ASSIGN"]      = 0;

	["GT"]			= 1;
	["GE"]			= 1;
	["LT"]			= 1;
	["LE"]			= 1;
	["EQ"]			= 1;

    ["PLUS"]        = 2;
    ["MINUS"]       = 2;

    ["MULTIPLY"]    = 3;
    ["DIVIDE"]      = 3;

    ["GETMEMBER"]   = 50;


}

function compile:init(tree, datatypes)
    self.tree                   = tree
    self.datatypes              = datatypes
    self.at                     = tree[1]
    self.atblock                = tree[1].block
    self.offset                 = 0
	self.labels					= 0
    self.done                   = false
    self.bytecode               = {}
    self.locals                 = {}
    self.locals[self.atblock]   = {}
	self.queue					= {}
    self.loop_ends              = {}
    self.loop_starts            = {}
    self.funcs                  = {}
end

function compile:throw(msgformat, ...)
    local message = string.format(msgformat, ...)
    print(string.format("\nSPYRE COMPILE ERROR: \n\tMESSAGE: %s\n\tLINE: %d\n", message, self.at.line))
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
			if opcode[1] ~= "LABEL" then
				io.write("\t")
			end
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
    n = tonumber(n)
    if n < 0 then
        -- -1 for null pointer
        return string.format("0x%04x", 0xbff0000000000000 + n)
    end
    return string.format("0x%04x", n)
end

function compile:push(...)
    local a = {...}
    for i, v in ipairs(a) do
        local hex = self:getHexcode(v)
        if hex then
            table.insert(self.bytecode, self:toHex(hex))
            if v == "CALL" then
                self.offset = self.offset - tonumber(a[i + 2])
            else
                self.offset = self.offset + self:getOpcode(hex)[3]
            end
        else
            table.insert(self.bytecode, self:toHex(v))
        end
    end
end

function compile:addToQueue(...)
	table.insert(self.queue, {...})
end

function compile:addToCurrentQueue(...)
    for i, v in ipairs{...} do
        table.insert(self.queue[#self.queue], v)
    end
end

function compile:addToFrontCurrentQueue(...)
    local a = {...}
    for i = #a, 1, -1 do
        table.insert(self.queue[#self.queue], 1, a[i])
    end
end


function compile:popFromQueue()
	if #self.queue == 0 then
		return
	end
	self:push(unpack(table.remove(self.queue, #self.queue)))
end

function compile:pushLocal(l)
    l.offset = self.offset
    table.insert(self.locals[self.atblock], l)
end

function compile:getLocal(identifier)
    local now = self.atblock
    while true do
        if not self.locals[now] then
            return nil
        end
        for i, v in ipairs(self.locals[now]) do
            if v.identifier == identifier then
                return v
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
        if v.typeof == "IDENTIFIER" and expression[i + 1] and expression[i + 1].typeof == "OPENPAR" then
            local node = {
                typeof = "FUNCTION_CALL";
                arguments = {};
                func = self.funcs[v.word]
            }
            local args = {}
            local expr = {}
            local count = 1
            i = i + 2
            while count > 0 do
                local a = expression[i]
                if a.typeof == "OPENPAR" then
                    count = count + 1
                elseif a.typeof == "CLOSEPAR" then
                    count = count - 1
                end
                if a.typeof == "COMMA" or count == 0 then
                    table.insert(node.arguments, self:compileExpression(expr, true))
                    expr = {}
                else
                    table.insert(expr, a)
                end
                i = i + 1
            end
            if #node.func.arguments ~= #node.arguments then
                self:throw("Incorrect number of arguments when calling function '%s':  expected %d, got %d", v.word, #node.func.arguments, #node.arguments)
            end
            table.insert(rpn, node)
        elseif v.typeof == "IDENTIFIER" or v.typeof == "NUMBER" or v.typeof == "STRING" then
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

    local i = 1
    local lastp = nil
    local toptype = {
        ["POINTER"] = 1;
        ["NUMBER"] = 2;
    }
    local tops = {}
    local function pop()
        local last = tops[#tops]
        for i = 1, 2 do
            table.remove(tops, #tops)
        end
        table.insert(tops, last)
    end
    local function push(v)
        if v.typeof == "FUNCTION_CALL" then
            for q = #v.arguments, 1, -1 do
                for e, l in ipairs(v.arguments[q]) do
                    push(l)
                end
            end
            self:push("CALL", v.func.label, #v.func.arguments)
        elseif v.typeof == "IDENTIFIER" then
            local l = self:getLocal(v.word)
            self:assertLocal(l, v.word)
            if l then
                local other = false
                if rpn[i + 2] then
                    if rpn[i + 1].typeof == "IDENTIFIER" and rpn[i + 2].typeof == "GETMEMBER" then
                        local memoffset = self.datatypes[l.datatype].members[rpn[i + 1].word].offset
                        self:push("PUSHLOCAL", l.offset)
                        self:push("PUSHNUM", memoffset)
                        self:push("ADD")
                        self:push("GETMEM")
                        i = i + 1
                    else
                        other = true
                    end
                else
                    other = true
                end
                if other then
                    self:push("PUSHLOCAL", l.offset)
                end
            end
        elseif v.typeof == "PLUS" then
            self:push("ADD")
        elseif v.typeof == "MINUS" then
            self:push("SUB")
        elseif v.typeof == "MULTIPLY" then
            self:push("MUL")
		elseif v.typeof == "DIVIDE" then
			self:push("DIV")
		elseif v.typeof == "GT" or v.typeof == "GE" or v.typeof == "LT" or v.typeof == "LE" or v.typeof == "EQ" then
			self:push(v.typeof)
        elseif v.typeof == "NUMBER" then
            self:push("PUSHNUM", v.word)
        end
    end
    while i <= #rpn do
        push(rpn[i])
        i = i + 1
    end
end

function compile:compileVariableDeclaration()
    if self.at.modifiers.new then
        self:push("MALLOC", self.datatypes[self.at.datatype].sizeof)
    else
        self:push("PUSHNUM", 0);
    end
    self:pushLocal(self.at)
end

function compile:compileVariableAssignment()
    self:compileExpression(self.at.expression)
    self:pushLocal(self.at)
end

function compile:compileVariableReassignment()
    self:compileExpression(self.at.right)
    local left = self:compileExpression(self.at.left, true)
    local i = 1
    while i <= #left do
        if left[i].typeof == "IDENTIFIER" and left[i + 2] and left[i + 1].typeof == "IDENTIFIER" and left[i + 2].typeof == "GETMEMBER" then
            local l = self:getLocal(left[i].word)
            self:push("PUSHLOCAL", l.offset)
            self:push("PUSHNUM", self.datatypes[l.datatype].members[left[i + 1].word].offset)
            self:push("ADD")
            self:push("SETMEM")
            i = i + 2
        elseif left[i].typeof == "IDENTIFIER" then
            local l = self:getLocal(left[i].word)
            self:push("SETLOCAL", l.offset)
        end
        i = i + 1
    end
end

function compile:compileIf()
	self:compileExpression(self.at.condition)
	self:push("JIF", self.labels)
	self:addToQueue("LABEL", self.labels)
	self.labels = self.labels + 1
end

function compile:compileWhile()
	self:push("LABEL", self.labels)
    table.insert(self.loop_starts, self.labels)
	self.labels = self.labels + 1
	self:compileExpression(self.at.condition)
	self:push("JIF", self.labels)
	self:addToQueue("JMP", self.labels - 1, "LABEL", self.labels)
    table.insert(self.loop_ends, self.labels)
	self.labels = self.labels + 1
end

function compile:compileFunction()
    self:push("LABEL", self.labels)
    self.labels = self.labels + 1
    self.offset = 0
    for i = 1, #self.at.arguments do
        self:push("PUSHARG", i - 1)
        local arg = self.at.arguments[i]
        arg.isarg = true
        self:pushLocal(arg)
    end
    self:addToQueue()
    self.funcs[self.at.identifier] = {
        label = self.labels - 1;
        arguments = self.at.arguments;
    }
end

function compile:compileContinue()
    if #self.loop_ends == 0 then
        self:throw("The keyword 'continue' can only be used inside of a loop")
    end
    if self.at.condition then
        self:compileExpression(self.at.condition)
        self:push("JIT", self.loop_starts[#self.loop_starts])
    else
        self:push("JMP", self.loop_starts[#self.loop_starts])
    end
end

function compile:compileBreak()
    if #self.loop_ends == 0 then
        self:throw("The keyword 'break' can only be used inside of a loop")
    end
    if self.at.condition then
        self:compileExpression(self.at.condition)
        self:push("JIT", self.loop_ends[#self.loop_ends])
    else
        self:push("JMP", self.loop_ends[#self.loop_ends])
    end
end

function compile:compileReturn()
    if #self.at.expression > 0 then
        self:compileExpression(self.at.expression)
    else
        self:push("PUSHNUM", 0)
    end
    self:push("SETRET")
    self:addToFrontCurrentQueue("RET")
end

function compile:branch()
    if self.at.block and self.at.block[1] then
        self.atblock = self.at.block
        self.at = self.at.block[1]
    else
        while not self.at.parent_block[self.at.block_index + 1] do
            for i = #self.locals[self.at.parent_block], 1, -1 do
                local v = self.locals[self.at.parent_block][i]
                if not v.isarg then
                    local v = self.locals[self.at.parent_block][i]
                    if v.modifiers.strong or v.datatype == "real" then
                        self:push("POP")
                    else
                        self:push("FREE")
                    end
                end
            end
            self.at = self.at.parent_block.parent_chunk
            self.atblock = self.at.parent_block
			self:popFromQueue()
            if not self.at.parent_block then
                while #self.queue > 0 do
                    self:popFromQueue()
                end
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
    elseif t == "VARIABLE_REASSIGNMENT" then
        self:compileVariableReassignment()
	elseif t == "IF" then
		self:compileIf()
	elseif t == "WHILE" then
		self:compileWhile()
    elseif t == "FUNCTION" then
        self:compileFunction()
    elseif t == "CONTINUE" then
        self:compileContinue()
    elseif t == "BREAK" then
        self:compileBreak()
    elseif t == "RETURN" then
        self:compileReturn()
    elseif t == "EXPRESSION" then
        self:compileExpression(self.at.expression)
    end
end

function compile:main()
    self:push("JMP", 0)
    self:addToQueue("LABEL", 0)
    self.labels = 1
    while true do
        self:branch()
        if self.done then
            break
        end
    end
    self:push("PUSHNUM", 0)
    self:push("CALL", self.funcs.main.label, 1)
    self:push("NULL", "NULL", "NULL")
end

return function(tree, datatypes)

    local compile_state = setmetatable({}, {__index = compile})


    compile_state:init(tree, datatypes)
    compile_state:main()
    compile_state:dump()

    return table.concat(compile_state.bytecode, " ")

end

