-- Spyre lexer
-- arguments:   source file contents
-- returns:     a table of tokens
-- gives to:    sparse.lua

local lex = {}

lex.token_grammar = {
    -- operators
    ["+"]       = "PLUS";
    ["-"]       = "MINUS";
    ["*"]       = "MULTIPLY";
    ["/"]       = "DIVIDE";
    ["%"]       = "MODULUS";
    ["="]       = "REASSIGN";
    [">"]       = "GT";
    ["<"]       = "LT";
    [">="]      = "GE";
    ["<="]      = "LE";
    ["=="]      = "EQ";
    [":="]      = "ASSIGN";
    ["++"]      = "INCREMENT";
    ["--"]      = "DECREMENT";
    ["+="]      = "NADD";
    ["-="]      = "NSUB";
    ["*="]      = "NMUL";
    ["/="]      = "NDIV";
    ["%="]      = "NMOD";
    -- expression control
    ["("]       = "OPENPAR";
    [")"]       = "CLOSEPAR";
    ["["]       = "OPENSQ";
    ["]"]       = "CLOSESQ";
    ["{"]       = "OPENCURL";
    ["}"]       = "CLOSECURL";
    [";"]       = "SEMICOLON";
    [","]       = "COMMA";
    -- keywords
    ["func"]    = "FUNCTION";
    ["if"]      = "IF";
    ["while"]   = "WHILE";
    ["for"]     = "FOR";
    ["defer"]   = "DEFER";
    ["return"]  = "RETURN";
    ["break"]   = "BREAK";
    ["local"]   = "MODIFIER";
    ["global"]  = "MODIFIER";
    ["const"]   = "MODIFIER";
    ["mut"]     = "MODIFIER";
}

function lex:init(contents)
    self.source         = contents
    self.index          = 1
    self.line           = 1
    self.tokens         = {}
end

function lex:throw(msgformat, ...)
    local message = string.format(msgformat, ...)
    print(string.format("\nSPYRE LEX ERROR: \n\tMESSAGE: %s\n\tLINE: %d\n", message, self.line))
    error()
end

function lex:inc(i)
    self.index = self.index + (i or 1)
end

function lex:dec(i)
    self.index = self.index - (i or 1)
end

function lex:peek(i)
    return self.source:sub(self.index + i, self.index + i)
end

function lex:space()
    return self.index <= self.source:len()
end

function lex:getchar()
    return self.source:sub(self.index, self.index)
end

function lex:pushtoken(word)
    local token = {}
    token.word = word
    token.line = self.line
    for i, v in pairs(lex.token_grammar) do
        if word == i then
            token.typeof = v
        end
    end
    if not token.typeof then
        if tonumber(word) then
            token.typeof = "NUMBER"
        elseif word:sub(1, 1) == "\"" and word:sub(-1, -1) == "\"" then
            token.typeof = "STRING"
            token.word = word:sub(2, -2)
        else
            token.typeof = "ID"
        end
    end
    table.insert(self.tokens, token)
end

function lex:dump()
    for i, v in ipairs(self.tokens) do
        print(string.format("0x%04x:", i))
        print("\ttype: " .. v.typeof)
        print("\tword: " .. v.word)
        print("\tline: " .. v.line)
    end
end

function lex:generate()

    while self:space() do
        local c = self:getchar()
        if c ~= " " then
            -- newline
            if c == "\n" then
                self.line = self.line + 1
            -- string
            elseif c == "\"" then
                local str = c
                self:inc()
                c = self:getchar()
                while c ~= "\"" do
                    c = self:getchar()
                    str = str .. c
                    self:inc()
                end
                self:pushtoken(str)
            -- operator
            elseif c:match("%p") or c == ";" then
                local nxt = self:peek(1)
                if lex.token_grammar[c .. nxt] then
                    -- found double operator
                    self:pushtoken(c .. nxt)
                    self:inc()
                else
                    self:pushtoken(c)
                end
            -- number
            elseif c:match("%d") then
                local num = ""
                while c:match("%d") or c == "." do
                    num = num .. c
                    self:inc()
                    c = self:getchar()
                end
                self:pushtoken(num)
                self:dec()
            -- keyword or identifier
            else
                local id = ""
                while (c:match("%a") or c == "_") and c ~= " " do
                    id = id .. c
                    self:inc()
                    c = self:getchar()
                end
                if id ~= "" then
                    self:pushtoken(id)
                    self:dec()
                end
            end
        end
        self:inc()
    end

end

return function(contents)

    local lex_state = setmetatable({}, {__index = lex})

    lex_state:init(contents)
    lex_state:generate()
    lex_state:dump()

    return lex_state.tokens

end
