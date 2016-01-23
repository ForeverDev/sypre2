-- Spyre lexer
-- arguments:   table of tokens
-- returns:     abstract syntax tree
-- gives to:    scompile.lua

local parse = {}

function parse:init(tokens)
    self.tree       = {}
    self.index      = 1
    self.tokens     = tokens
    self.curblock   = nil

    local root      = {}
    root.typeof     = "ROOT"
    root.block      = {parent_chunk = root}
    self.tree[1]    = root
    self.root       = root
    self.curblock   = root.block
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
    print(string.format("\nSPYRE PARSE ERROR: \n\tMESSAGE: %s\n\tLINE: %d\n", message, self:gettok().line))
    error()
end

function parse:createChunk(typeof, has_block)
    local chunk = {}
    chunk.typeof = typeof
    chunk.block = has_block and {parent_chunk = chunk} or nil
    chunk.parent_block = self.curblock
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
    local args, raw = self:parseExpressionUntil("OPENCURL", nil)
    local i = 1
    while true do
        if args[i].typeof ~= "ID" then
            self:throw("Expected function parameter name, got %s", args[i].typeof)
        end
        table.insert(chunk.arguments, args[i])
        chunk.nargs = chunk.nargs + 1
        i = i + 1
        if not args[i] then
            break
        elseif args[i].typeof ~= "COMMA" then
            self:throw("Expected comma in function parameter list, got %s", args[i].typeof)
        end
        i = i + 1
    end
    self:pushIntoCurblock(chunk)
    self:jumpIntoBlock(chunk.block)
    self:dec()
end

function parse:dump(chunk, tabs)
    chunk = chunk or self.root
    tabs = tabs or 0
    local tab = string.rep("\t", tabs)
    print(tab .. "type: " .. chunk.typeof)
    for i, v in pairs(chunk) do
        if i ~= "block" and i ~= "typeof" and i ~= "parent_block" then
            if type(v) == "table" then
                if v.raw then
                    print(tab .. i .. ": " .. v.raw)
                else
                    io.write(tab .. i .. ": ")
                    for j, k in pairs(v) do
                        io.write(k.typeof .. " ")
                    end
                    print()
                end
            else
                print(tab .. i .. ": " .. v)
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
        elseif t.typeof == "CLOSECURL" then
            self:jumpIntoBlock(self.curblock.parent_chunk.parent_block)
        -- break can have an optional expression after it.  If it evaluates to true, loop WILL break
        elseif t.typeof == "RETURN" or t.typeof == "BREAK" then
            self:inc()
            local chunk = self:createChunk(t.typeof, false)
            local expression, raw = self:parseExpressionUntil("SEMICOLON", nil)
            chunk.expression = expression
            chunk.expression.raw = raw
            self:pushIntoCurblock(chunk)
        elseif t.typeof ~= "OPENCURL" then
            local expression, raw = self:parseExpressionUntil("SEMICOLON", nil)
            if #expression > 0 then
                local chunk = self:createChunk("EXPRESSION", false)
                chunk.expression = expression
                chunk.expression.raw = raw
                self:pushIntoCurblock(chunk)
            end
        end
        self:inc()
    end

end

return function(tokens)

    local parse_state = setmetatable({}, {__index = parse})

    parse_state:init(tokens)
    parse_state:main()
    parse_state:dump()

    return parse_state.tree

end
