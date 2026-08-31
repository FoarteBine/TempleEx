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
-- PROVIDER PRESETS
-- ============================================================
AI.providers = {
    anthropic  = { baseUrl = "https://api.anthropic.com/v1", style = "anthropic", model = "claude-3-5-sonnet-latest" },
    claude     = { baseUrl = "https://api.anthropic.com/v1", style = "anthropic", model = "claude-3-5-sonnet-latest" },
    openai     = { baseUrl = "https://api.openai.com/v1", style = "openai", model = "gpt-4o-mini" },
    chatgpt    = { baseUrl = "https://api.openai.com/v1", style = "openai", model = "gpt-4o-mini" },
    deepseek   = { baseUrl = "https://api.deepseek.com/v1", style = "openai", model = "deepseek-chat" },
    qwen       = { baseUrl = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1", style = "openai", model = "qwen-plus" },
    nvidia     = { baseUrl = "https://integrate.api.nvidia.com/v1", style = "openai", model = "meta/llama-3.1-70b-instruct" },
    openrouter = { baseUrl = "https://openrouter.ai/api/v1", style = "openai", model = "openai/gpt-4o-mini" },
    custom     = { baseUrl = nil, style = "openai", model = nil },
}

local function extractContent(style, data)
    if style == "anthropic" then
        local c = data.content
        if type(c) == "table" then
            for _, part in ipairs(c) do
                if part.type == "text" then return part.text end
            end
        end
        return nil
    end
    local ok, txt = pcall(function() return data.choices[1].message.content end)
    return ok and txt or nil
end

-- ============================================================
-- HTTP REQUEST TO LLM
-- ============================================================
local function llmRequest(messages, options)
    options = options or {}
    local aiConfig = Config.get("ai") or {}
    local provider = string.lower(aiConfig.provider or "openai")
    local preset = AI.providers[provider] or AI.providers.openai
    local style = preset.style
    local baseUrl = aiConfig.base_url or preset.baseUrl
    local model = options.model or aiConfig.model or preset.model or "gpt-4o-mini"
    local apiKey = aiConfig.api_key
    local temperature = options.temperature or 0.7
    local maxTokens = options.max_tokens or 4000

    if not apiKey or apiKey == "" then
        return { Success = false, Error = "No API key set. Open AI Themes and enter a key." }
    end
    if not baseUrl then
        return { Success = false, Error = "No base URL for provider '" .. provider .. "'. Set one (custom)." }
    end

    local headers = { ["Content-Type"] = "application/json" }
    local url, body

    if style == "anthropic" then
        headers["x-api-key"] = apiKey
        headers["anthropic-version"] = "2023-06-01"
        local system, msgs = "", {}
        for _, m in ipairs(messages) do
            if m.role == "system" then system = m.content
            else table.insert(msgs, { role = m.role, content = m.content }) end
        end
        url = baseUrl .. "/messages"
        body = { model = model, max_tokens = maxTokens, temperature = temperature, system = system, messages = msgs }
    else
        headers["Authorization"] = "Bearer " .. apiKey
        url = baseUrl .. "/chat/completions"
        body = { model = model, messages = messages, temperature = temperature, max_tokens = maxTokens, stream = false }
    end

    local res = Executor.http(url, {
        Method = "POST",
        Headers = headers,
        Body = HttpService:JSONEncode(body)
    })

    if res and res.Success and res.Body and res.Body ~= "" then
        local ok, data = pcall(function() return HttpService:JSONDecode(res.Body) end)
        if ok and data then
            local content = extractContent(style, data)
            if content then
                return { Success = true, Content = content }
            end
            return { Success = false, Error = "Unexpected response shape" }
        end
        return { Success = false, Error = "Bad JSON response" }
    end
    return { Success = false, Error = (res and (res.Error or ("HTTP " .. tostring(res.StatusCode)))) or "no response" }
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
function AI.buildTheme(prompt, options)
    options = options or {}
    local model = options.model or Config.get("ai.model") or "gpt-4o-mini"
    local temperature = options.temperature or 0.9

    local nameResult = AI.nameTheme(prompt)
    local slug = nameResult.slug
    local name = nameResult.name
    local tags = nameResult.tags

    local schemaPrompt = [[
You are a TempleEx theme generator. Output ONLY valid YAML for a TempleEx theme v1.
Top-level keys: temple_theme: 1, name, author, palette (map of named colors as #RRGGBB), tokens (map of UI roles to a hex color or a "palette.<name>" reference).
Define at least palette entries: bg, surface, text, muted, accent, border.
Define at least tokens: window.bg, window.border, text.primary, text.muted, element.bg, toggle.track.on, dock.bg, dock.icon.
Output ONLY the YAML. No markdown fences, no explanation.
]]

    local userPrompt = string.format([[
Create a theme: %s
Name: %s
Slug: %s
Tags: %s
]], prompt, name, slug, table.concat(tags, ", "))

    local messages = {
        {role = "system", content = schemaPrompt},
        {role = "user", content = userPrompt}
    }

    AI.activeRequest = {type = "theme-gen", prompt = prompt, startTime = tick()}
    local res = llmRequest(messages, {model = model, temperature = temperature})
    AI.activeRequest = nil

    if not res.Success then
        return nil, nil, "LLM request failed: " .. (res.Error or "unknown")
    end

    local content = res.Content
    local yamlContent = content:match("```yaml%s*(.-)```") or content:match("```%s*(.-)```") or content
    yamlContent = (yamlContent:gsub("^\n+", ""))

    local YAML = require(script.Parent.yaml)
    local theme, errors = YAML.parse(yamlContent)
    if errors and #errors > 0 then
        return nil, nil, "YAML parse errors: " .. table.concat(errors, "; ")
    end
    if not theme then
        return nil, nil, "Could not parse theme"
    end

    theme.name = name
    theme.slug = slug

    -- Contrast is advisory only; the user previews and decides.
    local contrastOk, contrastErr = AI.validateContrast(theme)
    if not contrastOk then
        Log.warn("Theme contrast:", contrastErr)
    end

    return theme, yamlContent, nil
end

function AI.saveTheme(slug, yamlContent)
    local themesPath = Config.get("paths.themes") or "themes"
    pcall(Executor.fs_write, themesPath .. "/" .. slug .. ".yaml", yamlContent)
    ThemeEngine.loadAllThemes(themesPath)
end

function AI.deleteTheme(slug)
    local themesPath = Config.get("paths.themes") or "themes"
    pcall(Executor.fs_delete, themesPath .. "/" .. slug .. ".yaml")
    ThemeEngine.loadAllThemes(themesPath)
end

function AI.generateTheme(prompt, options)
    local theme, yamlContent, err = AI.buildTheme(prompt, options)
    if not theme then return nil, err end
    AI.saveTheme(theme.slug, yamlContent)
    Log.info("Generated theme:", theme.name, "(", theme.slug .. ")")
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
        return nil, "LLM request failed: " .. (res.Error or "unknown")
    end

    local content = res.Content
    local yamlContent = content:match("```yaml%s*(.-)```") or content:match("```%s*(.-)```") or content
    yamlContent = (yamlContent:gsub("^\n+", ""))

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