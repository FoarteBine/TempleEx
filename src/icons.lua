--[[
    TempleEx Icons
    Rendering is rbxassetid-based only (SVG/vector GUI is unavailable on many
    clients). Resolution per icon:
      1. Raster asset from Icons.overrides[name] or config `icons.assets.<name>`
         -> ImageLabel (true Material from uploaded PNGs, recolorable via
         ImageColor3).
      2. If no asset is assigned, a TextLabel emoji glyph is shown so the UI is
         never blank. Set an rbxassetid for any icon to replace its glyph.
    Icon "names" are Google Material Symbols identifiers (Apache 2.0).
]]

local Config = require(script.Parent.config)

local Icons = {}

-- name -> "rbxassetid://..." (or a getcustomasset URL). Populated by config
-- `icons.assets` or at runtime via TempleEx.Icons.overrides.
-- Defaults below are the user-supplied Google Material raster assets.
Icons.overrides = {
    start          = "rbxassetid://77014925817328", -- menu_power
    flight         = "rbxassetid://138022586306102",
    directions_run = "rbxassetid://70523947915342",
    visibility     = "rbxassetid://133911389227055",
    block          = "rbxassetid://13793170713",
    arrow_upward   = "rbxassetid://153287109",
    wb_sunny       = "rbxassetid://118024599480966",
    center_focus   = "rbxassetid://107110237849005",
    photo_camera   = "rbxassetid://9266631404",
    palette        = "rbxassetid://14008802626",
    auto_awesome   = "rbxassetid://92629709486503",
    code           = "rbxassetid://11348555035",
    settings       = "rbxassetid://9405931578",
    search         = "rbxassetid://118685771787843",
    close          = "rbxassetid://135341415849911",
    minimize       = "rbxassetid://103624489836882",
    maximize       = "rbxassetid://87584126977170",
    restore        = "rbxassetid://83285738642662",
}

-- Small badge drawn at the bottom-right of every dock shortcut.
Icons.shortcutBadge = "rbxassetid://133742372514080"

-- Material-symbol name -> emoji glyph (placeholder for icons with no asset).
Icons.glyphs = {
    start = "⊞",
    close = "✕", minimize = "–", maximize = "□", restore = "❐",
    flight = "✈", directions_run = "🏃", visibility = "👁", block = "👻",
    arrow_upward = "⤒", wb_sunny = "☀", center_focus = "🎯", photo_camera = "🎥",
    palette = "🎨", auto_awesome = "✨", code = "📜", settings = "⚙", search = "🔍",
    home = "⌂", play_arrow = "▶", check = "✓", add = "+", delete = "🗑",
    folder = "📁", refresh = "↻", expand_more = "▾", chevron_right = "›",
}
-- Back-compat alias (older code referenced Icons.fallback).
Icons.fallback = Icons.glyphs

-- Icons.new(name, parent, size, color3) -> instance, setColorFn(newColor3)
function Icons.new(name, parent, size, color3)
    size = size or 24
    color3 = color3 or Color3.new(1, 1, 1)

    -- (1) Raster asset: true Material from an uploaded PNG.
    local assetId = Icons.overrides[name]
    if not assetId then
        local ok, cfg = pcall(Config.get, "icons.assets." .. name)
        if ok then assetId = cfg end
    end
    if type(assetId) == "string" and assetId ~= "" then
        local img = Instance.new("ImageLabel")
        img.Name = "Icon_" .. name
        img.BackgroundTransparency = 1
        img.Image = assetId
        img.ImageColor3 = color3
        img.Size = UDim2.new(0, size, 0, size)
        img.Position = UDim2.new(0.5, 0, 0.5, 0)
        img.AnchorPoint = Vector2.new(0.5, 0.5)
        img.ZIndex = (parent and parent.ZIndex or 1) + 1
        img.Parent = parent
        return img, function(c3) img.ImageColor3 = c3 end
    end

    -- (2) No asset assigned: emoji glyph placeholder (never blank).
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Icon_" .. name
    lbl.BackgroundTransparency = 1
    lbl.Text = Icons.glyphs[name] or "•"
    lbl.TextColor3 = color3
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.Size = UDim2.new(0, size, 0, size)
    lbl.Position = UDim2.new(0.5, 0, 0.5, 0)
    lbl.AnchorPoint = Vector2.new(0.5, 0.5)
    lbl.ZIndex = (parent and parent.ZIndex or 1) + 1
    lbl.Parent = parent
    return lbl, function(c3) lbl.TextColor3 = c3 end
end

return Icons
