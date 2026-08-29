--[[
    TempleEx AI Agents Bridge
    Theme generation/refinement via LLM
]]

local AI = {}
AI.__index = AI

local Executor = require(script.Parent.executor)
local Config = require(script.Parent.config)
local ThemeEngine = require(script.Parent.theme)
local Log = require(script.Parent.log)

local HttpService = game:GetService("HttpService")

AI.cache = {}           -- promptHash -> result
AI.activeRequest = nil
AI.requestQueue = {}

-- ============================================================
-- LOAD AGENT PROMPTS
-- ============================================================
local function loadAgentPrompt(name)
    local ok, content = Executor.fs_read("agents/" .. name .. ".md")
    if ok and content then return content end
    -- Fallback: try from script directory
    local Executor = require(script.Parent.executor)
    local ok2, content2 = Executor.fs_read("src/agents/" .. name .. ".md")
    if ok2 and content2 then return content2 end
    return nil
end

AI.prompts = {
    theme_gen = loadAgentPrompt("theme-gen"),
    theme_refine = loadAgentPrompt("theme-refine"),
    config_audit = loadAgentPrompt("config-audit"),
    theme_namer = loadAgentPrompt("theme-namer")
}

-- ============================================================
-- HTTP REQUEST TO LLM
-- ============================================================
local function llmRequest(messages, options)
    options = options or {}
    local aiConfig = Config.get("ai") or {}
    local provider = aiConfig.provider or "openai-compatible"
    local baseUrl = aiConfig.base_url or "https://api.openai.com/v1"
    local model = options.model or aiConfig.model or "gpt-4o-mini"
    local temperature = options.temperature or 0.7
    local maxTokens = options.max_tokens or 4000

    local apiKey = nil
    if aiConfig.api_key_env then
        -- Try to get from executor env (not directly accessible, but some executors expose)
        -- For now, user must set in temple.yaml or we skip
    end

    local headers = {
        ["Content-Type"] = "application/json"
    }

    if apiKey then
        headers["Authorization"] = "Bearer " .. apiKey
    end

    local body = {
        model = model,
        messages = messages,
        temperature = temperature,
        max_tokens = maxTokens,
        stream = false
    }

    local url = baseUrl .. "/chat/completions"
    local res = Executor.http(url, {
        Method = "POST",
        Headers = headers,
        Body = HttpService:JSONEncode(body)
    })

    return res
end

-- ============================================================
-- CACHE KEY
-- ============================================================
local function cacheKey(prompt, model, agent)
    local str = agent .. "|" .. model .. "|" .. prompt
    -- Simple hash
    local hash = 0
    for i = 1, #str do
        hash = (hash * 31 + str:byte(i)) % 2147483647
    end
    return tostring(hash)
end

-- ============================================================
-- THEME GENERATOR
-- ============================================================
function AI.generateTheme(prompt, options)
    options = options or {}
    local model = options.model or Config.get("ai.agents.theme-gen.model") or "inherit"
    local temperature = options.temperature or Config.get("ai.agents.theme-gen.temperature") or 0.9

    if model == "inherit" then
        model = Config.get("ai.model") or "gpt-4o-mini"
    end

    local key = cacheKey(prompt, model, "theme-gen")
    if AI.cache[key] then
        Log.info("Theme gen cache hit")
        return AI.cache[key]
    end

    -- Get theme namer first
    local nameResult = AI.nameTheme(prompt)
    local slug = nameResult.slug
    local name = nameResult.name
    local tags = nameResult.tags

    -- Build system prompt with schema
    local schemaPrompt = [[
You are a TempleEx theme generator. Output ONLY valid YAML for a TempleEx theme v1.
Required sections: temple_theme: 1, name, author, palette (10 colors), tokens (all 57 required roles), typography, geometry, effects, icons, layout.
All token values MUST be palette references (e.g., "palette.accent"), never raw hex.
WCAG AA contrast: text.primary vs window.bg >= 4.5:1, accent vs window.bg >= 3:1.
]]

    local userPrompt = string.format([[
Create a theme: %s
Name: %s
Slug: %s
Tags: %s
Style: %s

Output ONLY the YAML. No markdown, no explanation.
]], prompt, name, slug, table.concat(tags, ", "), prompt)

    local messages = {
        {role = "system", content = schemaPrompt},
        {role = "user", content = userPrompt}
    }

    AI.activeRequest = {type = "theme-gen", prompt = prompt, startTime = tick()}
    local res = llmRequest(messages, {model = model, temperature = temperature})
    AI.activeRequest = nil

    if not res.Success then
        return nil, "LLM request failed: " .. (res.Error or res.Body)
    end

    local data = HttpService:JSONDecode(res.Body)
    local content = data.choices[1].message.content

    -- Extract YAML from potential markdown fence
    local yamlContent = content:match("```yaml\n(.-)\n```") or content:match("```\n(.-)\n```") or content

    -- Validate via ThemeEngine
    local YAML = require(script.Parent.yaml)
    local theme, errors = YAML.parse(yamlContent)
    if errors and #errors > 0 then
        return nil, "YAML parse errors: " .. table.concat(errors, "; ")
    end

    if not theme or theme.temple_theme ~= 1 then
        return nil, "Invalid theme format"
    end

    -- Contrast check (simplified)
    local contrastOk, contrastErr = AI.validateContrast(theme)
    if not contrastOk then
        return nil, "Contrast validation failed: " .. contrastErr
    end

    -- Cache and save
    theme.name = name
    theme.slug = slug
    AI.cache[key] = theme

    -- Save to themes folder
    local themesPath = Config.get("paths.themes") or "themes"
    local fileName = slug .. ".yaml"
    pcall(Executor.fs_write, themesPath .. "/" .. fileName, yamlContent)

    -- Reload themes
    ThemeEngine.loadAllThemes(themesPath)

    Log.info("Generated theme:", name, "(", slug .. ")")
    return theme, yamlContent
end

-- ============================================================
-- THEME REFINER
-- ============================================================
function AI.refineTheme(currentThemeYaml, feedback, options)
    options = options or {}
    local model = options.model or Config.get("ai.agents.theme-refine.model") or "inherit"
    local temperature = options.temperature or Config.get("ai.agents.theme-refine.temperature") or 0.4

    if model == "inherit" then
        model = Config.get("ai.model") or "gpt-4o-mini"
    end

    local key = cacheKey(currentThemeYaml .. "|" .. feedback, model, "theme-refine")
    if AI.cache[key] then return AI.cache[key] end

    local systemPrompt = [[
You are a TempleEx theme refiner. Modify the given theme YAML based on user feedback.
Preserve all required sections and tokens. Only change values that need to change.
Maintain WCAG AA contrast. Output ONLY the complete modified YAML.
]]

    local userPrompt = string.format([[
Current theme:
%s

Feedback: %s

Return the complete modified theme YAML only.
]], currentThemeYaml, feedback)

    local messages = {
        {role = "system", content = systemPrompt},
        {role = "user", content = userPrompt}
    }

    AI.activeRequest = {type = "theme-refine", prompt = feedback, startTime = tick()}
    local res = llmRequest(messages, {model = model, temperature = temperature})
    AI.activeRequest = nil

    if not res.Success then
        return nil, "LLM request failed: " .. (res.Error or res.Body)
    end

    local data = HttpService:JSONDecode(res.Body)
    local content = data.choices[1].message.content
    local yamlContent = content:match("```yaml\n(.-)\n```") or content:match("```\n(.-)\n```") or content

    local YAML = require(script.Parent.yaml)
    local theme, errors = YAML.parse(yamlContent)
    if errors and #errors > 0 then
        return nil, "YAML parse errors: " .. table.concat(errors, "; ")
    end

    local contrastOk, contrastErr = AI.validateContrast(theme)
    if not contrastOk then
        return nil, "Contrast validation failed: " .. contrastErr
    end

    AI.cache[key] = theme
    return theme, yamlContent
end

-- ============================================================
-- THEME NAMER
-- ============================================================
function AI.nameTheme(prompt)
    local key = cacheKey(prompt, "namer", "theme-namer")
    if AI.cache[key] then return AI.cache[key] end

    -- Simple local naming (no LLM call for speed)
    local words = {}
    for w in prompt:gmatch("%w+") do
        if #w > 2 then table.insert(words, w:lower()) end
    end

    local slug = table.concat(words, "-"):sub(1, 40)
    local name = table.concat(words, " "):gsub("(%w)(%w*)", function(a,b) return a:upper()..b:lower() end)

    local tags = {"custom"}
    for _, w in ipairs(words) do
        if #tags < 8 then table.insert(tags, w) end
    end

    local result = {name = name, slug = slug, tags = tags}
    AI.cache[key] = result
    return result
end

-- ============================================================
-- CONTRAST VALIDATION
-- ============================================================
function AI.validateContrast(theme)
    if not theme.palette or not theme.tokens then
        return false, "Missing palette or tokens"
    end

    local function hexToRgb(hex)
        hex = hex:gsub("#", "")
        local r = tonumber(hex:sub(1,2), 16) / 255
        local g = tonumber(hex:sub(3,4), 16) / 255
        local b = tonumber(hex:sub(5,6), 16) / 255
        return r, g, b
    end

    local function luminance(r, g, b)
        local function lin(c)
            return c <= 0.03928 and c/12.92 or ((c+0.055)/1.055)^2.4
        end
        return 0.2126*lin(r) + 0.7152*lin(g) + 0.0722*lin(b)
    end

    local function contrastRatio(hex1, hex2)
        local r1,g1,b1 = hexToRgb(hex1)
        local r2,g2,b2 = hexToRgb(hex2)
        local l1 = luminance(r1,g1,b1)
        local l2 = luminance(r2,g2,b2)
        return (math.max(l1,l2) + 0.05) / (math.min(l1,l2) + 0.05)
    end

    -- Resolve palette refs
    local function resolve(ref)
        if ref:sub(1,8) == "palette." then
            local key = ref:sub(9)
            return theme.palette[key]
        end
        return ref
    end

    local textPrimary = resolve(theme.tokens["text.primary"])
    local windowBg = resolve(theme.tokens["window.bg"])
    local accent = resolve(theme.tokens["toggle.track.on"])

    if textPrimary and windowBg then
        local ratio = contrastRatio(textPrimary, windowBg)
        if ratio < 4.5 then
            return false, string.format("text.primary vs window.bg contrast %.2f:1 (need 4.5:1)", ratio)
        end
    end

    if accent and windowBg then
        local ratio = contrastRatio(accent, windowBg)
        if ratio < 3.0 then
            return false, string.format("accent vs window.bg contrast %.2f:1 (need 3:1)", ratio)
        end
    end

    return true
end

-- ============================================================
-- CONFIG AUDIT
-- ============================================================
function AI.auditConfig(configYaml)
    local key = cacheKey(configYaml, "audit", "config-audit")
    if AI.cache[key] then return AI.cache[key] end

    -- For now, use local validation (config-audit agent would be LLM)
    local YAML = require(script.Parent.yaml)
    local config, errors = YAML.parse(configYaml)

    local result = {errors = {}, warnings = {}, info = {}}

    if errors then
        for _, e in ipairs(errors) do
            table.insert(result.errors, {path = "parse", message = e, fix = "Fix YAML syntax"})
        end
    end

    if config then
        -- Check theme existence
        local themesPath = Config.get("paths.themes") or "themes"
        local Executor = require(script.Parent.executor)
        local ok, files = Executor.fs_list(themesPath)
        local themeFiles = {}
        if ok then for _, f in ipairs(files) do themeFiles[f:gsub("%.yaml$","")] = true end end

        local active = config.theme and config.theme.active
        local fallback = config.theme and config.theme.fallback

        if active and not themeFiles[active] then
            table.insert(result.errors, {path = "theme.active", message = "Theme '" .. active .. "' not found", fix = "Create themes/" .. active .. ".yaml or change to existing theme"})
        end

        if fallback and not themeFiles[fallback] then
            table.insert(result.warnings, {path = "theme.fallback", message = "Fallback theme '" .. fallback .. "' not found", fix = "Create or change fallback"})
        end

        -- Check dock pins
        local validPins = {"fly", "speed", "esp", "noclip", "infjump", "fullbright", "hitbox", "freecam", "themes", "ai", "scripts"}
        local pins = config.shell and config.shell.dock and config.shell.dock.pins
        if pins then
            for _, pin in ipairs(pins) do
                if not table.find(validPins, pin) and not pin:match("^custom_") then
                    table.insert(result.warnings, {path = "shell.dock.pins", message = "Pin '" .. pin .. "' may not exist", fix = "Verify function ID or use custom pin via API"})
                end
            end
        end
    end

    AI.cache[key] = result
    return result
end

-- ============================================================
-- QUEUE MANAGEMENT
-- ============================================================
function AI.queueRequest(request)
    table.insert(AI.requestQueue, request)
    AI.processQueue()
end

function AI.processQueue()
    if AI.activeRequest or #AI.requestQueue == 0 then return end
    local req = table.remove(AI.requestQueue, 1)
    req.callback(AI[req.method](req.args))
end

-- ============================================================
-- STATUS
-- ============================================================
function AI.getStatus()
    return {
        active = AI.activeRequest,
        queued = #AI.requestQueue,
        cacheSize = (function() local c=0 for _ in pairs(AI.cache) do c=c+1 end return c end)()
    }
end

return AI