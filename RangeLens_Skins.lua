-- Range Lens's pieces in the window styles. Styles.lua does the choosing and the drawing
-- (Blizzard, Dark, or EllesmereUI's look); this file says what Range Lens restyles.
--
-- The range icons follow the style. In Blizzard they are built like the Cooldown Manager's
-- own (rounded mask, overlay frame, rounded swipe). In Dark and EllesmereUI they are square,
-- the way EllesmereUI's Cooldown Manager draws its icons: no mask and no overlay, the bevel
-- cropped, a 1px black edge and a square swipe. The red, the orange and the swipe colors
-- keep their meaning.
-- The options live on the game's own Options > AddOns page, which keeps the game's look in
-- every style. The standalone window (only on clients without that page) gets its frame
-- restyled; the controls inside it are the same frame as on the page, so they stay as they are.

local ADDON, ns = ...
local Styles = ns.Styles
local Try = Styles.Try
local FLAT = "Interface\\Buttons\\WHITE8X8"

local function S() return Styles.S end

-- A border frame a style adds sits above everything in the window; put the button back on top.
local function RaiseAbove(button, win)
    local level = win:GetFrameLevel() or 1
    for _, child in ipairs({ win:GetChildren() }) do
        if child ~= button then level = math.max(level, child:GetFrameLevel() or 0) end
    end
    button:SetFrameLevel(level + 5)
end

-- ---- pieces built later, as they are needed -----------------------------------------------------

-- Every range icon: on nameplates, on the target panel and in the options' nameplate preview.
function ns.SkinIcon(icon)
    if not S() or type(icon) ~= "table" or icon.rlSquare then return end
    Try("range icon", function()
        -- A masked texture cannot be cropped square, so the mask goes first.
        for _, tex in ipairs({ icon.dim, icon.oor, icon.lit }) do
            if icon.mask and tex.RemoveMaskTexture then pcall(tex.RemoveMaskTexture, tex, icon.mask) end
        end
        S().SquareIcon(icon.dim)
        if Styles.Applied() == "dark" then
            -- Dark's edge is sized once, from the icon's scale when it is drawn; a nameplate's
            -- scale is not final when its icons are made, and the edge came out many pixels
            -- thick. This one is sized again each time the icons are laid out or shown.
            S().SquareIcon(icon.lit)
            icon.rlEdge = {}
            for i = 1, 4 do
                local line = icon:CreateTexture(nil, "BORDER", nil, 7)
                line:SetColorTexture(0, 0, 0, 1)
                icon.rlEdge[i] = line
            end
            ns.SizeIconEdge(icon)
        else
            S().SquareIcon(icon.lit, icon)
        end
        -- The out-of-range shade's art is rounded; a flat red shade says the same.
        icon.oor:SetTexCoord(0, 1, 0, 1)
        icon.oor:SetColorTexture(0.5, 0, 0)
        icon.overlay:SetAlpha(0)
        pcall(icon.cd.SetSwipeTexture, icon.cd, FLAT, 0, 0, 0, 0.85)
        icon.look = nil -- the next range update sets the swipe color again
        icon.rlSquare = true
    end)
end

-- One screen pixel just outside the icon, at the icon's scale now. Never more than a twelfth of
-- the icon, whatever the scale says while a nameplate is still being set up.
function ns.SizeIconEdge(icon)
    local lines = type(icon) == "table" and icon.rlEdge
    if not lines then return end
    local px = 1
    local ok, scale = pcall(icon.GetEffectiveScale, icon)
    if ok and not (issecretvalue and issecretvalue(scale)) and type(scale) == "number" and scale > 0
        and PixelUtil and PixelUtil.GetNearestPixelSize then
        local okPx, size = pcall(PixelUtil.GetNearestPixelSize, 1, scale, 1)
        if okPx and type(size) == "number" and size > 0 then px = size end
    end
    local w = icon:GetWidth()
    local cap = (type(w) == "number" and w > 0) and math.max(0.5, w / 12) or 1.5
    if px > cap then px = cap end
    if icon.rlEdgePx == px then return end
    icon.rlEdgePx = px
    local top, bottom, left, right = lines[1], lines[2], lines[3], lines[4]
    for _, line in ipairs(lines) do line:ClearAllPoints() end
    top:SetPoint("BOTTOMLEFT", icon, "TOPLEFT", -px, 0)
    top:SetPoint("BOTTOMRIGHT", icon, "TOPRIGHT", px, 0)
    top:SetHeight(px)
    bottom:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", -px, 0)
    bottom:SetPoint("TOPRIGHT", icon, "BOTTOMRIGHT", px, 0)
    bottom:SetHeight(px)
    left:SetPoint("TOPRIGHT", icon, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMRIGHT", icon, "BOTTOMLEFT", 0, 0)
    left:SetWidth(px)
    right:SetPoint("TOPLEFT", icon, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(px)
end

-- The standalone options window.
function ns.SkinWindow(win)
    if not S() or type(win) ~= "table" then return end
    Try("options window", function()
        S().Shell(win)
        if type(win.Inset) == "table" then S().Inset(win.Inset) end
        if type(win.PortraitContainer) == "table" then S().FadeRegions(win.PortraitContainer) end
        local title = win.TitleText or (type(win.TitleContainer) == "table" and win.TitleContainer.TitleText)
        if type(title) == "table" then S().Font(title) end
        local close = win.CloseButton or _G.RangeLensOptionsCloseButton or win.rlClose
        if type(close) == "table" then
            S().CloseButton(close)
            RaiseAbove(close, win)
        end
    end)
end

-- ---- everything that exists when a style is applied ---------------------------------------------

local function SkinAll()
    for icon in pairs(ns.icons or {}) do ns.SkinIcon(icon) end
    if RangeLensOptions then ns.SkinWindow(RangeLensOptions) end
end

Styles.Setup({
    addon = ADDON,
    title = "Range Lens",
    db = function() return ns.DB and ns.DB() end,
    report = ns.report,
    accent = { 0.31, 0.7, 1 }, -- the panel's unlock outline and the chat prefix blue
    skin = SkinAll,
})
