--[[
    TempleEx YAML Parser (subset)
    Supports: block mappings, block sequences, flow mappings {a: 1}, flow sequences [a, b],
              scalars (string/number/bool/null), quoted strings, comments.
    Handles "- key: value" (mapping inside a sequence item) for plugins lists.
]]

local YAML = {}

local function trim(s) return (s:match("^%s*(.-)%s*$")) end

-- Remove a trailing "# comment" that is not inside quotes
local function stripComment(line)
    local inQuote
    for idx = 1, #line do
        local c = line:sub(idx, idx)
        if inQuote then
            if c == inQuote then inQuote = nil end
        elseif c == '"' or c == "'" then
            inQuote = c
        elseif c == "#" then
            if idx == 1 or line:sub(idx-1, idx-1) == " " then
                return line:sub(1, idx - 1)
            end
        end
    end
    return line
end

-- Parse a scalar string into a Lua value
local function parseScalar(value)
    value = trim(value)
    if value == "" or value == "null" or value == "~" then return nil end
    if value == "true" or value == "yes" then return true end
    if value == "false" or value == "no" then return false end
    local num = tonumber(value)
    if num then return num end
    if value:sub(1,1) == '"' and value:sub(-1) == '"' then
        return (value:sub(2, -2):gsub('\\"', '"'):gsub('\\\\', '\\'))
    end
    if value:sub(1,1) == "'" and value:sub(-1) == "'" then
        return (value:sub(2, -2):gsub("''", "'"))
    end
    return value
end

-- Split "key: value" respecting quotes; returns key, value or nil
local function splitKeyValue(text)
    local inQuote
    for idx = 1, #text do
        local c = text:sub(idx, idx)
        if inQuote then
            if c == inQuote then inQuote = nil end
        elseif c == '"' or c == "'" then
            inQuote = c
        elseif c == ":" then
            local key = trim(text:sub(1, idx - 1))
            local val = trim(text:sub(idx + 1))
            if key ~= "" then return key, val end
            return nil
        end
    end
    return nil
end

-- Does this string look like "key: value" (not a URL scalar)?
local function looksLikeKey(s)
    if s:match("^[\"']") then return false end
    local before = s:match("^([^:]+):")
    if not before then return false end
    local after = s:sub(#before + 2, #before + 2)
    if after ~= "" and after ~= " " then return false end
    return true
end

-- Split flow content on top-level commas
local function splitFlow(s)
    local parts, buf, depth, inQuote = {}, "", 0, nil
    for idx = 1, #s do
        local c = s:sub(idx, idx)
        if inQuote then
            buf = buf .. c
            if c == inQuote then inQuote = nil end
        elseif c == '"' or c == "'" then
            inQuote = c; buf = buf .. c
        elseif c == "{" or c == "[" then
            depth = depth + 1; buf = buf .. c
        elseif c == "}" or c == "]" then
            depth = depth - 1; buf = buf .. c
        elseif c == "," and depth == 0 then
            parts[#parts + 1] = buf; buf = ""
        else
            buf = buf .. c
        end
    end
    if trim(buf) ~= "" then parts[#parts + 1] = buf end
    return parts
end

-- forward declarations
local parseInline, parseFlowMap, parseFlowSeq

parseFlowMap = function(s)
    local inner = s:match("^%{(.-)%}$") or s:sub(2, -2)
    local map = {}
    if trim(inner) == "" then return map end
    for _, part in ipairs(splitFlow(inner)) do
        local k, v = splitKeyValue(part)
        if k then map[k] = parseInline(v) end
    end
    return map
end

parseFlowSeq = function(s)
    local inner = s:match("^%[(.-)%]$") or s:sub(2, -2)
    local arr = {}
    if trim(inner) == "" then return arr end
    for _, part in ipairs(splitFlow(inner)) do
        arr[#arr + 1] = parseInline(part)
    end
    return arr
end

parseInline = function(s)
    s = trim(s)
    if s == "" then return nil end
    local first = s:sub(1, 1)
    if first == "{" then return parseFlowMap(s) end
    if first == "[" then return parseFlowSeq(s) end
    return parseScalar(s)
end

-- ============================================================
-- BLOCK PARSER (indentation based, recursive descent)
-- ============================================================
function YAML.parse(content)
    local lines = {}
    for raw in content:gmatch("[^\r\n]+") do
        local stripped = stripComment(raw)
        local indent = #stripped - #stripped:match("^%s*(.*)$")
        local text = trim(stripped)
        if text ~= "" then
            lines[#lines + 1] = { indent = indent, text = text }
        end
    end

    local i = 1
    local errors = {}
    local function cur() return lines[i] end

    local parseBlock, parseMapping, parseSequence

    parseBlock = function(indent)
        local line = cur()
        if not line then return nil end
        if line.text == "-" or line.text:sub(1, 2) == "- " then
            return parseSequence(indent)
        else
            return parseMapping(indent)
        end
    end

    -- parse a mapping whose first entry text is already known (from "- key: value")
    local function parseMappingFromInline(firstText, keyIndent)
        local map = {}
        local key, rest = splitKeyValue(firstText)
        i = i + 1  -- consume the "- ..." line
        if key then
            rest = trim(rest or "")
            if rest == "" then
                local nxt = cur()
                if nxt and nxt.indent > keyIndent then
                    map[key] = parseBlock(nxt.indent)
                else
                    map[key] = nil
                end
            else
                map[key] = parseInline(rest)
            end
        end
        -- subsequent keys at keyIndent
        while cur() and cur().indent == keyIndent and cur().text:sub(1, 1) ~= "-" do
            local line = cur()
            local k2, r2 = splitKeyValue(line.text)
            if not k2 then i = i + 1 break end
            i = i + 1
            r2 = trim(r2 or "")
            if r2 == "" then
                local nxt = cur()
                if nxt and nxt.indent > keyIndent then
                    map[k2] = parseBlock(nxt.indent)
                else
                    map[k2] = nil
                end
            else
                map[k2] = parseInline(r2)
            end
        end
        return map
    end

    parseMapping = function(indent)
        local map = {}
        while cur() and cur().indent == indent do
            local line = cur()
            if line.text == "-" or line.text:sub(1, 2) == "- " then break end
            local key, rest = splitKeyValue(line.text)
            if not key then
                i = i + 1
                errors[#errors + 1] = "Unexpected line: " .. line.text
            else
                i = i + 1
                rest = trim(rest or "")
                if rest == "" then
                    local nxt = cur()
                    if nxt and nxt.indent > indent then
                        map[key] = parseBlock(nxt.indent)
                    elseif nxt and nxt.indent == indent and (nxt.text == "-" or nxt.text:sub(1,2) == "- ") then
                        map[key] = parseSequence(indent)
                    else
                        map[key] = nil
                    end
                else
                    map[key] = parseInline(rest)
                end
            end
        end
        return map
    end

    parseSequence = function(indent)
        local arr = {}
        while cur() and cur().indent == indent and (cur().text == "-" or cur().text:sub(1, 2) == "- ") do
            local line = cur()
            local rest = (line.text == "-") and "" or trim(line.text:sub(3))
            local keyIndent = indent + 2
            if rest == "" then
                i = i + 1
                local nxt = cur()
                if nxt and nxt.indent > indent then
                    arr[#arr + 1] = parseBlock(nxt.indent)
                else
                    arr[#arr + 1] = nil
                end
            elseif looksLikeKey(rest) then
                arr[#arr + 1] = parseMappingFromInline(rest, keyIndent)
            else
                i = i + 1
                arr[#arr + 1] = parseInline(rest)
            end
        end
        return arr
    end

    local result
    if #lines == 0 then
        result = {}
    else
        result = parseBlock(lines[1].indent)
    end
    return result, errors
end

-- ============================================================
-- STRINGIFY (block style, round-trips with the parser above)
-- ============================================================
local function needsQuote(s)
    if s == "" then return true end
    if tonumber(s) or s == "true" or s == "false" or s == "null" then return true end
    if s:match("^[%w_%-%.]+$") then return false end
    return true
end

local function fmtScalar(v)
    if v == nil then return "null" end
    local tv = type(v)
    if tv == "boolean" then return v and "true" or "false" end
    if tv == "number" then return tostring(v) end
    if tv == "string" then
        if needsQuote(v) then
            return '"' .. v:gsub('\\', '\\\\'):gsub('"', '\\"') .. '"'
        end
        return v
    end
    return "null"
end

local function isSeq(t)
    local n = 0
    for k in pairs(t) do
        if type(k) ~= "number" then return false end
        n = n + 1
    end
    if n == 0 then return nil end
    for idx = 1, n do if t[idx] == nil then return false end end
    return true
end

function YAML.stringify(tbl, indent)
    indent = indent or 0
    local lines = {}

    local function emit(t, ind)
        local p = string.rep("  ", ind)
        local seq = isSeq(t)
        if seq then
            for _, v in ipairs(t) do
                if type(v) == "table" then
                    if next(v) == nil then
                        lines[#lines + 1] = p .. "- {}"
                    else
                        local saved = lines
                        lines = {}
                        emit(v, ind + 1)
                        local block = lines
                        lines = saved
                        for j, bl in ipairs(block) do
                            if j == 1 then
                                lines[#lines + 1] = p .. "- " .. bl:match("^%s*(.*)$")
                            else
                                lines[#lines + 1] = bl
                            end
                        end
                    end
                else
                    lines[#lines + 1] = p .. "- " .. fmtScalar(v)
                end
            end
        else
            for k, v in pairs(t) do
                if type(v) == "table" then
                    if next(v) == nil then
                        lines[#lines + 1] = p .. tostring(k) .. ": {}"
                    else
                        lines[#lines + 1] = p .. tostring(k) .. ":"
                        emit(v, ind + 1)
                    end
                else
                    lines[#lines + 1] = p .. tostring(k) .. ": " .. fmtScalar(v)
                end
            end
        end
    end

    emit(tbl, indent)
    return table.concat(lines, "\n")
end

-- string:split helper (used by config path lookups)
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