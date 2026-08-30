--[[
    TempleEx Icons - Google Material Symbols (Apache 2.0)
    Rendered as Roblox VectorGraphic (native SVG) so icons are crisp, recolorable
    and fully offline (no asset uploads). Falls back to a TextLabel glyph when
    VectorGraphic is unavailable on the client/executor.
]]

local Icons = {}

-- 24x24 viewBox path data (Material Design icons, Google, Apache 2.0)
Icons.paths = {
    close        = "M19 6.41L17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z",
    minimize     = "M20 14H4v-2h16v2z",
    maximize     = "M7 14H5v5h5v-2H7v-3zm-2-4h2V7h3V5H5v5zm12 7h-3v2h5v-5h-2v3zM14 5v2h3v3h2V5h-5z",
    restore      = "M5 16h3v3h2v-5H5v2zm3-8H5v2h5V5H8v3zm6 11h2v-3h3v-2h-5v5zm2-11V5h-2v5h5V8h-3z",
    flight       = "M21 16v-2l-8-5V3.5c0-.83-.67-1.5-1.5-1.5S10 2.67 10 3.5V9l-8 5v2l8-2.5V19l-2 1.5V22l3.5-1 3.5 1v-1.5L13 19v-5.5l8 2.5z",
    directions_run = "M13.5 5.5c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zM9.8 8.9L7 23h2.1l1.8-8 2.1 2v6h2v-7.5l-2.1-2 .6-3C14.8 12 16.8 13 19 13v-2c-1.9 0-3.5-1-4.3-2.4l-1-1.6c-.4-.6-1-1-1.7-1-.3 0-.5.1-.8.1L6 8.3V13h2V9.6l1.8-.7",
    visibility   = "M12 4.5C7 4.5 2.73 7.61 1 12c1.73 4.39 6 7.5 11 7.5s9.27-3.11 11-7.5c-1.73-4.39-6-7.5-11-7.5zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3z",
    block        = "M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 18c-4.42 0-8-3.58-8-8 0-1.85.63-3.55 1.69-4.9L16.9 18.31C15.55 19.37 13.85 20 12 20zm6.31-3.1L7.1 5.69C8.45 4.63 10.15 4 12 4c4.42 0 8 3.58 8 8 0 1.85-.63 3.55-1.69 4.9z",
    arrow_upward = "M4 12l1.41 1.41L11 7.83V20h2V7.83l5.58 5.59L20 12l-8-8-8 8z",
    wb_sunny     = "M6.76 4.84l-1.8-1.79-1.41 1.41 1.79 1.79 1.42-1.41zM4 10.5H1v2h3v-2zm9-9.95h-2V3.5h2V.55zm7.45 3.91l-1.41-1.41-1.79 1.79 1.41 1.41 1.79-1.79zm-3.21 13.7l1.79 1.8 1.41-1.41-1.8-1.79-1.4 1.4zM20 10.5v2h3v-2h-3zm-8-5c-3.31 0-6 2.69-6 6s2.69 6 6 6 6-2.69 6-6-2.69-6-6-6zm-1 16.95h2V19.5h-2v2.95zm-7.45-3.91l1.41 1.41 1.79-1.8-1.41-1.41-1.79 1.8z",
    center_focus = "M12 8c-2.21 0-4 1.79-4 4s1.79 4 4 4 4-1.79 4-4-1.79-4-4-4zm-7 7H3v4c0 1.1.9 2 2 2h4v-2H5v-4zM5 5h4V3H5c-1.1 0-2 .9-2 2v4h2V5zm14-2h-4v2h4v4h2V5c0-1.1-.9-2-2-2zm0 16h-4v2h4c1.1 0 2-.9 2-2v-4h-2v4z",
    photo_camera = "M12 15.2c1.77 0 3.2-1.43 3.2-3.2s-1.43-3.2-3.2-3.2-3.2 1.43-3.2 3.2 1.43 3.2 3.2 3.2zM9 2L7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2H9zm3 15c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5z",
    palette      = "M12 2C6.49 2 2 6.49 2 12s4.49 10 10 10c1.38 0 2.5-1.12 2.5-2.5 0-.61-.23-1.2-.64-1.67-.08-.1-.13-.21-.13-.33 0-.28.22-.5.5-.5H16c3.31 0 6-2.69 6-6 0-4.96-4.49-9-10-9zm5.5 11c-.83 0-1.5-.67-1.5-1.5S16.67 10 17.5 10s1.5.67 1.5 1.5-.67 1.5-1.5 1.5zm-3-4C13.67 9 13 8.33 13 7.5S13.67 6 14.5 6 16 6.67 16 7.5 15.33 9 14.5 9zM5 11.5c0-.83.67-1.5 1.5-1.5S8 10.67 8 11.5 7.33 13 6.5 13 5 12.33 5 11.5zm6-4C11 8.33 10.33 9 9.5 9S8 8.33 8 7.5 8.67 6 9.5 6s1.5.67 1.5 1.5z",
    auto_awesome = "M19 9l1.25-2.75L23 5l-2.75-1.25L19 1l-1.25 2.75L15 5l2.75 1.25L19 9zm-7.5.5L9 4 6.5 9.5 1 12l5.5 2.5L9 20l2.5-5.5L17 12l-5.5-2.5zM19 15l-1.25 2.75L15 19l2.75 1.25L19 23l1.25-2.75L23 19l-2.75-1.25L19 15z",
    code         = "M9.4 16.6L4.8 12l4.6-4.6L8 6l-6 6 6 6 1.4-1.4zm5.2 0l4.6-4.6-4.6-4.6L16 6l6 6-6 6-1.4-1.4z",
    settings     = "M19.14 12.94c.04-.3.06-.61.06-.94 0-.32-.02-.64-.07-.94l2.03-1.58c.18-.14.23-.41.12-.61l-1.92-3.32c-.12-.22-.37-.29-.59-.22l-2.39.96c-.5-.38-1.03-.7-1.62-.94l-.36-2.54c-.04-.24-.24-.41-.48-.41h-3.84c-.24 0-.43.17-.47.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96c-.22-.08-.47 0-.59.22L2.74 8.87c-.12.21-.08.47.12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58c-.18.14-.23.41-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32c.12-.22.07-.47-.12-.61l-2.01-1.58zM12 15.6c-1.98 0-3.6-1.62-3.6-3.6s1.62-3.6 3.6-3.6 3.6 1.62 3.6 3.6-1.62 3.6-3.6 3.6z",
    search       = "M15.5 14h-.79l-.28-.27C15.41 12.59 16 11.11 16 9.5 16 5.91 13.09 3 9.5 3S3 5.91 3 9.5 5.91 16 9.5 16c1.61 0 3.09-.59 4.23-1.57l.27.28v.79l5 4.99L20.49 19l-4.99-5zm-6 0C7.01 14 5 11.99 5 9.5S7.01 5 9.5 5 14 7.01 14 9.5 11.99 14 9.5 14z",
    home         = "M10 20v-6h4v6h5v-8h3L12 3 2 12h3v8z",
    play_arrow   = "M8 5v14l11-7z",
    check        = "M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z",
    add          = "M19 13h-6v6h-2v-6H5v-2h6V5h2v6h6v2z",
    delete       = "M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z",
    folder       = "M10 4H4c-1.1 0-1.99.9-1.99 2L2 18c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V8c0-1.1-.9-2-2-2h-8l-2-2z",
    refresh      = "M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z",
    expand_more  = "M16.59 8.59L12 13.17 7.41 8.59 6 10l6 6 6-6z",
    chevron_right = "M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z",
}

-- Text fallback glyphs (used only if VectorGraphic is unavailable).
-- Monochrome Unicode symbols that Roblox's fonts actually render (color emoji
-- often draw as blank boxes in-game).
Icons.fallback = {
    close = "✕", minimize = "–", maximize = "□", restore = "⊡",
    flight = "✈", directions_run = "➤", visibility = "◉", block = "⊘",
    arrow_upward = "↑", wb_sunny = "☀", center_focus = "◎", photo_camera = "▣",
    palette = "◐", auto_awesome = "✦", code = "‹›", settings = "⚙", search = "⌕",
    home = "⌂", play_arrow = "▶", check = "✓", add = "+", delete = "⌫",
    folder = "▤", refresh = "↻", expand_more = "▾", chevron_right = "›",
}

local function colorToHex(c)
    if typeof(c) ~= "Color3" then c = Color3.new(1, 1, 1) end
    return string.format("#%02x%02x%02x",
        math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end

local function buildSvg(name, hex)
    local d = Icons.paths[name]
    if not d then return nil end
    -- VectorGraphic needs explicit width/height on the root <svg> to compute its
    -- viewport; fill="none" on the root, real fill on the path (matches working
    -- Roblox VectorGraphic examples).
    return string.format(
        '<svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path fill="%s" d="%s"/></svg>',
        hex, d)
end

-- Icons.new(name, parent, size, color3) -> instance, setColorFn(newColor3)
-- Prefers VectorGraphic (crisp SVG). Falls back to a TextLabel glyph.
function Icons.new(name, parent, size, color3)
    size = size or 24
    color3 = color3 or Color3.new(1, 1, 1)
    local hex = colorToHex(color3)
    local svg = buildSvg(name, hex)

    if svg then
        local ok, vg = pcall(function()
            local g = Instance.new("VectorGraphic")
            g.Name = "Icon_" .. name
            g.Data = svg
            g.BackgroundTransparency = 1
            g.Size = UDim2.new(0, size, 0, size)
            g.Position = UDim2.new(0.5, 0, 0.5, 0)
            g.AnchorPoint = Vector2.new(0.5, 0.5)
            g.ZIndex = (parent and parent.ZIndex or 1) + 1
            g.Parent = parent
            return g
        end)
        if ok and vg then
            if not Icons._reported then
                Icons._reported = true
                print("[TempleEx] Icons: VectorGraphic supported (Material SVG)")
            end
            return vg, function(c3)
                local s = buildSvg(name, colorToHex(c3))
                if s then vg.Data = s end
            end
        end
    end

    if not Icons._reported then
        Icons._reported = true
        print("[TempleEx] Icons: VectorGraphic NOT supported -> text fallback")
    end

    -- Fallback: text glyph
    local lbl = Instance.new("TextLabel")
    lbl.Name = "Icon_" .. name
    lbl.BackgroundTransparency = 1
    lbl.Text = Icons.fallback[name] or "•"
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
