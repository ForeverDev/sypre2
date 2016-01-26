-- Spyre lexer
-- arguments:   table of tokens
-- returns:     abstract syntax tree
-- gives to:    scompile.lua

local parse = {}

function parse:init(tokens)
    self.tree               = {}
    self.index              = 1
    self.tokens             = tokens
    self.curblock           = nil
    self.datatypes = {
        ["real"]            = {sizeof = 1};
        ["string"]          = {sizeof = 1};
        ["null"]            = {sizeof = 1};
    }

    local root              = {}
    root.typeof             = "ROOT"
    root.block_index        = 1
    root.block              = {}
    root.block.parent_chunk = root
    self.tree[1]            = root
    self.root               = root
    self.curblock           = root.block
end

function parse:inc(i)
    self.index = self.index + (i or 1)
end

function parse:dec(i)
    self.index = self.index - (i or 1)
end

function parse:peek(i)
    return self.tokens[i + 1]
end

function parse:gettok(i)
    return self.tokens[i or self.index]
end

function parse:space()
    return self.index <= #self.tokens
end

function parse:throw(msgformat, ...)
    local message = string.format(msgformat, ...)
    local token = self:gettok()
    print(string.format("\nSPYRE PARSE ERROR: \n\tMESSAGE: %s\n\tLINE: %s\n", message, token and tostring(token.line) or "?"))
    os.exit()
end

function parse:checkDatatype(datatype)
    if not self.datatypes[datatype] then
        self:throw("Unknown datatype '%s'", datatype)
    end
end

function parse:createChunk(typeof, has_block)
    local chunk = {}
    chunk.typeof = typeof
    chunk.line = self:gettok().line
    chunk.block = has_block and {parent_chunk = chunk} or nil
    chunk.parent_block = self.curblock
    chunk.block_index = #self.curblock + 1
    return chunk
end

function parse:pushIntoCurblock(chunk)
    table.insert(self.curblock, chunk)
end

function parse:jumpIntoBlock(block)
    self.curblock = block
end

function parse:parseExpressionUntil(dec, inc)
    -- exprects to be on first token of expression
    if self:gettok().typeof == "SEMICOLON" then
        return {}, ""
    end
    local count = 1
    local expression = {}
    local raw = ""
    while self:space() do
        local t = self:gettok()
        if t.typeof == dec then
            count = count - 1
            if count == 0 then
                break
            end
        elseif inc and t.typeof == inc then
            count = count + 1
        end
        table.insert(expression, t)
        raw = raw .. t.word .. " "
        self:inc()
    end
    -- now sits on the last token of the expression
    return expression, raw
end

function parse:parseIf()
    self:inc()
    local chunk = self:createChunk("IF", true)
    -- jump onto first token in expression
    local cond, raw = self:parseExpressionUntil("OPENCURL", nil)
    chunk.condition = cond
    chunk.condition.raw = raw
    self:pushIntoCurblock(chunk)
    self:jumpIntoBlock(chunk.block)
    -- ends on {
end

function parse:parseWhile()
    self:inc()
    local chunk = self:createChunk("WHILE", true)
    -- jump onto first token in expression
    local condition, raw = self:parseExpressionUntil("OPENCURL", nil)
    chunk.condition = condition
    chunk.condition.raw = raw
    self:pushIntoCurblock(chunk)
    self:jumpIntoBlock(chunk.block)
    self:dec()
    -- ends on {
end

function parse:parseFor()
    self:inc()
    local chunk = self:createChunk("FOR", true)
    local assignment, raw = self:parseExpressionUntil("SEMICOLON", nil)
    chunk.assignment = assignment
    chunk.assignment.raw = raw
    self:inc()
    local condition, raw = self:parseExpressionUntil("SEMICOLON", nil)
    chunk.condition = condition
    chunk.condition.raw = raw
    self:inc()
    local statement, raw = self:parseExpressionUntil("OPENCURL", nil)
    chunk.statement = statement
    chunk.statement.raw = raw
    self:pushIntoCurblock(chunk)
    self:jumpIntoBlock(chunk.block)
    self:dec()
end

function parse:parseFunc()
    self:inc()
    local chunk = self:createChunk("FUNCTION", true)
    chunk.arguments = {}
    chunk.nargs = 0
    chunk.identifier = self:gettok().word
    self:inc(2)
    chunk.rettype = self:gettok().word
    self:checkDatatype(chunk.rettype)
    self:inc(3)
    local args, raw = self:parseExpressionUntil("CLOSEPAR", nil)
    local i = 1
    while i <= #args do
        local arg = {}
        arg.modifiers = {}
        while args[i].typeof == "MODIFIER" do
            arg.modifiers[args[i].word] = true
            i = i + 1
        end
        arg.identifier = args[i].word
        -- skip semicolon
        i = i + 2
        arg.datatype = args[i].word
        arg.offset = #chunk.arguments + 1
        self:checkDatatype(arg.datatype)
        i = i + 1
        table.insert(chunk.arguments, arg)
        if i > #args or args[i].typeof == "CLOSEPAR" then
            break
        end
        i = i + 1
    end
    self:inc(1)
    self:pushIntoCurblock(chunk)
    self:jumpIntoBlock(chunk.block)
    self:dec()
end

-- struct members are in the form of
-- {
--      identifier = <name>;
--      datatype = <datatype>;
-- }
function parse:parseStruct()
    self:inc()
    local typename = self:gettok().word
    local sizeof = 0
    local members = {}
    self:inc(2)
    local finish = self:parseExpressionUntil("CLOSECURL", "OPENCURL")
    local i = 1
    while i <= #finish do
        local v = finish[i]
        if self.datatypes[v.word] then
            local memid = finish[i + 1]
            if not memid or memid.typeof ~= "IDENTIFIER" then
                self:throw(
                    "In declaration of 'struct %s', expected identifier for member with datatype '%s', got non-id '%s'",
                    typename,
                    v.word,
                    memid and "null" or memid.word
                )
            end
            members[finish[i + 1].word] = {
                datatype = v.word;
                identifier = finish[i + 1].word;
                offset = sizeof;
            }
            sizeof = sizeof + 1
            i = i + 2
            if not finish[i] or finish[i].typeof ~= "SEMICOLON" then
                self:throw("Expected ';' to close declaration of member '%s' of struct '%s'", memid.word, typename)
            end
        elseif v.typeof == "STRUCT" then
            self:throw(
                "Embedded structs are currently not supported: (struct '%s' embedded in struct '%s')",
                finish[i + 1] and finish[i + 1].word or "?",
                typename
            )
        else
            i = i + 1
        end
    end
    if sizeof == 0 then
        self:throw("Struct '%s' must have at least one member", typename)
    end
    self.datatypes[typename] = {
        sizeof = sizeof;
        members = members;
    }
end

-- syntax possibilities:
--   <modifier*> x : datatype;          (declaration)
--   <modifier*> x : datatype = 10;     (assignment)
--   <modifier*> x := 10;               (assignment, compiler infers datatype)
function parse:parseDeclaration()
    local modifiers = {}
    while self:gettok().typeof == "MODIFIER" do
        modifiers[self:gettok().word] = true
        self:inc()
    end
    local identifier = self:gettok().word
    -- skip over colon
    self:inc(2)
    local datatype = self:gettok()
    local found_datatype = nil
    if datatype.typeof == "ASSIGN" then
        -- if we reached here, the user used the ':=' assignment
        -- operator and wants us to determine the datatype
        found_datatype = "__INFER__"
    else
        -- if we reached here, the user specified the datatype
        self:checkDatatype(datatype.word)
        found_datatype = datatype.word
        self:inc()
    end
    local now = self:gettok()
    local chunk;
    if now.typeof == "SEMICOLON" then
        -- if we reached here, the user just declared the variable
        chunk = self:createChunk("VARIABLE_DECLARATION", false)
        chunk.identifier = identifier
        chunk.datatype = found_datatype
        chunk.modifiers = modifiers
    else
        -- else, the user is assigning the variable to the
        -- result of an expression
        self:inc()
        chunk = self:createChunk("VARIABLE_ASSIGNMENT", false)
        chunk.identifier = identifier
        chunk.datatype = found_datatype
        chunk.expression, raw = self:parseExpressionUntil("SEMICOLON", nil)
        chunk.expression.raw = raw
        chunk.modifiers = modifiers
    end
    if (modifiers.strong or modifiers.weak) and chunk.datatype == "real" then
        self:throw("Attempt to make variable '%s' strong or weak:  non-pointer types cannot be made strong or weak", chunk.identifier)
    end
    self:pushIntoCurblock(chunk)
end

function parse:dump(chunk, tabs)
    chunk = chunk or self.root
    tabs = tabs or 0
    local tab = string.rep("\t", tabs)
    if chunk.typeof then
        print(tab .. "type: " .. chunk.typeof)
    end
    for i, v in pairs(chunk) do
        if i ~= "block" and i ~= "typeof" and i ~= "parent_block" and type(v) ~= "table" then
            print(tab .. i .. ": " .. tostring(v))
        end
    end
    for i, v in pairs(chunk) do
        if i ~= "block" and i ~= "typeof" and i ~= "parent_block" and type(v) == "table" then
            if v.raw then
                print(tab .. i .. ": " .. v.raw)
            else
                print(tab .. i .. ": {")
                self:dump(v, tabs + 1)
                print(tab .. "}")
            end
        end
    end
    if chunk.block then
        print(tab .. "block: {")
        for i, v in ipairs(chunk.block) do
            self:dump(v, tabs + 1)
        end
        print(tab .. "}")
    end
    print()
end

function parse:main()

    while self:space() do
        local t = self:gettok()
        if t.typeof == "IF" then
            self:parseIf()
        elseif t.typeof == "WHILE" then
            self:parseWhile()
        elseif t.typeof == "FOR" then
            self:parseFor()
        elseif t.typeof == "FUNCTION" then
            self:parseFunc()
        elseif t.typeof == "STRUCT" then
            self:parseStruct()
        elseif t.typeof == "CLOSECURL" then
            self:jumpIntoBlock(self.curblock.parent_chunk.parent_block)
        -- break can have an optional expression after it.  If it evaluates to true, loop WILL break
        elseif t.typeof == "RETURN" then
            self:inc()
            local chunk = self:createChunk(t.typeof, false)
            local expression, raw = self:parseExpressionUntil("SEMICOLON", nil)
            chunk.expression = expression
            chunk.expression.raw = raw
            self:pushIntoCurblock(chunk)
        elseif t.typeof == "BREAK" or t.typeof == "CONTINUE" then
            local chunk = self:createChunk(t.typeof, false)
            if self.tokens[self.index + 1].typeof == "IF" then
                self:inc(2)
                local condition, raw = self:parseExpressionUntil("SEMICOLON", nil)
                chunk.condition = condition
                chunk.condition.raw = raw
            end
            self:pushIntoCurblock(chunk)
        elseif t.typeof == "MODIFIER" or (t.typeof == "IDENTIFIER" and self.tokens[self.index + 1] and self.tokens[self.index + 1].typeof == "COLON") then
            self:parseDeclaration()
        elseif t.typeof ~= "OPENCURL" then
            local expression, raw = self:parseExpressionUntil("SEMICOLON", nil)
            if #expression > 0 then
                local equals = nil
                for i, v in ipairs(expression) do
                    if v.typeof == "ASSIGN" then
                        equals = i
                        break
                    end
                end
                if equals then
                    local left = {}
                    local right = {}
                    for i = 1, equals - 1 do
                        table.insert(left, expression[i])
                    end
                    for i = equals + 1, #expression do
                        table.insert(right, expression[i])
                    end
                    local chunk = self:createChunk("VARIABLE_REASSIGNMENT", false)
                    chunk.left = left
                    chunk.right = right
                    chunk.expression = {raw = raw}
                    self:pushIntoCurblock(chunk)
                else
                    local chunk = self:createChunk("EXPRESSION", false)
                    chunk.expression = expression
                    chunk.expression.raw = raw
                    self:pushIntoCurblock(chunk)
                end
            end
        end
        self:inc()
    end

end

return function(tokens)

    local parse_state = setmetatable({}, {__index = parse})

    parse_state:init(tokens)
    parse_state:main()

    return parse_state.tree, parse_state.datatypes

end
