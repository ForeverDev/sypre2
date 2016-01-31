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
    {"EQ", 0, -1},          {"PUSHLOCAL", 1, 1},        {"SETLOCAL", 1, -1},
    {"PUSHARG", 1, 1},      {"CALL", 2, 3},             {"RET", 0, -2},
    {"JMP", 1, 0},          {"JIT", 1, -1},             {"JIF", 1, -1},
    {"MALLOC", 1, 1},       {"SETMEM", 0, -2},          {"GETMEM", 0, 0},
	{"LABEL", 1, 0},		{"GT", 0, -1},				{"GE", 0, -1},
	{"LT", 0, -1},			{"LE", 0, -1},              {"FREE", 0, -1},
    {"SETRET", 0, -1},		{"CCALL", 3, 0},			{"MOD", 0, -1}
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

	["MODULUS"]		= 3;
    ["MULTIPLY"]    = 3;
    ["DIVIDE"]      = 3;

    ["GETMEMBER"]   = 50;


}

-- storing corefuncs here is necessary because C
-- doesn't do any typechecking at runtime, all
-- typechecking is done at compile time
-- [IDENTIFIER] = { RETTYPE, ARGS }
compile.corefuncs = {
	["println"] = {"real", "..."},
	["print"]	= {"real", "..."},
	
	["max"]		= {"real", "real..."},
	["min"]		= {"real", "real..."},
	["sin"]		= {"real", "real"},
	["cos"]		= {"real", "real"},
	["tan"]		= {"real", "real"},
	["rad"]		= {"real", "real"},
	["deg"]		= {"real", "real"},
	["sqrt"]	= {"real", "real"},
	["map"]		= {"real", "real", "real", "real", "real", "real"},
	["squish"]	= {"real", "real", "real", "real"}
}

compile.SHOW_COMMENTS = true 

function compile:init(tree, datatypes, output, should_dump, filename)
    self.tree                   = tree
    self.datatypes              = datatypes
    self.at                     = tree[1]
    self.atblock                = tree[1].block
	self.should_dump			= should_dump
	self.filename				= filename
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

	for i, v in pairs(compile.corefuncs) do
		self.funcs[i] = {}
		self.funcs[i].is_C = true
		self.funcs[i].identifier = i
		self.funcs[i].rettype = v[1]
		if v[2]:sub(-3, -1) == "..." then
			self.funcs[i].vararg = true
			if v[2]:sub(1, 1) ~= "." then
				self.funcs[i].vararg_type = v[2]:match("(.-)%.%.%.$")
			end
		else
			self.funcs[i].arguments = {}
			for j = 2, #v do
				table.insert(self.funcs[i].arguments, {
					identifier = "?";
					modifiers = {};
					datatype = v[j];	
				})
			end
		end
	end

	setmetatable(self.bytecode, {
		__newindex = function(_, k, v)
			rawset(self.bytecode, k, tostring(v))
		end
	})
end

function compile:throw(msgformat, ...)
    local message = string.format(msgformat, ...)
	self.should_abort = true
    print(string.format("\nSPYRE ERROR: \n\tFILE: %s\n\tMESSAGE: %s\n\tLINE: %d\n", self.filename, message, self.at.line))
	os.exit()
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
	print("LINE" .. string.rep(" ", 7) .. "| BYTECODE" .. string.rep(" ", 23) .. "| COMMENTS")
	for j = 1, 3 do
		print(string.rep(" ", 11) .. "|" .. string.rep(" ", 32) .. "|")
	end
	for i, v in ipairs(self.bytecode) do
		self.bytecode[i] = tostring(v)
	end
    while i <= #self.bytecode do
		local n = self.bytecode[i]:sub(5)
		n = n == "nil" and "" or n
		local towrite = n .. string.rep(" ", 10 - n:len()) .. " | "
		if n ~= "" then
			i = i + 1
		end
        local opcode = self:getOpcode(tonumber(self.bytecode[i]))
        if opcode then
			if towrite then
				io.write(towrite)
			end
			local len = 0
			if opcode[1] ~= "LABEL" then
				io.write("\t")
				len = len + 3
			end
			local len = len + #opcode[1]
			io.write(opcode[1] .. " ")
			local nargs = opcode[2]
			i = i + 1
			for j = 1, nargs do
				local n = tonumber(self.bytecode[i])
				local leading;
				if n then
					leading = (
						n < 2^8 and "02" or
						n < 2^16 and "04" or
						n < 2^32 and "08" or "016"
					)
				end
				local out = string.format("0x%" .. (leading or "02") .. "x", math.floor(n or 0)) .. " "
				len = len + #out
				io.write(out)
				i = i + 1
			end
			io.write(string.rep(" ", 30 - len) .. "|")
			if self.bytecode[i] and self.bytecode[i]:sub(1, 1) == ";" then
				io.write(self.bytecode[i]:sub(2))
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
	table.insert(self.bytecode, "LINE" .. (tostring(self.at.line) or "?"))
    local a = {...}
    for i, v in ipairs(a) do
        local hex = self:getHexcode(v)
        if hex then
            table.insert(self.bytecode, hex)
            if v == "CALL" then
                self.offset = self.offset - tonumber(a[i + 2]) + 1
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
	if not self.locals[self.at.parent_block] then
		return
	end
	for i = #self.locals[self.at.parent_block], 1, -1 do
		local v = self.locals[self.at.parent_block][i]
		if not v.isarg then
			local v = self.locals[self.at.parent_block][i]
			if v.modifiers.strong or v.datatype == "real" then
				self:push("POP", self:comment("pop local %s", v.identifier))
			else
				self:push("FREE", self:comment("free local %s", v.identifier))
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

function compile:addToCurrentQueueBack(...)
    for i, v in ipairs{...} do
        table.insert(self.queue[#self.queue], v)
    end
end

function compile:addToCurrentQueueFront(...)
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

function compile:compileFunctionCall(expression, start)
	local fcall = {
		typeof = "FUNCTION_CALL";
		identifier = expression[start].word;
		func = self.funcs[expression[start].word];
		arguments = {};
	}
	local count = 1
	start = start + 2
	local i = start
    while true do
        if expression[i].typeof == "CLOSEPAR" then
            count = count - 1
            if count == 0 then
                i = i - 1
                break
            end
        elseif expression[i].typeof == "OPENPAR" then
            count = count + 1
        end
        i = i + 1
    end
    -- i is now the last node in the last parameter
    local index = start
    local exp = {}
	local function paste()
		local t = {}
		table.insert(fcall.arguments, t)
		for i, v in ipairs(exp) do
			table.insert(t, v)
		end
		exp = {}
	end
	while index <= i do
		if expression[index].typeof == "IDENTIFIER" and expression[index + 1].typeof == "OPENPAR" then
			local call, newidx = self:compileFunctionCall(expression, index)
			index = newidx
			table.insert(exp, call)
		elseif expression[index].typeof == "COMMA" or expression[index].typeof == "CLOSEPAR" then
			paste()
        else
            table.insert(exp, expression[index])
        end
        index = index + 1
    end
	if #exp > 0 then
		paste()
	end
    -- i + 1 points to the closing parenthesis
    return fcall, i + 1
end

function compile:compileExpression(expression, just_get_rpn, is_rpn)
	local rpn = {}
	local operators = {}
	local i = 1
	while i <= #expression do
		local v = expression[i]
		if v.typeof == "IDENTIFIER" and expression[i + 1] and expression[i + 1].typeof == "OPENPAR" then
			-- FIXME
			local fcall, newidx = self:compileFunctionCall(expression, i)
			i = newidx
			-- parsed correctly, somehow not working
			table.insert(rpn, fcall)
		elseif v.typeof == "IDENTIFIER" or v.typeof == "NUMBER" or v.typeof == "STRING" or v.typeof == "FUNCTION_CALL" then
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
		if b and a[1] ~= b[1] then
			-- TODO implement implicit casting
			self:throw("Attempt to perform arithmetic on two different datatypes ('%s' %s and '%s' %s)", a[1], a[2], b[1], b[2])
		end
		newtop(a[1], a[2])
	end
	local push
    function push(v)
        if v.typeof == "FUNCTION_CALL" then
			if v.func and not v.func.vararg then
				if #v.arguments ~= #v.func.arguments then
					self:throw("incorrect number of arguments when calling function '%s': expected %s, got %s",
						v.identifier,
						#v.func.arguments,
						#v.arguments
					)
				end
			end
			-- TODO fix arg order
			local types = {}
            for q = #v.arguments, 1, -1 do
				local datatype = self:compileExpression(v.arguments[q])
				if v.func and v.func.vararg and v.func.vararg_type then
					if datatype ~= v.func.vararg_type then
						self:throw("Attempt to pass argument of type '%s' to function '%s': argument should be of type '%s' (argument %s)",
							datatype,
							v.func.identifier,
							v.func.vararg_type,
							#v.arguments - q + 1
						)
					end
				elseif v.func and not v.func.vararg then
					if datatype ~= v.func.arguments[q].datatype then
						self:throw("Attempt to pass argument of type '%s' to function '%s': argument should be of type '%s' (argument %s)",
							datatype,
							v.func.identifier,
							v.func.arguments[q].datatype,
							#v.arguments - q + 1
						)
					end
				end
				table.insert(types, datatype)
			end
			-- call spyre function
			if v.func and not v.func.is_C then
				self:push("CALL", v.func.label, #v.func.arguments)
				newtop(v.func.rettype, "(return type from '" .. v.identifier .. "' call)")
			-- call C function
			else
				-- C call format:
				-- push arg0
				-- push arg1 ...
				-- ccall, fptr, numargs, flag_descriptor
				local flag = 0
				local masks = {
					["null"]	= 0x00;
					["real"]	= 0x01;
					["string"]	= 0x02;
					["pointer"] = 0x03;
				}
				for i, v in ipairs(types) do
					flag = (flag | (masks[v] or masks.pointer)) << (i ~= #types and 2 or 0)
				end
				self:writeConstant(v.identifier)
				local fname = self:getConstant(v.identifier)
				self:push("CCALL", fname, #v.arguments, flag, self:comment("call c function %s", v.identifier))
				newtop("real", fname)
			end
		elseif v.typeof == "STRING" then
			self:writeConstant(v.word)
			local ptr = self:getConstant(v.word)
			self:push("PUSHNUM", ptr)
			newtop("string", v.identifier)
        elseif v.typeof == "IDENTIFIER" then
            local l = self:getLocal(v.word)
            self:assertLocal(l, v.word)
            if l then
                local other = false
                if rpn[i + 1] and rpn[i + 2] then
                    if rpn[i + 1].typeof == "IDENTIFIER" and rpn[i + 2].typeof == "GETMEMBER" then
                        local memoffset = self.datatypes[l.datatype].members[rpn[i + 1].word]
						if not memoffset then
							self:throw("Attempt to access field '%s' in a variable of type '%s'", rpn[i + 1].word, l.datatype)
						end
						memoffset = memoffset.offset
                        self:push("PUSHLOCAL", l.offset)
                        self:push("PUSHNUM", memoffset)
                        self:push("ADD")
                        self:push("GETMEM", self:comment("get member %s of local %s (typeof %s)", rpn[i + 1].word, l.identifier, l.datatype))
						newtop(self.datatypes[l.datatype].members[rpn[i + 1].word].datatype, "field " .. rpn[i + 1].word)
                        i = i + 2
                    else
                        other = true
                    end
                else
                    other = true
                end
                if other then
					newtop(l.datatype, l.identifier)
                    self:push("PUSHLOCAL", l.offset, self:comment("load local %s", l.identifier))
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
			elseif v.typeof == "MODULUS" then
				self:push("MOD")
			elseif	v.typeof == "GT" or v.typeof == "GE" or v.typeof == "LT" or v.typeof == "LE" or v.typeof == "EQ" then
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
        self:push("PUSHNUM", 0, self:comment("placeholder for %s", self.at.identifier));
    end
    self:pushLocal(self.at)
end

function compile:compileVariableAssignment()
    local datatype = self:compileExpression(self.at.expression)
    self:pushLocal(self.at)
	local l = self:getLocal(self.at.identifier)
	if l.datatype == "__INFER__" then
		l.datatype = datatype
	elseif datatype ~= l.datatype then
		self:throw("Attempt to assign an expression with an evaluated type of '%s' to a variable of type '%s'", datatype, l.datatype)
	end
	--self:push("SETLOCAL", l.offset, self:comment("setlocal %s", l.identifier))
	--self.offset = self.offset + 1
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
	self:push("JIF", self.labels, self:comment("if"))
	self:addToQueue("LABEL", self.labels)
	self.labels = self.labels + 1
end

function compile:compileWhile()
	self:push("LABEL", self.labels, self:comment("while %d", self.labels))
    table.insert(self.loop_starts, self.labels)
	self.labels = self.labels + 1
	self:compileExpression(self.at.condition)
	self:push("JIF", self.labels)
	self:addToQueue("JMP", self.labels - 1, "LABEL", self.labels, self:comment("end while %d", self.labels - 1))
    table.insert(self.loop_ends, self.labels)
	self.labels = self.labels + 1
end

function compile:compileFunction()
    self:push("LABEL", self.labels, self:comment("implement function %s", self.at.identifier))
    self.labels = self.labels + 1
    self.offset = 0
    for i = 1, #self.at.arguments do
        self:push("PUSHARG", i - 1, self:comment("load arg %s", self.at.arguments[i].identifier))
        local arg = self.at.arguments[i]
        arg.isarg = true
        self:pushLocal(arg)
    end
    --self:addToQueue()
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
		local start = self.at
		self.at = self.at.parent_block.parent_chunk
		while self.at.typeof ~= "WHILE" and self.at.typeof ~= "FOR" do
			self:popLocals()
			if not self.at.parent_block then
				break
			end
			self.at = self.at.parent_block.parent_chunk
		end
		self.at = start
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
		self:addToQueue("RET")
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
			self:popLocals()
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
		self:push("POP", self:comment("pop unused expression"))
    end
end

function compile:optimize()
--[[
	local function push(i, ...)
		local a = {...}
		for j, v in ipairs(a) do
			local hex = self:getHexcode(v)
			if hex then
				table.insert(self.bytecode, i, hex)
			else
				table.insert(self.bytecode, i, v)
			end
		end
	end
	local i = 1
	while i < #self.bytecode do
        local opcode = self:getOpcode(tonumber(self.bytecode[i]))
		local did = false
		if opcode then
			print(opcode[1])
			if self.bytecode[i + 5] then
				local noperand = self:getOpcode(tonumber(self.bytecode[i + 2]))
				local noperator = self:getOpcode(tonumber(self.bytecode[i + 3]))
				if opcode[1] == "PUSHNUM" and nop and nop[1] == "PUSHNUM" then
					local a, b = self.bytecode[i + 1], self.bytecode[i + 3]
					for j = 1, 5 do
						table.remove(self.bytecode, j)
					end
					print(self.bytecode[i + 1], self.bytecode[i + 3])
					push(i, "PUSHNUM", self.bytecode[i + 1] + self.bytecode[i + 3])
					did = true
					i = 0
				end
			end	
			if not did then
				i = i + opcode[2]
			end
		end
		i = i + 1
	end	
--]]
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

	self:optimize()
	if self.should_dump then
		self:dump()
	end

	for i = #self.bytecode, 1, -1 do
		if self.bytecode[i]:sub(1, 1) == ";" or self.bytecode[i]:sub(1, 4) == "LINE" then
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

	self.file:close()
end

return function(tree, datatypes, output, should_dump, filename)

    local compile_state = setmetatable({}, {__index = compile})

    compile_state:init(tree, datatypes, output, should_dump, filename)
    compile_state:main()

end

