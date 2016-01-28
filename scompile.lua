-- Spyre lexer
-- arguments:   abstract syntax tree, datatypes
-- returns:     Spyre bytecode, Spyre const memory
-- gives to:    main.c

-- find . -name '*.c' -o -name '*.h' -o -name '*.lua' -o -name '*.spy' | xargs wc -l

-- TODO LIST
--		type checking (when calling functions, when assigning variables, etc.)
--			tag everything (identifier, number, etc) with a datatype
--			implement typechecking into :compileExpression
--		implement strings
--		implement typeof tags in interpreter

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
    {"SETRET", 0, -1},		{"CCALL", 2, 0}
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

compile.SHOW_COMMENTS = true 

function compile:init(tree, datatypes, output)
    self.tree                   = tree
    self.datatypes              = datatypes
    self.at                     = tree[1]
    self.atblock                = tree[1].block
	self.file					= io.open(output, "w")
    self.offset                 = 0
	self.labels					= 0
    self.done                   = false
	self.should_abort			= false 
	self.current_function		= nil
    self.bytecode               = {}
    self.locals                 = {}
    self.locals[self.atblock]   = {}
	self.queue					= {}
    self.loop_ends              = {}
    self.loop_starts            = {}
    self.funcs                  = {}
	self.const_ptrs				= {}
	self.const_memory			= {}

	setmetatable(self.bytecode, {
		__newindex = function(_, k, v)
			rawset(self.bytecode, k, tostring(v))
		end
	})
end

function compile:throw(msgformat, ...)
    local message = string.format(msgformat, ...)
	self.should_abort = true
    print(string.format("\nSPYRE COMPILE ERROR: \n\tMESSAGE: %s\n\tLINE: %d\n", message, self.at.line))
end

function compile:assertLocal(l, name)
    if not l then
        self:throw("Attempt to use non-existant variable '%s'", name)
    end
end

function compile:pushData(fmt, ...)
	for i, v in ipairs{...} do
		self.file:write(string.pack(fmt, tonumber(v)))
	end
end

function compile:dump()
    local i = 1
	print("BYTECODE:")
    while i <= #self.bytecode do
        local opcode = self:getOpcode(tonumber(self.bytecode[i]))
        if opcode then
			local len = 0
			if opcode[1] ~= "LABEL" then
				io.write("\t")
				len = len + 4
			end
			local len = len + #opcode[1]
			io.write(opcode[1] .. " ")
			local nargs = opcode[2]
			i = i + 1
			for j = 1, nargs do
				len = len + #self.bytecode[i]
				io.write(self.bytecode[i] .. " ")
				i = i + 1
			end
			if self.bytecode[i] and self.bytecode[i]:sub(1, 1) == ";" then
				io.write(string.rep(" ", 23 - len) .. self.bytecode[i])
				i = i + 1
			end
			print()
		else
			i = i + 1
		end
    end
	print("\nCONST MEMORY:")
	for i, v in ipairs(self.const_memory) do
		print(string.format("0x%04x: %s", i - 1, v))
	end
	print("\nCONST MEMORY POINTERS:")
	local i = 0
	for _, v in pairs(self.const_ptrs) do
		print(string.format("0x%04x: 0x%04x", i, v))
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

function compile:push(...)
    local a = {...}
    for i, v in ipairs(a) do
        local hex = self:getHexcode(v)
        if hex then
            table.insert(self.bytecode, hex)
            if v == "CALL" then
                self.offset = self.offset - tonumber(a[i + 2])
			elseif v == "CCALL" then
				self.offset = self.offset - tonumber(a[i + 2]) + 1
            else
                self.offset = self.offset + self:getOpcode(hex)[3]
            end
        else
			if tostring(v):sub(1, 1) ~= ";" then
				table.insert(self.bytecode, v)
			else
				table.insert(self.bytecode, v)
			end
        end
    end
end

function compile:popLocals()
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
end

function compile:comment(msg, ...)
	return string.format("; " .. msg, ...)
end

function compile:writeConstant(const)
	if not self.const_ptrs[const] then
		local ptr = #self.const_memory
		for i = 1, const:len() do
			table.insert(self.const_memory, const:sub(i, i):byte())
		end
		table.insert(self.const_memory, 0)
		self.const_ptrs[const] = ptr
	end
end

function compile:getConstant(const)
	return self.const_ptrs[const]
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
	self:push(table.unpack(table.remove(self.queue, #self.queue)))
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
				identifier = v.word;
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
                    table.insert(node.arguments, expr)
                    expr = {}
                else
                    table.insert(expr, a)
                end
                i = i + 1
            end
            if node.func and #node.func.arguments ~= #node.arguments then
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
    local tops = {}
	local function newtop(t, id)
		table.insert(tops, {t, id})
	end
	local function typecheck()
		local a = table.remove(tops, #tops)
		local b = table.remove(tops, #tops)
		if a[1] ~= b[1] then
			-- TODO implement implicit casting
			self:throw("Attempt to perform arithmetic on two different datatypes ('%s' %s and '%s' %s)", a[1], a[2], b[1], b[2])
		end
		newtop(a[1], a[2])
	end
    local function push(v)
        if v.typeof == "FUNCTION_CALL" then
            for q = #v.arguments, 1, -1 do
				local datatype = self:compileExpression(v.arguments[q])
				if v.func then
					if datatype ~= v.func.arguments[q].datatype then
						self:throw("Attempt to pass argument of type '%s' to function '%s': argument should be of type '%s' (argument %s)",
							datatype,
							v.func.identifier,
							v.func.arguments[q].datatype,
							#v.arguments - q
						)
					end
				end
			end
			-- call spyre function
			if v.func then
				self:push("CALL", v.func.label, #v.func.arguments)
				newtop(v.func.rettype, "(return type from '" .. v.identifier .. "' call")
			-- call C function
			else
				-- C call format:
				-- push arg0
				-- push arg1 ...
				-- push func name pointer
				-- ccall, fptr, numargs
				self:writeConstant(v.identifier)
				local fname = self:getConstant(v.identifier)
				self:push("CCALL", fname, #v.arguments, self:comment("call c function %s", v.identifier))
				newtop("real", fname)
			end
        elseif v.typeof == "IDENTIFIER" then
            local l = self:getLocal(v.word)
            self:assertLocal(l, v.word)
            if l then
                local other = false
                if rpn[i + 1] and rpn[i + 2] then
                    if rpn[i + 1].typeof == "IDENTIFIER" and rpn[i + 2].typeof == "GETMEMBER" then
                        local memoffset = self.datatypes[l.datatype].members[rpn[i + 1].word].offset
                        self:push("PUSHLOCAL", l.offset)
                        self:push("PUSHNUM", memoffset)
                        self:push("ADD")
                        self:push("GETMEM", self:comment("get member %s of local %s (typeof %s)", rpn[i + 1].word, l.identifier, l.datatype))
						newtop(self.datatypes[l.datatype].members[rpn[i + 1].word].datatype.typename, "field " .. rpn[i + 1].word)
                        i = i + 2
                    else
                        other = true
                    end
                else
                    other = true
                end
                if other then
					newtop(l.datatype, l.identifier)
                    self:push("PUSHLOCAL", l.offset)
                end
            end
        elseif v.typeof == "NUMBER" then
			newtop("real", v.word)
            self:push("PUSHNUM", v.word)
		else
			typecheck()
			if v.typeof == "PLUS" then
				self:push("ADD")
			elseif v.typeof == "MINUS" then
				self:push("SUB")
			elseif v.typeof == "MULTIPLY" then
				self:push("MUL")
			elseif v.typeof == "DIVIDE" then
				self:push("DIV")
			elseif v.typeof == "GT" or v.typeof == "GE" or v.typeof == "LT" or v.typeof == "LE" or v.typeof == "EQ" then
				self:push(v.typeof)
			end
		end
    end
    while i <= #rpn do
        push(rpn[i])
        i = i + 1
    end
	return tops[#tops][1]
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
	self:push("PUSHNUM", 0)
    self:pushLocal(self.at)
    local datatype = self:compileExpression(self.at.expression)
	local l = self:getLocal(self.at.identifier)
	if l.datatype == "__INFER__" then
		l.datatype = datatype
	elseif datatype ~= l.datatype then
		self:throw("Attempt to assign an expression with an evaluated type of '%s' to a variable of type '%s'", datatype, l.datatype)
	end
	self:push("SETLOCAL", l.offset)
	self.offset = self.offset + 1
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
            self:push("SETMEM", self:comment("setlocal %s.%s", l.identifier, left[i + 1].word))
            i = i + 2
        elseif left[i].typeof == "IDENTIFIER" then
            local l = self:getLocal(left[i].word)
            self:push("SETLOCAL", l.offset, self:comment("setlocal %s", l.identifier))
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
        self:push("PUSHARG", i - 1, self:comment("load arg %s", self.at.arguments[i].identifier))
        local arg = self.at.arguments[i]
        arg.isarg = true
        self:pushLocal(arg)
    end
    self:addToQueue()
    self.funcs[self.at.identifier] = {
        label = self.labels - 1;
        arguments = self.at.arguments;
		identifier = self.at.identifier;
		rettype = self.at.rettype;
    }
	self.current_function = self.funcs[self.at.identifier]
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

-- TODO cleanup locals 
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
	local datatype;
    if #self.at.expression > 0 then
        datatype = self:compileExpression(self.at.expression)
    else
        self:push("PUSHNUM", 0)
		datatype = "null"
    end
	if datatype ~= self.current_function.rettype then
		self:throw("Return statement in function '%s' evaluated to type '%s': it should evaluate to type '%s'", self.current_function.identifier, datatype, self.current_function.rettype)
	end
	if self.at.condition then
		self:compileExpression(self.at.condition)
		self:push("JIF", self.labels)
		self:push("SETRET")
		self:popLocals()
		self:push("RET")
		self:push("LABEL", self.labels)
		self.labels = self.labels + 1
	else
		self:push("SETRET")
		self:addToFrontCurrentQueue("RET")
	end
end

function compile:branch()
    if self.at.block and self.at.block[1] then
        self.atblock = self.at.block
        self.at = self.at.block[1]
    else
		if not self.at.parent_block then
			self.done = true
			return
		end
        while not self.at.parent_block[self.at.block_index + 1] do
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

	if self.should_abort then
		self.file:flush()
		os.exit()
	end

	if self.funcs.main then
		self:push("CALL", self.funcs.main.label, 0)
		self:push("NULL", "NULL", "NULL")
	else
		table.remove(self.bytecode, 1)
		table.remove(self.bytecode, 1)
	end

	self:dump()

	for i = #self.bytecode, 1, -1 do
		if self.bytecode[i]:sub(1, 1) == ";" then
			table.remove(self.bytecode, i)
		end
	end

	-- header #1, points to the start of the data section
	self:pushData("I", 8)
	-- header #2, points to the start of the code section
	-- note the +1 is for the null termination that is
	-- added to the end of the data section
	self:pushData("I", #self.const_memory * 8 + 8)

	for i, v in ipairs(self.const_memory) do
		self:pushData("d", v)
	end

	for i, v in ipairs(self.bytecode) do
		self:pushData("d", v)
	end
end

return function(tree, datatypes, output)

    local compile_state = setmetatable({}, {__index = compile})


    compile_state:init(tree, datatypes, output)
    compile_state:main()
    --compile_state:dump()


end

