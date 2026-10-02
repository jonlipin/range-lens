-- RangeLens
-- Per-spell range indicators on enemy nameplates and on a movable target panel,
-- drawn the way the game's Cooldown Manager draws its icons.
--
-- Secret-value safety: on clients with the 12.x addon restrictions (retail
-- Midnight, WoW Forever), range results can come back as secret booleans in
-- restricted contexts. Lua may not test, compare or branch on those. Every
-- range result in this file goes through ApplyRange(), which either handles a
-- plain boolean normally or hands a secret one straight to the engine through
-- Region:SetAlphaFromBoolean without ever inspecting it. Cooldowns go to the
-- engine as duration objects, so their numbers are never read either.

local ADDON_NAME = ...

---------------------------------------------------------------------------
-- API shims
---------------------------------------------------------------------------

local isSecret = issecretvalue or function() return false end

-- Plain boolean test that tolerates secrets: a secret yields `fallback`.
local function Truthy(v, fallback)
    if isSecret(v) then return fallback end
    return v and true or false
end

local SpellInRange
if C_Spell and C_Spell.IsSpellInRange then
    SpellInRange = C_Spell.IsSpellInRange
else
    SpellInRange = function(spell, unit)
        local r = IsSpellInRange(spell, unit)
        if r == nil then return nil end
        return r == 1
    end
end

local function SpellInfo(spell)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spell)
        if info then return info.name, info.iconID, info.spellID, info.minRange, info.maxRange end
        return nil
    end
    local name, _, icon, _, minRange, maxRange, id = GetSpellInfo(spell)
    return name, icon, id, minRange, maxRange
end

-- Spells centred on you (or a cone in front of you) have no target range, so
-- the game's range check answers nil for them. Their radius in yards, GENERATED
-- from the game's own spell data for build 1.60.1.70009: every spell on a class
-- skill line whose effect hits enemies in an area centred on you, at your feet,
-- in a cone in front of you, or through a spell it pulses (Hellfire). Spells
-- aimed at a target (Blizzard, Intimidating Shout) are left to the game's own
-- range check. The radius is the smallest over all ranks.
local AOE_RADIUS = {
    ["Arcane Explosion"] = 10,    -- spell 1449, 8437, 8438, 8439, 10201, 10202
    ["Blast Wave"] = 10,          -- spell 11113, 13018, 13019, 13020, 13021
    ["Challenging Roar"] = 10,    -- spell 5209
    ["Challenging Shout"] = 10,   -- spell 1161
    ["Cone of Cold"] = 10,        -- cone, spell 120, 8492, 10159, 10160, 10161
    ["Confounding Flash"] = 8,    -- spell 1277455
    ["Consecration"] = 8,         -- spell 20116, 20922, 20923, 20924, 26573
    ["Demonic Howl"] = 10,        -- spell 412789
    ["Demoralizing Roar"] = 10,   -- spell 99, 1735, 9490, 9747, 9898
    ["Demoralizing Shout"] = 10,  -- spell 1160, 6190, 11554, 11555, 11556
    ["Divine Storm"] = 8,         -- spell 407778
    ["Frost Nova"] = 10,          -- spell 122, 865, 6131, 10230
    ["Hellfire"] = 10,            -- spell 1949, 11683, 11684
    ["Holy Nova"] = 10,           -- spell 15237, 15430, 15431, 27799, 27800, 27801
    ["Holy Wrath"] = 20,          -- spell 2812, 10318
    ["Howl of Terror"] = 10,      -- spell 5484, 17928
    ["Molten Blast"] = 10,        -- cone, spell 425339
    ["Piercing Howl"] = 10,       -- spell 12323
    ["Psychic Scream"] = 8,       -- spell 8122, 8124, 10888, 10890
    ["Starfall"] = 30,            -- spell 439748
    ["Suffering"] = 10,           -- spell 17735, 17750, 17751, 17752
    ["Thunder Clap"] = 8,         -- spell 6343, 8198, 8204, 8205, 11580, 11581
    ["Thunderstomp"] = 8,         -- spell 26090, 26187, 26188, 1264455
    ["Whirlwind"] = 8,            -- spell 1680
}
local CONE = { ["Cone of Cold"] = true, ["Molten Blast"] = true }

-- Built-in reach adjustments, in yards, for what actually lands in game where it
-- differs from the data. Frost Nova's freeze lands short of its 10 yd damage on
-- WoW Forever (seen in game 2026-09-29: it freezes past 9 yd but not at 10).
-- Arcane Explosion reaches about 9.5 yd standing still (seen in game
-- 2026-10-02), so it is checked at 9.
local DEFAULT_REACH_ADJUST = { ["Frost Nova"] = -1, ["Arcane Explosion"] = -1 }

local function ReachAdjust(name)
    return DEFAULT_REACH_ADJUST[name] or 0
end

-- A spell the player has unlocked in the options and set by hand: its reach in
-- yards, shared by all characters (RangeLensDB.override). It replaces both the
-- game's range check and the radius table for that spell.
local OVERRIDE_MIN, OVERRIDE_MAX = 1, 50
local function Override(name)
    local o = RangeLensDB and RangeLensDB.override
    return o and name and o[name]
end

local function SetOverride(name, yards)
    RangeLensDB.override = RangeLensDB.override or {}
    if yards then
        yards = math.max(OVERRIDE_MIN, math.min(OVERRIDE_MAX, math.floor(yards + 0.5)))
    end
    RangeLensDB.override[name] = yards
end

-- How far a self-centred spell does what the icon promises.
local function AoeReach(name, radius)
    return math.max(1, radius + ReachAdjust(name))
end

-- Talents that widen a self-centred spell, best rank first: { talent spell ID, factor }.
-- Arctic Reach (Frost): +10% / +20% radius for Frost Nova and Cone of Cold.
local ARCTIC_REACH = { { 16758, 1.2 }, { 16757, 1.1 } }
local AOE_TALENTS = { ["Frost Nova"] = ARCTIC_REACH, ["Cone of Cold"] = ARCTIC_REACH }

local function KnowsSpell(id)
    if IsPlayerSpell then return Truthy(IsPlayerSpell(id), false) end
    if IsSpellKnown then return Truthy(IsSpellKnown(id), false) end
    return false
end

---------------------------------------------------------------------------
-- Distance checks for units without a spell range test. Both kinds and all
-- the distances come from LibRangeCheck-3.0 by mitch0 and the WoWUIDev community (MIT licence,
-- github.com/WeakAuras/LibRangeCheck-3.0), whose authors measured them in game:
--  * C_Item.IsItemInRange with an item whose use range is known. The item does
--    not have to be in your bags, but its data has to be loaded first.
--  * CheckInteractDistance: 3 = duel, 8 yd; 2 = trade, 9 yd; 4 = follow, 28 yd
--    (smaller for Tauren and Undead characters). LibRangeCheck measured trade
--    but leaves it switched off, so it is checked against duel as it runs and
--    dropped for the session if it ever says no inside duel range.
-- Both are refused on friendly units while you are in combat, so those are skipped.
---------------------------------------------------------------------------

-- Item IDs by use range in yards, LibRangeCheck-3.0's list for Classic Era and Forever.
local HARM_ITEMS = {
    [5] = { 8149, 15826, 16308, 17117, 22259, 22432, 206466, 208760, 208855, 209027, 209057, 213036, 221199, 225943 },
    [10] = { 9606, 9618, 9619, 9620, 9621, 10699, 17626, 17689, 226472 },
    [15] = { 4559 },
    [20] = { 1191, 2012, 4388, 10645, 13892, 17757, 18209, 22048, 202251, 227936, 232344 },
    [25] = { 13289 },
    [30] = { 835, 1404, 1434, 1444, 1472, 1704, 1854, 1914, 1995, 2091, 3434, 3441, 4479, 4480, 4481, 4941, 5079, 5457, 6436, 7344, 7734, 9328, 9394, 10588, 10716, 10720, 11170, 11522, 11565, 12288, 12646, 12647, 13213, 13509, 13514, 17202, 17310, 20084, 20908, 21038, 21713, 22200, 22206, 22218, 220649, 228576, 233226 },
    [35] = { 1258, 1399, 1402, 8688, 18904, 220568, 233216 },
    [40] = { 4945, 8348, 191414, 208773, 208843, 209047 },
    [45] = { 221316 },
}

local itemFor = {}      -- [yards] = the first item of that range whose data is loaded
local pendingItems = {} -- [itemID] = yards, while its data is being loaded
local interactYards = { [3] = 8, [2] = 9, [4] = 28 }
local tradeBroken = false   -- set when the trade check contradicts the duel check
local interactBlocked = false -- set if the game ever refuses one of these checks
local checkerCache          -- every available check, nearest first

local function ItemReady(id)
    if C_Item.IsItemDataCachedByID and not C_Item.IsItemDataCachedByID(id) then return false end
    return C_Item.GetItemInfo(id) ~= nil
end

local function LoadRangeItems()
    if not (C_Item and C_Item.IsItemInRange and C_Item.GetItemInfo) then return end
    for yards, list in pairs(HARM_ITEMS) do
        if not itemFor[yards] then
            for _, id in ipairs(list) do
                if ItemReady(id) then
                    itemFor[yards] = id
                    checkerCache = nil
                    break
                end
                if not pendingItems[id] then
                    pendingItems[id] = yards
                    if C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
                end
            end
        end
    end
end

-- GET_ITEM_INFO_RECEIVED
local function OnItemLoaded(id, success)
    local yards = pendingItems[id]
    if not yards then return end
    pendingItems[id] = nil
    if success and not itemFor[yards] and ItemReady(id) then
        itemFor[yards] = id
        checkerCache = nil
    end
end

local function SetRaceDistances()
    local _, race = UnitRace("player")
    if race == "Tauren" then interactYards = { [3] = 6, [2] = 7, [4] = 25 }
    elseif race == "Scourge" then interactYards = { [3] = 7, [2] = 8, [4] = 27 } end
    checkerCache = nil
end

local function Checkers()
    if checkerCache then return checkerCache end
    local list = {}
    for yards, id in pairs(itemFor) do list[#list + 1] = { yards = yards, item = id } end
    if CheckInteractDistance and not interactBlocked then
        for index, yards in pairs(interactYards) do
            if not (index == 2 and tradeBroken) then
                list[#list + 1] = { yards = yards, interact = index }
            end
        end
    end
    table.sort(list, function(a, b) return a.yards < b.yards end)
    checkerCache = list
    return list
end

local function RunChecker(c, unit)
    if InCombatLockdown() and not Truthy(UnitCanAttack("player", unit), false) then return nil end
    local ok, r
    if c.item then
        ok, r = pcall(C_Item.IsItemInRange, c.item, unit)
    else
        ok, r = pcall(CheckInteractDistance, unit, c.interact)
    end
    if not ok then return nil end
    if c.interact == 2 and r == false and not tradeBroken then
        -- Out of trade range but inside duel range cannot be true: the trade
        -- check does not work on this unit, so stop using it.
        local okDuel, duel = pcall(CheckInteractDistance, unit, 3)
        if okDuel and duel == true then
            tradeBroken = true
            checkerCache = nil
            return true
        end
    end
    return r
end

-- The check that reaches farthest without going past `radius`, so a lit icon
-- means the spell will reach.
local function CheckerFor(radius)
    local best
    for _, c in ipairs(Checkers()) do
        if c.yards <= radius then best = c end
    end
    return best
end

-- "8-10", "40+" or "0-5": between the farthest check that fails and the nearest that passes.
local function DistanceText(unit)
    local low = 0
    for _, c in ipairs(Checkers()) do
        local r = RunChecker(c, unit)
        if r ~= nil and not isSecret(r) then
            if r then return low .. "-" .. c.yards end
            low = c.yards
        end
    end
    if low > 0 then return low .. "+" end
end

-- Radius of a self-centred spell: the table first, then "within N yards" in its description.
local function AoeRadius(name, id)
    local r = name and AOE_RADIUS[name]
    if r then
        for _, t in ipairs(AOE_TALENTS[name] or {}) do
            if KnowsSpell(t[1]) then return math.floor(r * t[2] + 0.5) end
        end
        return r
    end
    if C_Spell and C_Spell.GetSpellDescription and id then
        local ok, text = pcall(C_Spell.GetSpellDescription, id)
        if ok and type(text) == "string" and not isSecret(text) then
            local n = text:match("within (%d+) yards") or text:match("(%d+) yard radius")
            if n then return tonumber(n) end
        end
    end
end

-- "30", or "8-35" for a spell with a minimum range; nil when there is no range.
local function RangeText(minRange, maxRange)
    if isSecret(minRange) or isSecret(maxRange) then return nil end
    if type(maxRange) ~= "number" or maxRange <= 0 then return nil end
    local text = tostring(math.floor(maxRange + 0.5))
    if type(minRange) == "number" and minRange > 0 then
        text = math.floor(minRange + 0.5) .. "-" .. text
    end
    return text
end

local function SpellHasRange(spell)
    if C_Spell and C_Spell.SpellHasRange then return C_Spell.SpellHasRange(spell) end
    if _G.SpellHasRange then return _G.SpellHasRange(spell) end
    return true
end

local function HasAtlas(atlas)
    return C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) ~= nil
end

local QUESTION_ICON = 134400 -- INV_Misc_QuestionMark

---------------------------------------------------------------------------
-- Saved variables
---------------------------------------------------------------------------

local DEFAULTS = {
    plates = true,          -- show rows on nameplates
    enemyOnly = true,       -- only on units you can attack
    panel = true,           -- show the target panel
    locked = false,         -- target panel drag lock
    cooldowns = true,       -- cooldown swipe (and countdown on the panel)
    showRange = true,       -- spell range in yards on each icon
    showDistance = true,    -- distance to the target above the panel
    plateDistance = true,   -- distance to each unit beside its nameplate icons
    plateTargetOnly = false, -- nameplate icons only under your target's nameplate
    plateFocusOnly = false, -- ... or your focus's; both ticked = target and focus
    inRangeOnly = false,    -- hide a spell's icon while it can't reach, instead of red
    plateHideMelee = false, -- hide a nameplate's icons while that unit is in melee range
    minimap = true,         -- minimap button
    minimapAngle = 200,     -- degrees around the minimap
    plateIconSize = 18,
    panelIconSize = 40,
    plateOffsetY = -6,
    plateOffsetX = 0,
    outAlpha = 1,           -- opacity of the out-of-range look
    interval = 0.1,         -- seconds between range checks
    point = { "CENTER", "CENTER", 0, -190 },
}

-- Starting spells per class. Anything the character doesn't know is skipped
-- automatically, so extra names here are harmless.
local CLASS_DEFAULTS = {
    MAGE    = { "Frostbolt", "Fire Blast", "Counterspell" },
    WARLOCK = { "Shadow Bolt", "Corruption", "Fear" },
    PRIEST  = { "Smite", "Shadow Word: Pain", "Mind Flay" },
    DRUID   = { "Wrath", "Moonfire", "Entangling Roots" },
    SHAMAN  = { "Lightning Bolt", "Earth Shock", "Purge" },
    HUNTER  = { "Arcane Shot", "Concussive Shot", "Wing Clip" },
    ROGUE   = { "Throw", "Kick", "Sinister Strike" },
    WARRIOR = { "Charge", "Intercept", "Hamstring" },
    PALADIN = { "Judgement", "Hammer of Justice", "Exorcism" },
}

local db, cdb

local function DeepCopy(src)
    local out = {}
    for k, v in pairs(src) do
        out[k] = type(v) == "table" and DeepCopy(v) or v
    end
    return out
end

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if dst[k] == nil then
            if type(v) == "table" then
                dst[k] = {}
                CopyDefaults(v, dst[k])
            else
                dst[k] = v
            end
        end
    end
end

---------------------------------------------------------------------------
-- Spell list (resolved from the character's saved entries)
---------------------------------------------------------------------------

-- resolved[i] = { query = <name passed to the range API>, spellID = id, icon = fileID, range = "30" }
local resolved = {}

local function ResolveSpells()
    wipe(resolved)
    for _, entry in ipairs(cdb.spells) do
        local name, icon, id, minRange, maxRange = SpellInfo(entry)
        if name then
            -- Query by name so the check follows whatever rank the character has.
            local spell = { query = name, spellID = id, icon = icon or QUESTION_ICON,
                range = RangeText(minRange, maxRange) }
            if not isSecret(minRange) and not isSecret(maxRange) and type(minRange) == "number"
                and type(maxRange) == "number" and minRange > 0 and maxRange > minRange then
                spell.minRange, spell.maxRange = minRange, maxRange
            end
            if not spell.range then
                local radius = AoeRadius(name, id)
                if radius then
                    spell.aoe = AoeReach(name, radius)
                    spell.range = tostring(spell.aoe)
                end
            end
            local manual = Override(name)
            if manual then
                spell.aoe = manual
                spell.range = tostring(manual)
                spell.minRange, spell.maxRange = nil, nil
                spell.manual = true
            end
            resolved[#resolved + 1] = spell
        end
    end
end

-- Index of a saved entry by list number, name or spell ID.
local function FindEntry(query)
    if type(query) == "number" and cdb.spells[query] and query <= #cdb.spells then
        -- A small number is treated as a list index for remove.
        return query
    end
    local wantName = SpellInfo(query) or query
    for i, entry in ipairs(cdb.spells) do
        local name = SpellInfo(entry) or entry
        if entry == query or (type(name) == "string" and type(wantName) == "string"
            and name:lower() == wantName:lower()) then
            return i
        end
    end
end

---------------------------------------------------------------------------
-- Icons, built like the Cooldown Manager's own
-- (Blizzard_CooldownViewer/CooldownViewer.xml, CooldownViewerEssentialItemTemplate):
-- the icon clipped by UI-HUD-CoolDownManager-Mask, UI-HUD-CoolDownManager-IconOverlay
-- drawn 9 px past a 50 px icon on each side and 8 px above and below, and
-- when out of range the icon tinted 0.64/0.15/0.15 under UI-CooldownManager-OORshadow
-- at half strength.
---------------------------------------------------------------------------

local MASK_ATLAS = "UI-HUD-CoolDownManager-Mask"
local OVERLAY_ATLAS = "UI-HUD-CoolDownManager-IconOverlay"
local OOR_ATLAS = "UI-CooldownManager-OORshadow"
local SWIPE_FILE = "Interface\\HUD\\UI-HUD-CoolDownManager-Icon-Swipe"
local EDGE_FILE = "Interface\\Cooldown\\UI-HUD-ActionBar-SecondaryCooldown"
local OUT_R, OUT_G, OUT_B = 0.64, 0.15, 0.15
local OOR_ALPHA = 0.5
local OVERLAY_X, OVERLAY_Y = 9 / 50, 8 / 50
-- The swipe art is a plain white shape the colour is laid over. The manager's
-- cooldown swipe is black at 0.7; this one is darker, and red while out of range.
local SWIPE_NORMAL = { 0, 0, 0, 0.85 }
local SWIPE_OUT = { 0.6, 0.05, 0.05, 0.85 }
-- Too close (inside a minimum range, such as Charge's 8 yards): orange instead of red.
local CLOSE_R, CLOSE_G, CLOSE_B = 0.9, 0.5, 0.1
local SWIPE_CLOSE = { 0.75, 0.38, 0.05, 0.85 }

local function CreateIcon(parent)
    local f = CreateFrame("Frame", nil, parent)

    local mask
    if f.CreateMaskTexture and HasAtlas(MASK_ATLAS) then
        mask = f:CreateMaskTexture()
        mask:SetAtlas(MASK_ATLAS)
        mask:SetAllPoints()
    end

    local function Layer(sublevel)
        local t = f:CreateTexture(nil, "ARTWORK", nil, sublevel)
        t:SetAllPoints()
        if mask then
            t:AddMaskTexture(mask)
        else
            t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end
        return t
    end

    -- Out-of-range look, always underneath.
    f.dim = Layer(0)
    f.dim:SetVertexColor(OUT_R, OUT_G, OUT_B)
    f.oor = Layer(1)
    if HasAtlas(OOR_ATLAS) then
        f.oor:SetAtlas(OOR_ATLAS)
    else
        f.oor:SetColorTexture(0.5, 0, 0)
    end

    -- Normal icon on top: its alpha is the in-range signal.
    f.lit = Layer(2)

    if HasAtlas(OVERLAY_ATLAS) then
        f.overlay = f:CreateTexture(nil, "OVERLAY")
        f.overlay:SetAtlas(OVERLAY_ATLAS)
    else
        f.overlay = f:CreateTexture(nil, "BACKGROUND")
        f.overlay:SetColorTexture(0, 0, 0, 0.85)
        f.overlayPx = 1
    end

    f.cd = CreateFrame("Cooldown", nil, f)
    f.cd:SetAllPoints()
    pcall(f.cd.SetSwipeTexture, f.cd, SWIPE_FILE, unpack(SWIPE_NORMAL))
    pcall(f.cd.SetEdgeTexture, f.cd, EDGE_FILE)
    pcall(f.cd.SetDrawEdge, f.cd, false)
    pcall(f.cd.SetHideCountdownNumbers, f.cd, true)

    -- Spell range in yards, on a layer above the cooldown swipe.
    f.textLayer = CreateFrame("Frame", nil, f)
    f.textLayer:SetAllPoints()
    f.textLayer:SetFrameLevel(f.cd:GetFrameLevel() + 2)
    f.range = f.textLayer:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    f.range:SetPoint("BOTTOM", f, "BOTTOM", 0, 2)

    return f
end

-- Countdown font by icon size; the manager uses the huge one on 50 px icons.
local function CountdownFont(size)
    if size >= 44 then return "GameFontHighlightHugeOutline" end
    if size >= 30 then return "GameFontHighlightLargeOutline" end
    return "GameFontHighlightOutline"
end

local function RangeFont(size)
    if size >= 36 and _G.NumberFontNormalLarge then return "NumberFontNormalLarge" end
    if size < 24 and _G.NumberFontNormalSmall then return "NumberFontNormalSmall" end
    return "NumberFontNormal"
end

local function SizeIcon(icon, size, numbers)
    icon:SetSize(size, size)
    pcall(icon.range.SetFontObject, icon.range, RangeFont(size))
    icon.range:ClearAllPoints()
    icon.range:SetPoint("BOTTOM", icon, "BOTTOM", 0, size < 24 and 0 or 2)
    local o = icon.overlay
    o:ClearAllPoints()
    local dx = icon.overlayPx or size * OVERLAY_X
    local dy = icon.overlayPx or size * OVERLAY_Y
    o:SetPoint("TOPLEFT", icon, "TOPLEFT", -dx, dy)
    o:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", dx, -dy)
    pcall(icon.cd.SetHideCountdownNumbers, icon.cd, not numbers)
    if numbers and icon.cd.SetCountdownFont then
        local font = CountdownFont(size)
        if _G[font] then pcall(icon.cd.SetCountdownFont, icon.cd, font) end
    end
end

local function SetIconSpell(icon, spell)
    icon.dim:SetTexture(spell.icon)
    icon.lit:SetTexture(spell.icon)
    icon.dim:SetAlpha(db.outAlpha)
    icon.oor:SetAlpha(OOR_ALPHA * db.outAlpha)
    icon.dim:SetVertexColor(OUT_R, OUT_G, OUT_B)
    icon.look = nil
    icon.range:SetText(db.showRange and spell.range or "")
    icon.spell = spell
end

-- The one place a range result is consumed.
-- "in", "out" (too far, red) or "close" (inside a minimum range, orange).
local SWIPE = { ["in"] = SWIPE_NORMAL, out = SWIPE_OUT, close = SWIPE_CLOSE }
local function SetLook(icon, state)
    if icon.look == state then return end
    icon.look = state
    if state == "close" then
        icon.dim:SetVertexColor(CLOSE_R, CLOSE_G, CLOSE_B)
        icon.oor:SetAlpha(0) -- the red shade would turn the orange back to red
    else
        icon.dim:SetVertexColor(OUT_R, OUT_G, OUT_B)
        icon.oor:SetAlpha(OOR_ALPHA * db.outAlpha)
    end
    pcall(icon.cd.SetSwipeColor, icon.cd, unpack(SWIPE[state]))
end

local function ApplyRange(icon, inRange, tooClose)
    if isSecret(inRange) then
        -- Can't look at it. Let the engine decide the lit layer's alpha.
        -- Default args are "fully visible if true, invisible if false".
        icon:Show()
        SetLook(icon, "in") -- the answer is hidden, so the plain look
        if icon.lit.SetAlphaFromBoolean then
            icon.lit:SetAlphaFromBoolean(inRange)
        else
            icon.lit:SetAlpha(0)
        end
        -- In range only: the whole icon follows the hidden answer too.
        if db.inRangeOnly and icon.SetAlphaFromBoolean then
            icon:SetAlphaFromBoolean(inRange)
        else
            icon:SetAlpha(1)
        end
        return
    end
    if inRange == nil then
        -- Check not applicable (spell can't target this unit, unit not visible...)
        icon:Hide()
        return
    end
    icon:Show()
    icon.lit:SetAlpha(inRange and 1 or 0)
    SetLook(icon, inRange and "in" or (tooClose and "close" or "out"))
    -- In range only: out of reach (too far or too close) means not shown at all.
    icon:SetAlpha((db.inRangeOnly and not inRange) and 0 or 1)
end

-- Cooldown swipe from the game's own duration object: the numbers inside it
-- may be secret in combat, and the engine is the only one that reads them.
local function ApplyCooldown(icon)
    local cd = icon.cd
    local id = icon.spell and icon.spell.spellID
    if not (db.cooldowns and id and C_Spell and C_Spell.GetSpellCooldownDuration
        and cd.SetCooldownFromDurationObject) then
        -- Not Cooldown:Clear(): the game marks it as protected.
        cd:Hide()
        return
    end
    cd:Show()
    local ok, duration = pcall(C_Spell.GetSpellCooldownDuration, id, true)
    if not (ok and duration and pcall(cd.SetCooldownFromDurationObject, cd, duration, true)) then
        cd:Hide()
    end
end

---------------------------------------------------------------------------
-- Icon rows (shared by nameplates and the panel)
---------------------------------------------------------------------------

local function LayoutRow(row, size, spacing, numbers)
    local n = #resolved
    row.icons = row.icons or {}
    for i = 1, n do
        local icon = row.icons[i]
        if not icon then
            icon = CreateIcon(row)
            row.icons[i] = icon
        end
        SizeIcon(icon, size, numbers)
        icon:ClearAllPoints()
        icon:SetPoint("LEFT", row, "LEFT", (i - 1) * (size + spacing), 0)
        SetIconSpell(icon, resolved[i])
    end
    for i = n + 1, #row.icons do
        row.icons[i]:Hide()
        row.icons[i].spell = nil
    end
    local width = n > 0 and (n * size + (n - 1) * spacing) or 1
    row:SetSize(width, size)
    row.count = n
end

-- In range? true/false, nil when the check doesn't apply, or a secret.
local function CheckSpell(spell, unit)
    if spell.aoe then
        local c = CheckerFor(spell.aoe)
        return c and RunChecker(c, unit)
    end
    return SpellInRange(spell.query, unit)
end

-- A spell with a minimum range that the game says can't reach: too close, or
-- too far? A distance check that fits inside its maximum range (20 yards for
-- Charge's 25) passing means the unit is within reach of the far end, so the
-- game must be saying no because it is inside the minimum.
local function TooClose(spell, unit)
    if not spell.minRange then return false end
    local c = CheckerFor(spell.maxRange - 1)
    if not c or c.yards <= spell.minRange then return false end
    return RunChecker(c, unit) == true
end

local function UpdateRow(row, unit)
    for i = 1, row.count or 0 do
        local icon = row.icons[i]
        local r = CheckSpell(icon.spell, unit)
        ApplyRange(icon, r, r == false and TooClose(icon.spell, unit))
    end
end

local function UpdateRowCooldowns(row)
    for i = 1, row.count or 0 do
        ApplyCooldown(row.icons[i])
    end
end

local function PanelSpacing(size)
    return math.max(2, math.floor(size * 0.1 + 0.5))
end

---------------------------------------------------------------------------
-- Nameplates
---------------------------------------------------------------------------

local plateRows = {}   -- [nameplate frame] = row
local activePlates = {} -- [unit token] = row
local plateUnits = {}  -- [unit token] = true for every nameplate currently shown

local function PlateAnchor(plate)
    local uf = plate.UnitFrame
    if uf and not uf:IsForbidden() and uf.healthBar then
        return uf.healthBar
    end
    return plate
end

-- Is this nameplate the one for `token` ("target" or "focus")? Comparing the
-- nameplate frames needs no unit comparison, which the game can hide in some places.
local function IsPlateOf(unit, token)
    local ok, tokenPlate = pcall(C_NamePlate.GetNamePlateForUnit, token)
    if ok then
        return tokenPlate ~= nil and tokenPlate == C_NamePlate.GetNamePlateForUnit(unit)
    end
    return Truthy(UnitIsUnit(unit, token), false)
end

-- With "only on target" and/or "only on focus" ticked, is this nameplate one of them?
local function PlateAllowed(unit)
    if not (db.plateTargetOnly or db.plateFocusOnly) then return true end
    return (db.plateTargetOnly and IsPlateOf(unit, "target"))
        or (db.plateFocusOnly and IsPlateOf(unit, "focus")) or false
end

-- In melee range: the 5 yard item check passes.
local function InMelee(unit)
    local c = CheckerFor(5)
    return c ~= nil and RunChecker(c, unit) == true
end

-- The game's own nameplate settings (Options > Nameplates): Size and Style.
-- Read, never written; reading these does not touch Blizzard's nameplate code.
local function PlateSettings()
    local size = tonumber(GetCVar and GetCVar("nameplateSize")) or 2
    local style = tonumber(GetCVar and GetCVar("nameplateStyle")) or 0
    return size, style
end

local function PlateSettingsKey()
    local size, style = PlateSettings()
    return style .. ":" .. size
end

-- Blizzard's horizontal and vertical scale for a Size, per Style (NamePlateConstants).
local function PlateScale(size, style)
    local consts = _G.NamePlateConstants
    local classic = Enum and Enum.NamePlateStyle and style == Enum.NamePlateStyle.Classic
    local tbl = consts and (classic and consts.NAME_PLATE_SCALES_CLASSIC_STYLE or consts.NAME_PLATE_SCALES)
    local entry = tbl and (tbl[size] or tbl[2])
    if type(entry) == "table" then return entry.horizontal or 1, entry.vertical or 1 end
    return 1, 1
end

-- Measure a real plate's health bar and our row's scale, relative to the
-- nameplate frame itself, and save it under the current Size and Style.
-- The game scales each nameplate frame by distance (smaller far away) and
-- enlarges your target's; measuring relative to the frame leaves that out.
-- Drawn in the options at these sizes, the preview comes out the size the
-- game's own nameplate preview shows.
local function MeasurePlate(plate, row, bar)
    if not (bar and bar ~= plate and RangeLensDB) then return end
    local ok, w, h = pcall(function() return bar:GetWidth(), bar:GetHeight() end)
    local okS, barScale = pcall(bar.GetEffectiveScale, bar)
    local okR, rowScale = pcall(row.GetEffectiveScale, row)
    local okP, plateScale = pcall(plate.GetEffectiveScale, plate)
    if not okP or isSecret(plateScale) or type(plateScale) ~= "number" or plateScale <= 0 then return end
    if ok and okS and okR and not isSecret(w) and not isSecret(h) and not isSecret(barScale)
        and not isSecret(rowScale) and type(barScale) == "number" and type(rowScale) == "number"
        and type(w) == "number" and w > 20 and type(h) == "number" and h > 2 then
        barScale, rowScale = barScale / plateScale, rowScale / plateScale
        RangeLensDB.plateLooks = RangeLensDB.plateLooks or {}
        RangeLensDB.plateLooks[PlateSettingsKey()] = { w = w * barScale, h = h * barScale, rowScale = rowScale }
    end
end

-- The plate to draw in the preview for the current settings: measured if a
-- real plate has been seen with them, otherwise estimated from a measurement
-- under other settings (scaled by Blizzard's tables), otherwise from defaults.
local function PlateLook()
    local looks = RangeLensDB and RangeLensDB.plateLooks or {}
    local size, style = PlateSettings()
    local key = style .. ":" .. size
    if looks[key] then return looks[key], true end
    local h1, v1 = PlateScale(size, style)
    for other, look in pairs(looks) do
        local oStyle, oSize = other:match("^(%-?%d+):(%-?%d+)$")
        oStyle, oSize = tonumber(oStyle), tonumber(oSize)
        local h0, v0 = PlateScale(oSize, oStyle)
        return { w = look.w * h1 / h0, h = look.h * v1 / v0, rowScale = look.rowScale }, false
    end
    -- Blizzard's own sizes (Blizzard_NamePlates): the 190 wide plate holds the
    -- level badge and its gaps, leaving a 130 wide health bar at Medium (checked
    -- against the game's own preview); Classic insets its 152 plate by 24.25.
    -- The health bar height is by style.
    local styles = Enum and Enum.NamePlateStyle or {}
    local barH = 13
    if style == styles.Modern or style == styles.Block or style == styles.HealthFocus then barH = 20
    elseif style == styles.Classic then barH = 10 end
    local barW = (style == styles.Classic) and (152 - 24.25) or 130
    return { w = barW * h1, h = barH * v1, rowScale = 1 }, false
end

local function WantsPlate(unit)
    if not db.plates or #resolved == 0 then return false end
    if not PlateAllowed(unit) then return false end
    if Truthy(UnitIsUnit("player", unit), false) then return false end
    if db.enemyOnly then
        return Truthy(UnitCanAttack("player", unit), true)
    end
    return true
end

local function UpdatePlateMelee(row, unit)
    row:SetAlpha((db.plateHideMelee and InMelee(unit)) and 0 or 1)
end

local function UpdatePlateDistance(row, unit)
    local text = db.plateDistance and DistanceText(unit)
    row.distance:SetText(text or "")
end

local function OnPlateAdded(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or plate:IsForbidden() then return end

    local row = plateRows[plate]
    if not row then
        row = CreateFrame("Frame", nil, plate)
        row:SetFrameLevel(plate:GetFrameLevel() + 10)
        row.distance = row:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
        row.distance:SetPoint("LEFT", row, "RIGHT", 4, 0)
        plateRows[plate] = row
        LayoutRow(row, db.plateIconSize, 2, false)
    end

    if not WantsPlate(unit) then
        row:Hide()
        return
    end

    row:ClearAllPoints()
    row:SetPoint("TOP", PlateAnchor(plate), "BOTTOM", db.plateOffsetX, db.plateOffsetY)
    -- The options preview copies a real plate's size (see MeasurePlate).
    MeasurePlate(plate, row, PlateAnchor(plate))
    row.unit = unit
    row:Show()
    activePlates[unit] = row
    UpdateRow(row, unit)
    UpdatePlateMelee(row, unit)
    UpdatePlateDistance(row, unit)
    UpdateRowCooldowns(row)
end

local function OnPlateRemoved(unit)
    local row = activePlates[unit]
    if row then
        row:Hide()
        row.unit = nil
        activePlates[unit] = nil
    end
end

local function RefreshAllPlates()
    for unit, row in pairs(activePlates) do
        row:Hide()
        activePlates[unit] = nil
    end
    for _, row in pairs(plateRows) do
        LayoutRow(row, db.plateIconSize, 2, false)
    end
    -- Nameplate frames carry no reliable unit field on Forever (the Blizzard
    -- base mixin keeps it in plate.unitToken), so re-add from the tokens the
    -- NAME_PLATE_UNIT_ADDED events gave us.
    for unit in pairs(plateUnits) do
        OnPlateAdded(unit)
    end
end

---------------------------------------------------------------------------
-- Target panel
---------------------------------------------------------------------------

local panel = CreateFrame("Frame", "RangeLensPanel", UIParent)
panel:SetClampedToScreen(true)
panel:SetMovable(true)
panel:RegisterForDrag("LeftButton")
panel:Hide()

panel.row = CreateFrame("Frame", nil, panel)
panel.row:SetPoint("CENTER")

panel.distance = panel:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
panel.distance:SetPoint("BOTTOM", panel, "TOP", 0, 0)

-- While unlocked: a thin outline round the icons, brighter under the mouse,
-- so it is clear the panel can be dragged. Hidden once locked.
panel.outline = CreateFrame("Frame", nil, panel)
panel.outline:SetAllPoints()
panel.outline:SetFrameLevel(panel.row:GetFrameLevel() + 20)
panel.outline.edges = {}
for i, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = panel.outline:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(0.3, 0.7, 1, 1)
    if side == "TOP" or side == "BOTTOM" then
        t:SetPoint(side .. "LEFT")
        t:SetPoint(side .. "RIGHT")
        t:SetHeight(1)
    else
        t:SetPoint("TOP" .. side)
        t:SetPoint("BOTTOM" .. side)
        t:SetWidth(1)
    end
    panel.outline.edges[i] = t
end
panel.outline:SetAlpha(0.55)
panel.outline:Hide()

panel:SetScript("OnEnter", function(self)
    self.outline:SetAlpha(1)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Range Lens", 1, 1, 1)
    GameTooltip:AddLine("Drag to move", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Right-click: options", 0.7, 0.7, 0.7)
    GameTooltip:AddLine("Lock it in the options or with the minimap button's right-click", 0.7, 0.7, 0.7, true)
    GameTooltip:Show()
end)
panel:SetScript("OnLeave", function(self)
    self.outline:SetAlpha(0.55)
    GameTooltip:Hide()
end)

panel:SetScript("OnDragStart", function(self)
    if not db.locked then self:StartMoving() end
end)
panel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    db.point = { point, relPoint, x, y }
end)

local function PlacePanel()
    local p = db.point
    panel:ClearAllPoints()
    panel:SetPoint(p[1], UIParent, p[2], p[3], p[4])
end

local function LayoutPanel()
    local size = db.panelIconSize
    LayoutRow(panel.row, size, PanelSpacing(size), true)
    local w, h = panel.row:GetSize()
    -- Room for the icon overlay that reaches past each icon.
    panel:SetSize(w + size * OVERLAY_X * 2 + 4, h + size * OVERLAY_Y * 2 + 4)
    panel:EnableMouse(not db.locked)
    panel.outline:SetShown(not db.locked)
    UpdateRowCooldowns(panel.row)
end

local function UpdatePanel()
    if not db.panel or #resolved == 0 then
        panel:Hide()
        return
    end
    local text = db.showDistance and Truthy(UnitExists("target"), false) and DistanceText("target")
    panel.distance:SetText(text or "")
    if not db.locked then
        -- Unlocked: always visible so it can be positioned.
        panel:Show()
        if Truthy(UnitExists("target"), true) then
            UpdateRow(panel.row, "target")
        else
            for i = 1, panel.row.count or 0 do
                panel.row.icons[i]:Show()
                panel.row.icons[i].lit:SetAlpha(1)
                panel.row.icons[i]:SetAlpha(1)
                SetLook(panel.row.icons[i], "in")
            end
        end
        return
    end
    if Truthy(UnitExists("target"), true) and not Truthy(UnitIsDeadOrGhost("target"), false) then
        panel:Show()
        UpdateRow(panel.row, "target")
    else
        panel:Hide()
    end
end

local function RefreshCooldowns()
    UpdateRowCooldowns(panel.row)
    for _, row in pairs(activePlates) do
        UpdateRowCooldowns(row)
    end
end

---------------------------------------------------------------------------
-- Ticker
---------------------------------------------------------------------------

local ticker

local tickCount = 0

local function Tick()
    tickCount = tickCount + 1
    local distances = tickCount % 3 == 0
    for unit, row in pairs(activePlates) do
        UpdateRow(row, unit)
        UpdatePlateMelee(row, unit)
        if distances then UpdatePlateDistance(row, unit) end
    end
    UpdatePanel()
end

local function StartTicker()
    if ticker then ticker:Cancel() end
    ticker = C_Timer.NewTicker(db.interval, Tick)
end

local function FullRefresh()
    ResolveSpells()
    RefreshAllPlates()
    LayoutPanel()
    UpdatePanel()
end

local function Print(msg)
    print("|cff4fb3ffRange Lens|r: " .. msg)
end

---------------------------------------------------------------------------
-- Options window
---------------------------------------------------------------------------

local optionRefreshers = {} -- functions that pull settings into widgets
local RefreshOptions        -- defined below

local function TryCreate(kind, name, parent, templates)
    for _, template in ipairs(templates) do
        local ok, made = pcall(CreateFrame, kind, name, parent, template)
        if ok and made then return made, template end
    end
    return CreateFrame(kind, name, parent), "bare"
end

-- Every non-passive spell in the spellbook that has a range, one per name.
local function ScanSpellBook()
    local out, seen = {}, {}
    local function Add(name, id, icon)
        if type(name) ~= "string" or name == "" or seen[name:lower()] then return end
        local ok, ranged = pcall(SpellHasRange, id or name)
        local range, auto
        if ok and not Truthy(ranged, true) then
            local radius = AoeRadius(name, id)
            if not radius then return end
            auto = AoeReach(name, radius)
            range = auto .. (CONE[name] and " yd cone" or " yd around you")
            if auto ~= radius then range = range .. " (data " .. radius .. ")" end
        else
            local _, _, _, minRange, maxRange = SpellInfo(id or name)
            range = RangeText(minRange, maxRange)
            range = range and (range .. " yd")
            if type(maxRange) == "number" and not isSecret(maxRange) and maxRange > 0 then
                auto = math.floor(maxRange + 0.5)
            end
        end
        local manual = Override(name)
        if manual then range = manual .. " yd, set by hand" end
        seen[name:lower()] = true
        out[#out + 1] = { name = name, icon = icon or QUESTION_ICON, range = range, auto = auto }
    end

    local book = C_SpellBook
    if book and book.GetNumSpellBookSkillLines and book.GetSpellBookItemInfo then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
        pcall(function()
            for line = 1, book.GetNumSpellBookSkillLines() do
                local info = book.GetSpellBookSkillLineInfo(line)
                if info and not info.shouldHide and not info.isGuild and not info.offSpecID then
                    for i = info.itemIndexOffset + 1, info.itemIndexOffset + info.numSpellBookItems do
                        local item = book.GetSpellBookItemInfo(i, bank)
                        if item and item.spellID and not item.isPassive
                            and (not spellType or item.itemType == spellType) then
                            Add(item.name, item.spellID, item.iconID)
                        end
                    end
                end
            end
        end)
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
        pcall(function()
            for tab = 1, GetNumSpellTabs() do
                local _, _, offset, count = GetSpellTabInfo(tab)
                for i = offset + 1, offset + count do
                    local kind, id = GetSpellBookItemInfo(i, "spell")
                    local passive = IsPassiveSpell and IsPassiveSpell(i, "spell")
                    if kind == "SPELL" and id and not passive then
                        local name, icon = SpellInfo(id)
                        Add(name, id, icon)
                    end
                end
            end
        end)
    end

    -- Tracked entries the book did not offer (not learned yet, or no range).
    for _, entry in ipairs(cdb.spells) do
        local name, icon = SpellInfo(entry)
        local label = tostring(name or entry)
        if not seen[label:lower()] then
            seen[label:lower()] = true
            out[#out + 1] = { name = label, icon = icon or QUESTION_ICON, unknown = name == nil }
        end
    end
    return out
end

-- Move a tracked spell to where another one is in the list (drag and drop).
local function MoveSpell(fromName, toName)
    local from, to = FindEntry(fromName), FindEntry(toName)
    if not (from and to) or from == to then return end
    local entry = tremove(cdb.spells, from)
    tinsert(cdb.spells, to, entry)
end

local function SetTracked(name, on)
    local i = FindEntry(name)
    if on and not i then
        tinsert(cdb.spells, name)
    elseif not on and i then
        tremove(cdb.spells, i)
    end
    FullRefresh()
    RefreshOptions()
end

local function CreateCheck(parent, label)
    local cb = TryCreate("CheckButton", nil, parent, { "UICheckButtonTemplate", "ChatConfigCheckButtonTemplate" })
    cb:SetSize(24, 24)
    -- Own label: the templates disagree about where theirs lives.
    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.label:SetText(label or "")
    return cb
end

local previewHook -- set by the options page: redraws the nameplate preview

local function OptionCheck(parent, label, key, x, y, after)
    local cb = CreateCheck(parent, label)
    cb:SetPoint("TOPLEFT", x, y)
    cb:SetScript("OnClick", function(self)
        db[key] = self:GetChecked() and true or false
        if after then after() end
        if previewHook then previewHook() end
    end)
    optionRefreshers[#optionRefreshers + 1] = function() cb:SetChecked(db[key] and true or false) end
    return cb
end

local sliderCount = 0
local function OptionSlider(parent, label, key, minV, maxV, x, y, width)
    sliderCount = sliderCount + 1
    local name = "RangeLensOptionsSlider" .. sliderCount
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", x, y)
    holder:SetSize(width, 40)

    local caption = holder:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    caption:SetPoint("TOPLEFT", 0, 0)
    caption:SetText(label)
    local value = holder:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    value:SetPoint("TOPRIGHT", 0, -1)

    local slider = TryCreate("Slider", name, holder, { "MinimalSliderTemplate", "UISliderTemplate", "OptionsSliderTemplate" })
    for _, suffix in ipairs({ "Low", "High", "Text" }) do
        local extra = _G[name .. suffix]
        if extra then extra:SetText("") extra:Hide() end
    end
    if slider.SetOrientation then slider:SetOrientation("HORIZONTAL") end
    slider:SetPoint("TOPLEFT", 2, -18)
    slider:SetSize(width - 6, 18)
    slider:SetMinMaxValues(minV, maxV)
    if slider.SetValueStep then slider:SetValueStep(1) end
    if slider.SetObeyStepOnDrag then pcall(slider.SetObeyStepOnDrag, slider, true) end

    slider:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v + 0.5)
        value:SetText(v)
        if self.syncing then return end
        db[key] = v
        FullRefresh()
        if previewHook then previewHook() end
    end)
    optionRefreshers[#optionRefreshers + 1] = function()
        slider.syncing = true
        slider:SetValue(db[key])
        slider.syncing = false
        value:SetText(db[key])
    end
end

local ROW_H = 26
local LEFT_W = 490   -- the settings column
local W = 920        -- the whole page in the standalone window; the options page uses its full width

local CONTENT_H = 540

local content              -- every control, in one frame
local window               -- standalone window, used only when the game's page can't open
local settingsPage, settingsCategory
local nativeOpenFailed = false
local UpdateMinimapButton  -- defined below

-- Builds every control into one frame. It is shown on the game's own
-- Options > AddOns > RangeLens page, or in a standalone window when that
-- page can't be opened.
local function BuildContent()
    local c = CreateFrame("Frame")
    c:SetSize(W, CONTENT_H)
    c:Hide()
    local PREVIEW_H = 200
    local top = -4 - PREVIEW_H - 14 -- everything else sits below the nameplate preview

    -- Display settings
    OptionCheck(c, "Nameplate icons", "plates", 16, top, RefreshAllPlates)
    OptionCheck(c, "Enemies only", "enemyOnly", 250, top, RefreshAllPlates)
    OptionCheck(c, "Target panel", "panel", 16, top - 26, UpdatePanel)
    OptionCheck(c, "Lock panel", "locked", 250, top - 26, function() LayoutPanel() UpdatePanel() end)
    OptionCheck(c, "Show cooldowns", "cooldowns", 16, top - 52, RefreshCooldowns)
    OptionCheck(c, "Show spell range", "showRange", 250, top - 52, FullRefresh)
    OptionCheck(c, "Only show spells in range", "inRangeOnly", 16, top - 78, FullRefresh)
    OptionCheck(c, "Minimap button", "minimap", 250, top - 78, function() UpdateMinimapButton() end)
    OptionCheck(c, "Distance on panel", "showDistance", 16, top - 104, UpdatePanel)
    OptionCheck(c, "Distance on nameplates", "plateDistance", 250, top - 104, RefreshAllPlates)
    OptionCheck(c, "Hide in melee range", "plateHideMelee", 16, top - 130, RefreshAllPlates)
    OptionCheck(c, "Only on target's nameplate", "plateTargetOnly", 16, top - 156, RefreshAllPlates)
    OptionCheck(c, "Only on focus's nameplate", "plateFocusOnly", 250, top - 156, RefreshAllPlates)
    local plateNote = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    plateNote:SetPoint("TOPLEFT", 20, top - 182)
    plateNote:SetWidth(LEFT_W - 36)
    plateNote:SetJustifyH("LEFT")
    plateNote:SetText("Tick both for target and focus; leave both clear for every enemy nameplate.")

    OptionSlider(c, "Panel icon size", "panelIconSize", 16, 80, 20, top - 210, 200)
    OptionSlider(c, "Nameplate icon size", "plateIconSize", 8, 40, 250, top - 210, 200)
    OptionSlider(c, "Nameplate up / down", "plateOffsetY", -100, 100, 20, top - 258, 200)
    OptionSlider(c, "Nameplate left / right", "plateOffsetX", -200, 200, 250, top - 258, 200)

    -- Spell list
    local header = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", LEFT_W + 10, top - 2)
    header:SetText("Spells to range check")
    local hint = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -3)
    hint:SetPoint("RIGHT", c, "RIGHT", -18, 0)
    hint:SetJustifyH("LEFT")
    hint:SetText("Your spellbook spells that have a range, plus spells that hit around you. Ticked spells sit at the top in icon order; < and > move one along the row. Unlock a spell to set its reach by hand.")

    -- Nameplate preview: a mock plate with the icon row as it will look on
    -- real ones. Drag an icon along the row and drop it to reorder.
    local preview = CreateFrame("Frame", nil, c)
    -- Across the whole page, so icons moved far left or right stay in view.
    preview:SetPoint("TOPLEFT", c, "TOPLEFT", 12, -4)
    preview:SetPoint("RIGHT", c, "RIGHT", -12, 0)
    preview:SetHeight(PREVIEW_H)
    if preview.SetClipsChildren then preview:SetClipsChildren(true) end
    local previewBg = preview:CreateTexture(nil, "BACKGROUND")
    previewBg:SetAllPoints()
    previewBg:SetColorTexture(0.12, 0.1, 0.08, 0.6)
    local previewLabel = preview:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    previewLabel:SetPoint("TOPLEFT", 8, -6)
    previewLabel:SetText("Nameplate preview: drag an icon to reorder")

    -- The mock plate is built like the game's own (Blizzard_NamePlates on
    -- WoW Forever): the Cooldown Manager bar art as the fill, its "Bar-BG"
    -- plate as the frame (2 left, 3 up, 6 right, 6 down past the bar), and
    -- the level badge 5 to the right. Default size: a 190 wide plate.
    local plate = CreateFrame("Frame", nil, preview)
    plate:SetAllPoints()
    local mockBar = plate:CreateTexture(nil, "ARTWORK")
    mockBar:SetPoint("CENTER", preview, "CENTER", 0, 0)
    if HasAtlas("UI-HUD-CoolDownManager-Bar") then
        mockBar:SetAtlas("UI-HUD-CoolDownManager-Bar")
    else
        mockBar:SetColorTexture(1, 1, 1, 1)
    end
    mockBar:SetVertexColor(0.9, 0.15, 0.1)
    local mockFrame = plate:CreateTexture(nil, "BACKGROUND")
    if HasAtlas("UI-HUD-CoolDownManager-Bar-BG") then
        mockFrame:SetAtlas("UI-HUD-CoolDownManager-Bar-BG")
    else
        mockFrame:SetColorTexture(0, 0, 0, 0.9)
    end
    mockFrame:SetPoint("TOPLEFT", mockBar, "TOPLEFT", -2, 3)
    mockFrame:SetPoint("BOTTOMRIGHT", mockBar, "BOTTOMRIGHT", 6, -6)
    local mockLevel = plate:CreateTexture(nil, "BACKGROUND")
    if HasAtlas("ui-hud-nameplates-levelindicator") then
        mockLevel:SetAtlas("ui-hud-nameplates-levelindicator")
    else
        mockLevel:SetColorTexture(0, 0, 0, 0.7)
    end
    mockLevel:SetPoint("LEFT", mockBar, "RIGHT", 4, -1)
    local mockLevelText = plate:CreateFontString(nil, "OVERLAY", _G.SystemFont_NamePlateLevel and "SystemFont_NamePlateLevel" or "GameFontHighlightSmall")
    mockLevelText:SetPoint("CENTER", mockLevel, "CENTER", 0, 0)
    mockLevelText:SetText("8")
    local mockName = plate:CreateFontString(nil, "OVERLAY", _G.SystemFont_NamePlate and "SystemFont_NamePlate" or "GameFontHighlightSmall")
    mockName:SetPoint("BOTTOM", mockBar, "TOP", 0, 2)
    mockName:SetText("Elder Mottled Boar")
    local mockBorder = mockBar -- the icon row hangs off the health bar, as on real plates

    local prow = CreateFrame("Frame", nil, plate) -- scaled with the mock plate
    prow.distance = prow:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    prow.distance:SetPoint("LEFT", prow, "RIGHT", 4, 0)
    local previewEmpty = preview:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    previewEmpty:SetPoint("TOP", mockBorder, "BOTTOM", 0, -10)

    -- Drop placeholder: an outlined gap where the dragged icon will land.
    local placeholder = CreateFrame("Frame", nil, prow)
    placeholder:Hide()
    local phFill = placeholder:CreateTexture(nil, "BACKGROUND")
    phFill:SetAllPoints()
    phFill:SetColorTexture(1, 0.82, 0, 0.15)
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = placeholder:CreateTexture(nil, "BORDER")
        t:SetColorTexture(1, 0.82, 0, 0.9)
        if side == "TOP" or side == "BOTTOM" then
            t:SetPoint(side .. "LEFT") t:SetPoint(side .. "RIGHT") t:SetHeight(1)
        else
            t:SetPoint("TOP" .. side) t:SetPoint("BOTTOM" .. side) t:SetWidth(1)
        end
    end

    local function DragSlot(icon)
        local cx, left = icon:GetCenter(), prow:GetLeft()
        if not (cx and left) then return nil end
        local slot = math.floor((cx - left) / (db.plateIconSize + 2)) + 1
        return math.max(1, math.min(prow.count or 1, slot))
    end

    -- Lay the other icons out around a gap at `slot`, with the placeholder in it.
    local function ShowGap(dragged, slot)
        local size, step = db.plateIconSize, db.plateIconSize + 2
        local k = 0
        for i = 1, prow.count or 0 do
            local icon = prow.icons[i]
            if icon ~= dragged then
                k = k + 1
                if k == slot then k = k + 1 end
                icon:ClearAllPoints()
                icon:SetPoint("LEFT", prow, "LEFT", (k - 1) * step, 0)
            end
        end
        placeholder:SetSize(size, size)
        placeholder:ClearAllPoints()
        placeholder:SetPoint("LEFT", prow, "LEFT", (slot - 1) * step, 0)
        placeholder:Show()
    end

    local function DropIcon(icon)
        prow:SetScript("OnUpdate", nil)
        placeholder:Hide()
        icon:StopMovingOrSizing()
        local slot = DragSlot(icon)
        if slot and icon.spell then
            local target = resolved[slot]
            if target then MoveSpell(icon.spell.query, target.query) end
        end
        FullRefresh()
        RefreshOptions()
    end

    local function StartDrag(icon)
        icon:SetFrameLevel(prow:GetFrameLevel() + 20)
        icon:StartMoving()
        local last
        prow:SetScript("OnUpdate", function()
            local slot = DragSlot(icon)
            if slot and slot ~= last then
                last = slot
                ShowGap(icon, slot)
            end
        end)
    end

    function c:UpdatePreview()
        -- Real plate size and the scale its icon row is drawn at, measured
        -- from a nameplate in game (see OnPlateAdded); defaults until then.
        local look, measured = PlateLook()
        local pe = preview:GetEffectiveScale() or 1
        if not (pe and pe > 0) then pe = 1 end
        -- The whole mock plate (bar, frame, badge, name, icon row) is drawn at the
        -- real row's scale, so fonts and icons come out the size they are in game.
        -- Draw at the options window's own scale, the way the game's nameplate
        -- preview is, whatever scale this page itself is shown at.
        local rowScale = look.rowScale or 1
        local ref = (SettingsPanel and SettingsPanel:IsShown() and SettingsPanel) or UIParent
        local okRef, refScale = pcall(ref.GetEffectiveScale, ref)
        if not okRef or type(refScale) ~= "number" or refScale <= 0 then refScale = pe end
        plate:SetScale(rowScale * refScale / pe)
        mockBar:SetSize(look.w / rowScale, look.h / rowScale)
        local size, style = PlateSettings()
        local h, v = PlateScale(size, style)
        mockLevel:SetSize(28 * h, 16 * h)
        -- Font sizes follow the Size setting, as Blizzard_NamePlates sets them:
        -- the name at 14 (10 for Classic) and the level at 10, times the vertical scale.
        local isClassic = Enum and Enum.NamePlateStyle and style == Enum.NamePlateStyle.Classic
        if mockName.SetTextHeight then mockName:SetTextHeight((isClassic and 10 or 14) * v) end
        if mockLevelText.SetTextHeight then mockLevelText:SetTextHeight(10 * v) end
        -- The Classic style draws the old bar and border; the others the Cooldown Manager bar.
        local classic = Enum and Enum.NamePlateStyle and style == Enum.NamePlateStyle.Classic
        if classic ~= c.classicLook then
            c.classicLook = classic
            if classic then
                mockBar:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
                mockFrame:SetTexture("Interface\\Tooltips\\Nameplate-Border")
                mockFrame:SetTexCoord(0, 1, 0.5, 1)
            else
                if HasAtlas("UI-HUD-CoolDownManager-Bar") then mockBar:SetAtlas("UI-HUD-CoolDownManager-Bar") end
                if HasAtlas("UI-HUD-CoolDownManager-Bar-BG") then mockFrame:SetAtlas("UI-HUD-CoolDownManager-Bar-BG") end
                mockFrame:SetTexCoord(0, 1, 0, 1)
            end
            mockBar:SetVertexColor(0.9, 0.15, 0.1)
        end
        previewLabel:SetText("Nameplate preview: drag an icon to reorder.  "
            .. (measured and "|cff80ff80Matches your nameplate settings.|r"
                or "|cffffd060Estimated until a nameplate is on screen.|r"))
        LayoutRow(prow, db.plateIconSize, 2, false)
        prow:ClearAllPoints()
        prow:SetPoint("TOP", mockBorder, "BOTTOM", db.plateOffsetX, db.plateOffsetY)
        for i = 1, prow.count or 0 do
            local icon = prow.icons[i]
            icon:Show()
            icon:SetAlpha(1)
            icon.lit:SetAlpha(1)
            SetLook(icon, "in")
            if not icon.draggable then
                icon.draggable = true
                icon:EnableMouse(true)
                icon:SetMovable(true)
                icon:RegisterForDrag("LeftButton")
                icon:SetScript("OnDragStart", StartDrag)
                icon:SetScript("OnDragStop", DropIcon)
                icon:SetScript("OnEnter", function(self)
                    if not self.spell then return end
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetText(self.spell.query, 1, 1, 1)
                    GameTooltip:AddLine("Drag to reorder", 0.7, 0.7, 0.7)
                    GameTooltip:Show()
                end)
                icon:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
        end
        prow.distance:SetText(db.plateDistance and "10-15" or "")
        prow:SetShown(db.plates and (prow.count or 0) > 0)
        if not db.plates then
            previewEmpty:SetText("Nameplate icons are switched off.")
        elseif (prow.count or 0) == 0 then
            previewEmpty:SetText("Tick spells below to see them here.")
        else
            previewEmpty:SetText("")
        end
    end
    previewHook = function() if c:IsVisible() then c:UpdatePreview() end end

    local area = CreateFrame("Frame", nil, c)
    local areaBg = area:CreateTexture(nil, "BACKGROUND")
    areaBg:SetAllPoints()
    areaBg:SetColorTexture(0, 0, 0, 0.35)
    area:SetPoint("TOPLEFT", c, "TOPLEFT", LEFT_W + 4, top - 50)
    area:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -12, 36)

    local ok, scroll = pcall(CreateFrame, "ScrollFrame", "RangeLensOptionsScroll", c, "RangeLensScrollFrameTemplate")
    if not (ok and scroll) then
        scroll = CreateFrame("ScrollFrame", "RangeLensOptionsScroll", c)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseWheel", function(self, delta)
            local range = self:GetVerticalScrollRange() or 0
            self:SetVerticalScroll(math.max(0, math.min(range, self:GetVerticalScroll() - delta * ROW_H * 3)))
        end)
    end
    scroll:SetPoint("TOPLEFT", area, "TOPLEFT", 6, -6)
    scroll:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -22, 6)
    local child = CreateFrame("Frame", nil, scroll)
    local childW = W - LEFT_W - 4 - 12 - 28
    child:SetSize(childW, 1)
    c.child = child
    scroll:SetScrollChild(child)
    c.rows = {}

    local function Row(i)
        local row = c.rows[i]
        if row then return row end
        row = CreateFrame("Button", nil, child)
        row:SetSize(c.childW or childW, ROW_H)
        local hl = row:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(1, 1, 1, 0.08)

        row.check = CreateCheck(row)
        row.check:SetPoint("TOPLEFT", 2, -1)
        row.icon = CreateIcon(row)
        SizeIcon(row.icon, 20, false)
        row.icon:SetPoint("LEFT", row.check, "RIGHT", 6, 0)
        row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -3)
        row.name:SetPoint("RIGHT", row, "RIGHT", -30, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetWordWrap(false)
        row.order = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        row.order:SetPoint("TOPRIGHT", -6, -6)

        -- < and >: move a tracked spell's icon one place left or right in the row.
        local function Move(delta)
            local from = FindEntry(row.spellName)
            local to = from and from + delta
            if not (to and to >= 1 and to <= #cdb.spells) then return end
            cdb.spells[from], cdb.spells[to] = cdb.spells[to], cdb.spells[from]
            FullRefresh()
            RefreshOptions()
        end
        row.later = TryCreate("Button", nil, row, { "UIPanelButtonTemplate" })
        row.later:SetSize(22, 18)
        row.later:SetPoint("TOPRIGHT", row, "TOPRIGHT", -88, -4)
        row.later:SetText(">")
        row.later:SetScript("OnClick", function() Move(1) end)
        row.earlier = TryCreate("Button", nil, row, { "UIPanelButtonTemplate" })
        row.earlier:SetSize(22, 18)
        row.earlier:SetPoint("RIGHT", row.later, "LEFT", -2, 0)
        row.earlier:SetText("<")
        row.earlier:SetScript("OnClick", function() Move(-1) end)

        -- Unlock: set this spell's reach by hand. Lock: back to automatic.
        row.unlock = TryCreate("Button", nil, row, { "UIPanelButtonTemplate" })
        row.unlock:SetSize(58, 18)
        row.unlock:SetPoint("TOPRIGHT", row, "TOPRIGHT", -24, -4)
        row.unlock:SetScript("OnClick", function()
            local name = row.spellName
            if Override(name) then
                SetOverride(name, nil)
            else
                SetOverride(name, row.auto or 10)
            end
            FullRefresh()
            RefreshOptions()
        end)

        -- The tuner, shown while unlocked: a slider and a box you can type in.
        row.tuner = CreateFrame("Frame", nil, row)
        row.tuner:SetPoint("TOPLEFT", row, "TOPLEFT", 34, -ROW_H + 2)
        row.tuner:SetPoint("RIGHT", row, "RIGHT", -8, 0)
        row.tuner:SetHeight(28)
        row.tuner:EnableMouse(true) -- clicks here don't tick or untick the spell
        local sliderName = "RangeLensTuneSlider" .. i
        local slider = TryCreate("Slider", sliderName, row.tuner, { "MinimalSliderTemplate", "UISliderTemplate", "OptionsSliderTemplate" })
        for _, suffix in ipairs({ "Low", "High", "Text" }) do
            local extra = _G[sliderName .. suffix]
            if extra then extra:SetText("") extra:Hide() end
        end
        if slider.SetOrientation then slider:SetOrientation("HORIZONTAL") end
        slider:SetPoint("LEFT", row.tuner, "LEFT", 0, 0)
        slider:SetSize(190, 16)
        slider:SetMinMaxValues(OVERRIDE_MIN, OVERRIDE_MAX)
        if slider.SetValueStep then slider:SetValueStep(1) end
        if slider.SetObeyStepOnDrag then pcall(slider.SetObeyStepOnDrag, slider, true) end
        row.slider = slider

        local box = TryCreate("EditBox", "RangeLensTuneBox" .. i, row.tuner, { "InputBoxTemplate" })
        box:SetSize(34, 20)
        box:SetPoint("LEFT", slider, "RIGHT", 14, 0)
        box:SetAutoFocus(false)
        box:SetNumeric(true)
        box:SetMaxLetters(2)
        box:SetJustifyH("CENTER")
        if not box:GetFontObject() then box:SetFontObject(ChatFontNormal) end
        row.box = box
        local unit = row.tuner:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        unit:SetPoint("LEFT", box, "RIGHT", 4, 0)
        unit:SetText("yd")

        slider:SetScript("OnValueChanged", function(self, v)
            v = math.floor(v + 0.5)
            if self.syncing then return end
            box:SetText(v)
            SetOverride(row.spellName, v)
            row.name:SetText(row.label(v))
            FullRefresh()
            if previewHook then previewHook() end
        end)
        local function Commit(self)
            local v = tonumber(self:GetText())
            if v then
                SetOverride(row.spellName, v)
                FullRefresh()
            end
            self:ClearFocus()
            RefreshOptions()
        end
        box:SetScript("OnEnterPressed", Commit)
        box:SetScript("OnEditFocusLost", function(self)
            if not self.committing then
                self.committing = true
                Commit(self)
                self.committing = false
            end
        end)
        box:SetScript("OnEscapePressed", function(self)
            self:SetText(Override(row.spellName) or "")
            self:ClearFocus()
        end)

        row.check:SetScript("OnClick", function(self)
            SetTracked(row.spellName, self:GetChecked() and true or false)
        end)
        row:SetScript("OnClick", function()
            SetTracked(row.spellName, not FindEntry(row.spellName))
        end)
        c.rows[i] = row
        return row
    end

    function c:Populate()
        local list = ScanSpellBook()
        -- Tracked spells first, in the order their icons appear; then the rest.
        for i, item in ipairs(list) do item.sortKey = FindEntry(item.name) or (1000 + i) end
        table.sort(list, function(a, b) return a.sortKey < b.sortKey end)
        local y = 0
        for i, item in ipairs(list) do
            local row = Row(i)
            row.spellName = item.name
            row.icon.dim:SetTexture(item.icon)
            row.icon.lit:SetTexture(item.icon)
            row.icon.lit:SetAlpha(1)
            local index = FindEntry(item.name)
            row.check:SetChecked(index ~= nil)
            row.icon.range:SetText("")
            local auto = item.auto
            row.auto = auto
            row.label = function(manualYards)
                local range = item.range
                if manualYards then range = manualYards .. " yd, set by hand" end
                return item.name
                    .. (range and (" |cffaaaaaa" .. range .. "|r") or "")
                    .. (item.unknown and " |cff888888(not in spellbook)|r" or "")
            end
            local manual = Override(item.name)
            row.name:SetText(row.label(manual))
            row.order:SetText(index and tostring(index) or "")
            local tunable = (auto ~= nil or manual ~= nil) and not item.unknown
            row.earlier:SetShown(index ~= nil)
            row.later:SetShown(index ~= nil)
            row.earlier:SetEnabled(index ~= nil and index > 1)
            row.later:SetEnabled(index ~= nil and index < #cdb.spells)
            row.unlock:SetShown(tunable)
            row.unlock:SetText(manual and "Lock" or "Unlock")
            row.name:ClearAllPoints()
            row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -3)
            row.name:SetPoint("RIGHT", row, "RIGHT", index and -140 or (tunable and -88 or -30), 0)
            row.tuner:SetShown(manual ~= nil)
            if manual then
                row.slider.syncing = true
                row.slider:SetValue(manual)
                row.slider.syncing = false
                if not row.box:HasFocus() then row.box:SetText(manual) end
            end
            local height = manual and (ROW_H + 30) or ROW_H
            row:SetSize(c.childW or childW, height)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
            y = y + height
            row:Show()
        end
        for i = #list + 1, #c.rows do c.rows[i]:Hide() end
        child:SetHeight(math.max(1, y))
        c.count:SetText(#cdb.spells .. " tracked")
    end

    local defaults = TryCreate("Button", nil, c, { "UIPanelButtonTemplate" })
    defaults:SetSize(120, 22)
    defaults:SetPoint("BOTTOMLEFT", LEFT_W + 6, 6)
    defaults:SetText("Class defaults")
    defaults:SetScript("OnClick", function()
        local _, class = UnitClass("player")
        wipe(cdb.spells)
        for _, s in ipairs(CLASS_DEFAULTS[class] or {}) do tinsert(cdb.spells, s) end
        FullRefresh()
        RefreshOptions()
    end)
    local clear = TryCreate("Button", nil, c, { "UIPanelButtonTemplate" })
    clear:SetSize(90, 22)
    clear:SetPoint("LEFT", defaults, "RIGHT", 6, 0)
    clear:SetText("Clear all")
    clear:SetScript("OnClick", function()
        wipe(cdb.spells)
        FullRefresh()
        RefreshOptions()
    end)
    c.count = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    c.count:SetPoint("BOTTOMRIGHT", -18, 12)

    function c:Resize(width, height)
        width = math.max(W, width or W)
        height = math.max(CONTENT_H, height or CONTENT_H)
        self:SetSize(width, height)
        self.childW = width - LEFT_W - 4 - 12 - 28
        child:SetWidth(self.childW)
    end

    c:SetScript("OnShow", function() RefreshOptions() end)
    return c
end

local function EnsureContent()
    if content then return content end
    local ok, made = pcall(BuildContent)
    if not ok then
        Print("the options could not be built: " .. tostring(made))
        return nil
    end
    content = made
    return content
end

-- Moves the controls into `parent`.
local function Host(parent, x, y, scale, width, height)
    scale = scale or 1
    content:Resize(width, height)
    content:SetParent(parent)
    content:ClearAllPoints()
    content:SetScale(scale)
    content:SetPoint("TOPLEFT", parent, "TOPLEFT", x / scale, y / scale)
    content:Show()
    RefreshOptions()
end

local function BuildWindow()
    local f, template = TryCreate("Frame", "RangeLensOptions", UIParent,
        { "ButtonFrameTemplate", "BasicFrameTemplateWithInset" })
    local top = template == "ButtonFrameTemplate" and -60 or -28
    f:SetSize(W, CONTENT_H - top + 6)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function(self) self:StartMoving() end)
    f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    f:Hide()
    tinsert(UISpecialFrames, "RangeLensOptions")

    if template == "bare" then
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.05, 0.07, 0.95)
    end
    if f.SetTitle then f:SetTitle("Range Lens")
    elseif f.TitleText then f.TitleText:SetText("Range Lens")
    elseif f.TitleContainer and f.TitleContainer.TitleText then f.TitleContainer.TitleText:SetText("Range Lens")
    else
        local t = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        t:SetPoint("TOP", 0, -8)
        t:SetText("Range Lens")
    end
    local portrait = "Interface\\Icons\\Ability_Hunter_SniperShot"
    if f.SetPortraitToAsset then pcall(f.SetPortraitToAsset, f, portrait)
    elseif f.PortraitContainer and f.PortraitContainer.portrait then f.PortraitContainer.portrait:SetTexture(portrait) end
    if not (f.CloseButton or _G["RangeLensOptionsCloseButton"]) then
        local close = TryCreate("Button", nil, f, { "UIPanelCloseButton" })
        close:SetPoint("TOPRIGHT", 2, 2)
        close:SetScript("OnClick", function() f:Hide() end)
    end

    f:SetScript("OnShow", function(self) Host(self, 0, top, 1) end)
    return f
end

local function ShowWindow()
    if not EnsureContent() then return end
    if not window then
        local ok, made = pcall(BuildWindow)
        if not ok then
            Print("the options window could not be built: " .. tostring(made))
            return
        end
        window = made
    end
    window:Show()
    if window.Raise then window:Raise() end
end

RefreshOptions = function()
    if not (content and content:IsVisible()) then return end
    for _, refresh in ipairs(optionRefreshers) do refresh() end
    content:Populate()
    content:UpdatePreview()
end

-- Opens Options > AddOns > RangeLens, the way Shard Grid's minimap button does.
-- If the game won't show it, the standalone window is used from then on.
-- A second click closes whichever is open.
-- The page is created without a parent, and a shown frame with no parent counts
-- as visible, so it is only open while the game's options panel is showing it.
local function PageOpen()
    return settingsPage ~= nil and SettingsPanel ~= nil and SettingsPanel:IsShown()
        and settingsPage:GetParent() ~= nil and settingsPage:IsVisible()
end

local function ToggleOptions()
    if PageOpen() then
        -- Closing a Blizzard panel from addon code may be refused; its own Close button always works.
        if SettingsPanel and HideUIPanel then pcall(HideUIPanel, SettingsPanel) end
        return
    end
    if window and window:IsShown() then
        window:Hide()
        return
    end
    if settingsCategory and Settings and Settings.OpenToCategory and not nativeOpenFailed then
        local id = settingsCategory.GetID and settingsCategory:GetID() or settingsCategory.ID or settingsCategory
        pcall(Settings.OpenToCategory, id)
        -- Trust what is on screen, not the call's return value.
        if PageOpen() then return end
        nativeOpenFailed = true
    end
    ShowWindow()
end

panel:SetScript("OnMouseUp", function(_, button)
    if button == "RightButton" then ToggleOptions() end
end)

-- The Options > AddOns > RangeLens page. A canvas page only: proxy settings
-- (Settings.RegisterProxySetting) tainted Blizzard's nameplates on WoW Forever.
local function RegisterOptionsPage()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local page = CreateFrame("Frame")
    local title = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Range Lens")
    page:SetScript("OnShow", function(self)
        if not EnsureContent() then return end
        if window and window:IsShown() then window:Hide() end
        local w, h = self:GetWidth() or 0, self:GetHeight() or 0
        local scale = 1
        if w > 0 and h > 0 then scale = math.min(1, (w - 12) / W, (h - 50) / CONTENT_H) end
        -- Fill the page: the spell list takes all the width and height left.
        Host(self, 6, -42, scale, (w - 12) / scale, (h - 50) / scale)
    end)
    page:SetScript("OnSizeChanged", function(self)
        if self:IsVisible() and content and content:GetParent() == self then
            self:GetScript("OnShow")(self)
        end
    end)
    local category = Settings.RegisterCanvasLayoutCategory(page, "Range Lens")
    if category then
        Settings.RegisterAddOnCategory(category)
        settingsPage, settingsCategory = page, category
    end
end

-- Minimap button: left-click options, right-click lock/unlock the panel,
-- drag to move it round the rim. Same build as Shard Grid's.
local mmButton

local function PlaceMinimapButton()
    if not mmButton then return end
    local angle = math.rad(db.minimapAngle or 200)
    local radius = (Minimap:GetWidth() or 140) / 2 + 6
    mmButton:ClearAllPoints()
    mmButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

UpdateMinimapButton = function()
    if not Minimap then return end
    if not mmButton then
        if not db.minimap then return end
        mmButton = CreateFrame("Button", "RangeLensMinimapButton", Minimap)
        mmButton:SetSize(31, 31)
        mmButton:SetFrameStrata("MEDIUM")
        mmButton:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
        mmButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        mmButton:RegisterForDrag("LeftButton")
        mmButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

        local bg = mmButton:CreateTexture(nil, "BACKGROUND")
        bg:SetSize(20, 20)
        bg:SetPoint("TOPLEFT", 7, -5)
        bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

        local icon = mmButton:CreateTexture(nil, "ARTWORK")
        icon:SetSize(18, 18)
        icon:SetPoint("TOPLEFT", 7, -6)
        icon:SetTexture("Interface\\Icons\\Ability_Hunter_SniperShot")
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        local border = mmButton:CreateTexture(nil, "OVERLAY")
        border:SetSize(53, 53)
        border:SetPoint("TOPLEFT")
        border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

        mmButton:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                db.locked = not db.locked
                LayoutPanel()
                UpdatePanel()
                RefreshOptions()
                Print("panel " .. (db.locked and "locked" or "unlocked, drag to move"))
            else
                ToggleOptions()
            end
        end)
        mmButton:SetScript("OnDragStart", function(self)
            self:SetScript("OnUpdate", function()
                local mx, my = Minimap:GetCenter()
                local scale = Minimap:GetEffectiveScale()
                local cx, cy = GetCursorPosition()
                if not (mx and my and cx and cy) then return end
                db.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx)) % 360
                PlaceMinimapButton()
            end)
        end)
        mmButton:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
        mmButton:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText("Range Lens", 1, 1, 1)
            GameTooltip:AddLine(#cdb.spells .. " spells tracked", 0.31, 0.7, 1)
            GameTooltip:AddLine("Left-click: options", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Right-click: lock / unlock the panel", 0.7, 0.7, 0.7)
            GameTooltip:AddLine("Drag: move around the minimap", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        mmButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    mmButton:SetShown(db.minimap and true or false)
    PlaceMinimapButton()
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------

local function ParseSpellArg(arg)
    arg = strtrim(arg or "")
    if arg == "" then return nil end
    return tonumber(arg) or arg
end

local HELP = {
    "/rl - open the options (Options > AddOns > Range Lens)",
    "/rl minimap - show or hide the minimap button",
    "/rl debug - print the range answers for your target and each nameplate",
    "/rl add <spell name or ID> - track a spell",
    "/rl remove <spell or list number> - stop tracking",
    "/rl list - show tracked spells",
    "/rl clear | /rl defaults - empty the list or load class defaults",
    "/rl plates | /rl panel - toggle nameplate icons or target panel",
    "/rl enemy - toggle enemies-only on nameplates",
    "/rl targetonly | /rl focusonly - limit nameplate icons to your target, your focus, or both",
    "/rl melee - toggle hiding nameplate icons in melee range",
    "/rl cooldowns - toggle cooldown swipes",
    "/rl inrange - show only the spells that can reach (no red icons)",
    "/rl reach <spell> <yards> - set a spell's reach by hand; /rl reach <spell> sets it back to automatic",
    "/rl range - toggle the spell range number on icons",
    "/rl distance | /rl platedistance - toggle the distance on the panel or on nameplates",
    "/rl lock | /rl unlock - lock or move the target panel",
    "/rl size <n> | /rl panelsize <n> - icon sizes",
    "/rl offset <n> | /rl offsetx <n> - nameplate row up/down and left/right",
    "/rl dim <0-1> - strength of the out-of-range look",
    "/rl reset - restore all settings (keeps spell list)",
}

local function OnOff(v) return v and "|cff40ff40on|r" or "|cffff4040off|r" end

local function Slash(msg)
    local cmd, rest = strsplit(" ", strtrim(msg or ""), 2)
    cmd = (cmd or ""):lower()

    if cmd == "" or cmd == "options" or cmd == "config" then
        ToggleOptions()
        return
    elseif cmd == "add" then
        local q = ParseSpellArg(rest)
        if not q then return Print("usage: /rl add <spell name or ID>") end
        if FindEntry(q) and type(q) ~= "number" then return Print("already tracking " .. tostring(q)) end
        local name = SpellInfo(q)
        if not name then
            Print(tostring(q) .. " isn't in your spellbook right now. Added anyway; it will show once learned.")
        elseif not Truthy(SpellHasRange(name), true) then
            local radius = AoeRadius(name, select(3, SpellInfo(q)))
            if not radius then
                Print(name .. " has no range, so it will never light up.")
            end
        end
        tinsert(cdb.spells, name or q)
        FullRefresh()
        Print("tracking " .. tostring(name or q))
    elseif cmd == "remove" or cmd == "rm" then
        local q = ParseSpellArg(rest)
        local i = q and FindEntry(q)
        if not i then return Print("not found: " .. tostring(q)) end
        local removed = tremove(cdb.spells, i)
        FullRefresh()
        Print("removed " .. tostring(removed))
    elseif cmd == "list" then
        if #cdb.spells == 0 then return Print("no spells tracked. /rl add <spell> or /rl defaults") end
        for i, entry in ipairs(cdb.spells) do
            local name = SpellInfo(entry)
            Print(i .. ". " .. tostring(name or entry) .. (name and "" or " |cff888888(not known)|r"))
        end
    elseif cmd == "clear" then
        wipe(cdb.spells)
        FullRefresh()
        Print("spell list cleared")
    elseif cmd == "defaults" then
        local _, class = UnitClass("player")
        wipe(cdb.spells)
        for _, s in ipairs(CLASS_DEFAULTS[class] or {}) do tinsert(cdb.spells, s) end
        FullRefresh()
        Print("loaded defaults for " .. tostring(class) .. " (" .. #resolved .. " known)")
    elseif cmd == "plates" then
        db.plates = not db.plates
        RefreshAllPlates()
        Print("nameplate icons " .. OnOff(db.plates))
    elseif cmd == "panel" then
        db.panel = not db.panel
        UpdatePanel()
        Print("target panel " .. OnOff(db.panel))
    elseif cmd == "targetonly" then
        db.plateTargetOnly = not db.plateTargetOnly
        RefreshAllPlates()
        Print("target's nameplate only " .. OnOff(db.plateTargetOnly))
    elseif cmd == "reach" then
        local text = strtrim(rest or "")
        local spellName, n = text:match("^(.-)%s+(%d+)$")
        spellName = strtrim(spellName or text)
        spellName = SpellInfo(spellName) or spellName -- the game's spelling and case
        if spellName == "" or not (SpellInfo(spellName) or AOE_RADIUS[spellName]) then
            return Print("usage: /rl reach <spell> <yards>, or /rl reach <spell> for automatic")
        end
        SetOverride(spellName, n and tonumber(n) or nil)
        FullRefresh()
        local manual = Override(spellName)
        Print(spellName .. (manual and (": set by hand to " .. manual .. " yd") or ": back to automatic"))
    elseif cmd == "inrange" then
        db.inRangeOnly = not db.inRangeOnly
        FullRefresh()
        Print("only show spells in range " .. OnOff(db.inRangeOnly))
    elseif cmd == "focusonly" then
        db.plateFocusOnly = not db.plateFocusOnly
        RefreshAllPlates()
        Print("focus's nameplate only " .. OnOff(db.plateFocusOnly))
    elseif cmd == "melee" then
        db.plateHideMelee = not db.plateHideMelee
        RefreshAllPlates()
        Print("hide nameplate icons in melee range " .. OnOff(db.plateHideMelee))
    elseif cmd == "enemy" then
        db.enemyOnly = not db.enemyOnly
        RefreshAllPlates()
        Print("enemies only " .. OnOff(db.enemyOnly))
    elseif cmd == "cooldowns" then
        db.cooldowns = not db.cooldowns
        RefreshCooldowns()
        Print("cooldowns " .. OnOff(db.cooldowns))
    elseif cmd == "debug" then
        -- What the game answers for every tracked spell on the target and each nameplate.
        local function Show(v)
            if isSecret(v) then return "|cffff80ffsecret|r" end
            if v == nil then return "|cff888888nil|r" end
            return v and "|cff40ff40true|r" or "|cffff4040false|r"
        end
        Print(("version %s, %d spells resolved, nameplate icons %s, enemies only %s"):format(
            tostring(C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")),
            #resolved, OnOff(db.plates), OnOff(db.enemyOnly)))
        local units = { "target" }
        for unit in pairs(plateUnits) do units[#units + 1] = unit end
        local shown = 0
        for _, unit in ipairs(units) do
            if Truthy(UnitExists(unit), true) then
                local parts = {}
                for _, spell in ipairs(resolved) do
                    local _, _, _, minR, maxR = SpellInfo(spell.query)
                    local reach = spell.aoe and (spell.aoe .. "yd around") or ((isSecret(maxR) and "?" or tostring(maxR)) .. "yd")
                    local answer = CheckSpell(spell, unit)
                    parts[#parts + 1] = spell.query .. "[" .. reach .. "]=" .. Show(answer)
                        .. ((answer == false and TooClose(spell, unit)) and " (too close)" or "")
                end
                local d = {}
                for _, c in ipairs(Checkers()) do
                    d[#d + 1] = c.yards .. (c.item and ("yd item " .. c.item) or "yd interact") .. " " .. Show(RunChecker(c, unit))
                end
                Print("  distance " .. tostring(DistanceText(unit)) .. " yd; checks: " .. (#d > 0 and table.concat(d, ", ") or "none")
                    .. (interactBlocked and " (interact blocked this session)" or "")
                    .. (tradeBroken and " (9 yd trade check dropped: it said no inside 8 yd)" or ""))
                local row = activePlates[unit]
                Print(("%s %s: attackable %s, icons %s | %s"):format(unit, tostring(UnitName(unit)),
                    Show(UnitCanAttack("player", unit)),
                    unit == "target" and "(panel)" or (row and (row:IsShown() and "shown" or "hidden") or "|cffff4040none|r"),
                    table.concat(parts, ", ")))
                shown = shown + 1
            end
        end
        if shown == 0 then Print("no target and no nameplates in view") end
    elseif cmd == "minimap" then
        db.minimap = not db.minimap
        UpdateMinimapButton()
        Print("minimap button " .. OnOff(db.minimap))
    elseif cmd == "distance" then
        db.showDistance = not db.showDistance
        UpdatePanel()
        Print("distance on panel " .. OnOff(db.showDistance))
    elseif cmd == "platedistance" then
        db.plateDistance = not db.plateDistance
        RefreshAllPlates()
        Print("distance on nameplates " .. OnOff(db.plateDistance))
    elseif cmd == "range" then
        db.showRange = not db.showRange
        FullRefresh()
        Print("spell range numbers " .. OnOff(db.showRange))
    elseif cmd == "lock" or cmd == "unlock" then
        db.locked = (cmd == "lock")
        LayoutPanel()
        UpdatePanel()
        Print("panel " .. (db.locked and "locked" or "unlocked, drag to move"))
    elseif cmd == "size" or cmd == "panelsize" or cmd == "offset" or cmd == "offsetx" or cmd == "dim" then
        local n = tonumber(rest)
        if not n then return Print("usage: /rl " .. cmd .. " <number>") end
        if cmd == "size" then db.plateIconSize = math.max(8, math.min(48, n))
        elseif cmd == "panelsize" then db.panelIconSize = math.max(12, math.min(96, n))
        elseif cmd == "offset" then db.plateOffsetY = n
        elseif cmd == "offsetx" then db.plateOffsetX = n
        else db.outAlpha = math.max(0, math.min(1, n)) end
        FullRefresh()
        Print(cmd .. " set to " .. n)
    elseif cmd == "reset" then
        local spells = cdb.spells
        wipe(db)
        CopyDefaults(DEFAULTS, db)
        cdb.spells = spells
        PlacePanel()
        StartTicker()
        FullRefresh()
        Print("settings reset")
    else
        Print("commands:")
        for _, line in ipairs(HELP) do print("  " .. line) end
    end
    RefreshOptions()
end

SLASH_RANGELENS1 = "/rangelens"
SLASH_RANGELENS2 = "/rl"
SlashCmdList.RANGELENS = Slash

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("SPELLS_CHANGED")
ev:RegisterEvent("SPELL_UPDATE_COOLDOWN")
ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
ev:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
ev:RegisterEvent("PLAYER_TARGET_CHANGED")
ev:RegisterEvent("CVAR_UPDATE")
pcall(ev.RegisterEvent, ev, "PLAYER_FOCUS_CHANGED")
ev:RegisterEvent("ADDON_ACTION_BLOCKED")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")
-- Talent changes: re-read every spell's range (not every client has every event).
for _, e in ipairs({ "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED" }) do
    pcall(ev.RegisterEvent, ev, e)
end
ev:RegisterEvent("ADDON_ACTION_FORBIDDEN")

local ready = false

ev:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        RangeLensDB = RangeLensDB or {}
        RangeLensDB.override = RangeLensDB.override or {}
        -- 1.10.4: earlier measurements were in screen pixels and varied with the
        -- game's distance and target scaling; measure again, relative to the plate.
        if RangeLensDB.plateLooksBase ~= 2 then
            RangeLensDB.plateLooks, RangeLensDB.plateLook = nil, nil
            RangeLensDB.plateLooksBase = 2
        end
        -- 1.6.0 kept +/- tuning as yards from the radius; it is now a reach set by hand.
        if RangeLensDB.reach then
            for name, delta in pairs(RangeLensDB.reach) do
                local radius = AOE_RADIUS[name]
                if radius and delta ~= (DEFAULT_REACH_ADJUST[name] or 0) and RangeLensDB.override[name] == nil then
                    RangeLensDB.override[name] = math.max(OVERRIDE_MIN, radius + delta)
                end
            end
            RangeLensDB.reach = nil
        end
        RangeLensCharDB = RangeLensCharDB or {}
        cdb = RangeLensCharDB
        -- 1.3.0: settings are per character (the folder the game saves
        -- RangeLensCharDB in is per character). A character without its own
        -- yet starts from the settings shared before, so nothing resets.
        if not cdb.settings then cdb.settings = DeepCopy(RangeLensDB) end
        db = cdb.settings
        -- 1.3.0: the out-of-range look is full strength by default; 0.1.0 saved
        -- 0.45, which CopyDefaults never replaces.
        if not db.outAlphaFixed then
            if db.outAlpha == 0.45 then db.outAlpha = nil end
            db.outAlphaFixed = true
        end
        -- 0.3.1 moved the nameplate row down; carry the old default across.
        if not db.offsetMoved then
            if db.plateOffsetY == -2 then db.plateOffsetY = nil end
            db.offsetMoved = true
        end
        CopyDefaults(DEFAULTS, db)
        if not cdb.spells then
            local _, class = UnitClass("player")
            cdb.spells = {}
            for _, s in ipairs(CLASS_DEFAULTS[class] or {}) do tinsert(cdb.spells, s) end
        end
    elseif event == "PLAYER_LOGIN" then
        ready = true
        PlacePanel()
        FullRefresh()
        StartTicker()
        SetRaceDistances()
        LoadRangeItems()
        pcall(RegisterOptionsPage)
        UpdateMinimapButton()
    elseif not ready then
        -- Remember plates that appear before login so FullRefresh picks them up.
        if event == "NAME_PLATE_UNIT_ADDED" then plateUnits[arg1] = true
        elseif event == "NAME_PLATE_UNIT_REMOVED" then plateUnits[arg1] = nil end
        return
    elseif event == "SPELLS_CHANGED" or event == "CHARACTER_POINTS_CHANGED"
        or event == "PLAYER_TALENT_UPDATE" or event == "TRAIT_CONFIG_UPDATED" then
        FullRefresh()
        RefreshOptions()
    elseif event == "SPELL_UPDATE_COOLDOWN" then
        RefreshCooldowns()
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        plateUnits[arg1] = true
        OnPlateAdded(arg1)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        plateUnits[arg1] = nil
        OnPlateRemoved(arg1)
    elseif event == "PLAYER_TARGET_CHANGED" then
        if db.plateTargetOnly then RefreshAllPlates() end
        UpdatePanel()
    elseif event == "CVAR_UPDATE" then
        -- Size or Style changed in Options > Nameplates: the plates on screen
        -- are rebuilt by the game, so measure them again a moment later.
        local name = type(arg1) == "string" and arg1:lower() or ""
        if name == "nameplatesize" or name == "nameplatestyle" then
            C_Timer.After(0.3, function()
                for unit, row in pairs(activePlates) do
                    local plate = C_NamePlate.GetNamePlateForUnit(unit)
                    if plate and not plate:IsForbidden() then MeasurePlate(plate, row, PlateAnchor(plate)) end
                end
                if previewHook then previewHook() end
            end)
        end
    elseif event == "PLAYER_FOCUS_CHANGED" then
        if db.plateFocusOnly then RefreshAllPlates() end
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        OnItemLoaded(arg1, arg2)
    elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        -- The only call here that could be refused is CheckInteractDistance;
        -- the item checks carry on without it.
        if arg1 == ADDON_NAME and not interactBlocked then
            interactBlocked = true
            checkerCache = nil
            Print("the game refused an interact distance check; using item checks only this session.")
        end
    end
end)
