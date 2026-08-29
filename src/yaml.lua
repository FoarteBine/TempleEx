--[[
    TempleEx YAML Parser (minimal subset for config/theme files)
    Supports: mappings, sequences, scalars (strings, numbers, bools, null), comments preservation (best-effort)
    Does NOT support: anchors/aliases, flow styles, complex types, directives
]]

local YAML = {}

-- Trim whitespace
local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- Check if line is comment or empty
local function isCommentOrEmpty(line)
    local t = trim(line)
    return t == "" or t:sub(1,1) == "#"
end

-- Parse a scalar value (string, number, bool, null)
local function parseScalar(value)
    value = trim(value)
    -- Null
    if value == "null" or value == "~" or value == "" then
        return nil
    end
    -- Boolean
    if value == "true" or value == "yes" or value == "on" then
        return true
    end
    if value == "false" or value == "no" or value == "off" then
        return false
    end
    -- Number
    local num = tonumber(value)
    if num then
        return num
    end
    -- String (strip quotes if present)
    if value:sub(1,1) == '"' and value:sub(-1) == '"' then
        return value:sub(2, -2):gsub('\\"', '"'):gsub('\\\\', '\\')
    end
    if value:sub(1,1) == "'" and value:sub(-1) == "'" then
        return value:sub(2, -2):gsub("''", "'")
    end
    return value
end

-- Parse YAML content into Lua table
-- Returns (table, errors[])
function YAML.parse(content)
    local lines = {}
    for line in content:gmatch("([^\n]*)\n?") do
        table.insert(lines, line)
    end

    local root = {}
    local stack = {{ indent = -1, node = root, key = nil, isArray = false }}
    local errors = {}
    local lineNum = 0

    local function currentContext()
        return stack[#stack]
    end

    local function pushContext(indent, node, key, isArray)
        table.insert(stack, { indent = indent, node = node, key = key, isArray = isArray })
    end

    local function popContext()
        table.remove(stack)
    end

    local function addValue(parent, key, value, isArrayItem)
        if isArrayItem then
            table.insert(parent, value)
        else
            parent[key] = value
        end
    end

    while lineNum < #lines do
        lineNum = lineNum + 1
        local line = lines[lineNum]
        local rawLine = line

        -- Preserve leading spaces for indent calculation
        local indent = 0
        while line:sub(indent + 1, indent + 1) == " " do
            indent = indent + 1
        end
        local content = trim(line:sub(indent + 1))

        if isCommentOrEmpty(content) then
            -- Skip comments for now (could store for round-trip later)
        else
            -- Handle sequence item (starts with "- ")
            local isArrayItem = false
            local itemContent = content
            if content:sub(1, 2) == "- " then
                isArrayItem = true
                itemContent = trim(content:sub(3))
            end

            -- Find appropriate parent context
            while #stack > 0 and currentContext().indent >= indent do
                popContext()
            end

            local ctx = currentContext()
            if not ctx then
                table.insert(errors, "Line " .. lineNum .. ": Indent error")
                break
            end

            if itemContent:find(":", 1, true) then
                -- Key-value pair
                local key, val = itemContent:match("^([^:]+):%s*(.*)$")
                key = trim(key)
                val = trim(val)

                if val == "" or val == "{" or val == "[" then
                    -- Nested object/array - create new table
                    local newNode = {}
                    addValue(ctx.node, ctx.key, newNode, ctx.isArray and not ctx.key)
                    if ctx.isArray and not ctx.key then
                        -- We're in an array, the new node is the array item
                        ctx.key = #ctx.node
                    else
                        ctx.key = key
                    end
                    ctx.isArray = false
                    pushContext(indent, newNode, key, false)
                else
                    -- Simple value
                    local parsed = parseScalar(val)
                    addValue(ctx.node, key, parsed, isArrayItem)
                end
            else
                -- Just a value (array item without key)
                if isArrayItem then
                    local parsed = parseScalar(itemContent)
                    addValue(ctx.node, nil, parsed, true)
                else
                    -- Could be a bare string key for next line? Unlikely in our subset.
                    table.insert(errors, "Line " .. lineNum .. ": Unexpected format: " .. content)
                end
            end
        end
    end

    -- Handle inline arrays/objects (very basic)
    -- For our use case, we keep it simple.

    return root, errors
end

-- Serialize Lua table to YAML (basic, no comment preservation)
function YAML.stringify(tbl, indent)
    indent = indent or 0
    local spaces = string.rep("  ", indent)
    local lines = {}

    local function isArray(t)
        if type(t) ~= "table" then return false end
        local max = 0
        for k, _ in pairs(t) do
            if type(k) == "number" and k > 0 then
                max = math.max(max, k)
            else
                return false
            end
        end
        return max > 0 and max == #t
    end

    local function formatValue(v)
        if v == nil then
            return "null"
        elseif type(v) == "boolean" then
            return v and "true" or "false"
        elseif type(v) == "number" then
            return tostring(v)
        elseif type(v) == "string" then
            -- Quote if contains special chars or looks like number/bool
            if v:match("^[%w_%-%.]+$") and not v:match("^%d") and v ~= "true" and v ~= "false" and v ~= "null" then
                return v
            end
            return '"' .. v:gsub('"', '\\"'):gsub("\\", "\\\\") .. '"'
        else
            return "null"
        end
    end

    if isArray(tbl) then
        for _, v in ipairs(tbl) do
            if type(v) == "table" then
                table.insert(lines, spaces .. "-")
                for _, subLine in ipairs(YAML.stringify(v, indent + 1):split("\n")) do
                    if subLine ~= "" then
                        table.insert(lines, spaces .. "  " .. subLine)
                    end
                end
            else
                table.insert(lines, spaces .. "- " .. formatValue(v))
            end
        end
    else
        for k, v in pairs(tbl) do
            local key = tostring(k)
            if type(v) == "table" then
                table.insert(lines, spaces .. key .. ":")
                for _, subLine in ipairs(YAML.stringify(v, indent + 1):split("\n")) do
                    if subLine ~= "" then
                        table.insert(lines, subLine)
                    end
                end
            else
                table.insert(lines, spaces .. key .. ": " .. formatValue(v))
            end
        end
    end

    return table.concat(lines, "\n")
end

-- Add split to string
if not string.split then
    function string:split(sep)
        local t = {}
        for part in self:gmatch("([^" .. sep .. "]+)") do
            table.insert(t, part)
        end
        return t
    end
end

return YAML