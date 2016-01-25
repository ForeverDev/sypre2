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
    {"EQ", 0, -1},          {"PUSHLOCAL", 1, 1},        {"SETLOCAL", 0, -2},
    {"PUSHARG", 1, 1},      {"CALL", 2, 3},             {"RET", 0, -3},
    {"JMP", 1, 0},          {"JIT", 1, -1},             {"JIF", 1, -1},
    {"MALLOC", 1, 1},       {"SETMEM", 0, -2},          {"GETMEM", 0, 0},
	{"LABEL", 1, 0},		{"GT", 0, -1},				{"GE", 0, -1},
	{"LT", 0, -1},			{"LE", 0, -1}
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
	self.insert_point			= 1
    self.offset                 = 0
	self.labels					= 0
    self.done                   = false
    self.bytecode               = {}
    self.locals                 = {}
    self.locals[self.atblock]   = {}
	self.queue					= {}
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

function compile:lock()
	self.insert_point = #self.bytecode
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
            table.insert(self.bytecode, self.insert_point, self:toHex(hex))
            self.offset = self.offset + self:getOpcode(hex)[3]
        else
            table.insert(self.bytecode, self.insert_point, self:toHex(v))
        end
		self.insert_point = (self.insert_point or 1) + 1
    end
end

function compile:addToQueue(...)
	table.insert(self.queue, {...})
end

function compile:popFromQueue()
	if #self.queue == 0 then
		return
	end
	self:push(unpack(table.remove(self.queue, #self.queue)))
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
    local function tag(t)
        t.is_being_assigned = true
    end
    local function untag(t)
        t.is_being_assigned = nil
    end
    local function istag(t)
        return t.is_being_assigned
    end
    local isassign = false
    local stop = nil
    for i, v in ipairs(expression) do
        if v.typeof == "ASSIGN" then
            isassign = true
            stop = i - 1
            break
        end
    end
    if isassign then
        for i = 1, stop do
            tag(expression[i])
        end
    end
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
        for i, v in ipairs(expression) do
            untag(v)
        end
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
    while i <= #rpn do
        local v = rpn[i]
        if v.typeof == "IDENTIFIER" then
            local l = self:getLocal(v.word)
            if l then
                lastp = l
            end
            if not l and not lastp then
                self:assertLocal(l, v.word)
            end
            if l then
                local other = false
                if rpn[i + 2] then
                    if rpn[i + 1].typeof == "IDENTIFIER" and rpn[i + 2].typeof == "GETMEMBER" then
                        local memoffset = self.datatypes[l.datatype].members[rpn[i + 1].word].offset
                        self:push("PUSHLOCAL", l.offset)
                        self:push("PUSHNUM", memoffset)
                        self:push("ADD")
                        if istag(v) then
                            table.insert(tops, {top = toptype.POINTER, tok = v})
                        else
                            self:push("GETMEM")
                            table.insert(tops, {top = toptype.NUMBER, tok = v})
                        end
                        i = i + 1
                    else
                        other = true
                    end
                else
                    other = true
                end
                if other then
					if istag(v) then
						self:push("PUSHNUM", l.offset)
					else
						self:push("PUSHLOCAL", l.offset)
					end	
					table.insert(tops, {top = toptype.NUMBER, tok = v})
                end
            end
        elseif v.typeof == "ASSIGN" then
            if not tops[#tops - 1] then
                break
            end
            if tops[#tops - 1].top == toptype.POINTER then
                self:push("SETMEM")
            elseif tops[#tops - 1].top == toptype.NUMBER then
                self:push("SETLOCAL")
            end
            pop()
        elseif v.typeof == "PLUS" then
            pop()
            self:push("ADD")
        elseif v.typeof == "MINUS" then
            pop()
            self:push("SUB")
        elseif v.typeof == "MULTIPLY" then
            pop()
            self:push("MUL")
		elseif v.typeof == "DIVIDE" then
			pop()
			self:push("DIV")
		elseif v.typeof == "GT" or v.typeof == "GE" or v.typeof == "LT" or v.typeof == "LE" or v.typeof == "EQ" then
			pop()
			self:push(v.typeof)
        elseif v.typeof == "NUMBER" then
            table.insert(tops, {top = toptype.NUMBER, tok = v})
            self:push("PUSHNUM", v.word)
        end
        i = i + 1
    end
	for i, v in ipairs(expression) do
		untag(v)
	end

end

function compile:compileVariableDeclaration()
    if self.at.datatype == "real" or self.at.datatype == "string" then
        self:push("PUSHNUM", 0);
    else
        self:push("MALLOC", self.datatypes[self.at.datatype].sizeof)
    end
    self:pushLocal(self.at.identifier, self.at.datatype)
end

function compile:compileVariableAssignment()
    self:compileExpression(self.at.expression)
    self:pushLocal(self.at.identifier, self.at.datatype)
end

function compile:compileIf()
	self:compileExpression(self.at.condition)
	self:push("JIF", self.labels)
	self:addToQueue("LABEL", self.labels)
	self.labels = self.labels + 1
end

function compile:compileWhile()
	self:push("LABEL", self.labels)
	self.labels = self.labels + 1
	self:compileExpression(self.at.condition)
	self:push("JIF", self.labels)
	self:addToQueue("JMP", self.labels - 1, "LABEL", self.labels)
	self.labels = self.labels + 1
end

function compile:branch()
    if self.at.block and self.at.block[1] then
        self.atblock = self.at.block
        self.at = self.at.block[1]
    else
        while not self.at.parent_block[self.at.block_index + 1] do
			for i = 1, #self.locals[self.at.parent_block] do
				self:push("POP")
			end
            self.at = self.at.parent_block.parent_chunk
			self:popFromQueue()
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
	elseif t == "IF" then
		self:compileIf()
	elseif t == "WHILE" then
		self:compileWhile()
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

