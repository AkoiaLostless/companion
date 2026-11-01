-- cmp/ui/petframe.lua - the pet window for every pet that is not an automaton
-- (cmp/pets.lua decides which, and builds tm.petView): the pet's name, how far
-- it is and its timer; HP, MP and TP; what is on it; what it is fighting; and
-- your recasts for its job as a list. Drawn in the main panel's window, so it
-- sits where the panel sits, and narrower than the panel: it carries less.
-- Exports draw().
local imgui = require('imgui')
local config = require('cmp.config')
local tm = require('cmp.state')
local SF = require('cmp.ui.surface')
local COL_TEXT, COL_DIM, COL_GOOD, COL_WARN, COL_BAD = SF.COL_TEXT, SF.COL_DIM, SF.COL_GOOD, SF.COL_WARN, SF.COL_BAD
local COL_MP, COL_TP, COL_TPUP, HUD_FLAGS = SF.COL_MP, SF.COL_TP, SF.COL_TPUP, SF.HUD_FLAGS
local hudPad, hudInner, tip = SF.hudPad, SF.hudInner, SF.tip
local petStatusStrip = SF.petStatusStrip

-- The window's width at 100%, against the panel's config.base_width.
local PET_WIDTH = 420

local KIND_TAG = { jug = 'Jug', charmed = 'Charmed', avatar = 'Avatar', wyvern = 'Wyvern' }
local NO_PET = { charmed = 'No Pet Out', avatar = 'No Avatar Out', wyvern = 'No Wyvern Out' }

-- The tag after the name is a bubble, light green for a jug pet and gold for
-- a charmed one, so which kind is out reads at a glance. Avatar and wyvern
-- tags stay plain.
local KIND_EDGE = { jug = { 0.55, 0.90, 0.55, 1.0 }, charmed = { 1.00, 0.80, 0.30, 1.0 } }

-- HP and TP, and MP when the pet has a pool to show: an avatar always (its MP
-- is yours, but a summoner reads it there), anything else only once it
-- reports some. A wyvern or a jug with no MP gets two wider bars, not an
-- empty third.
local function vitals(pet, showMp)
    local pad  = imgui.GetStyle().ItemSpacing.x
    local n    = showMp and 3 or 2
    local barW = (hudInner() - pad * (n - 1)) / n
    local hpp, tp = pet.hpp or 0, pet.tp or 0
    local hpCol = COL_GOOD
    if hpp < 40 then hpCol = COL_BAD elseif hpp < 75 then hpCol = COL_WARN end
    tm.bar(nil, hpp / 100, nil, hpCol, barW)
    if showMp then
        imgui.SameLine()
        tm.bar(nil, (pet.mpp or 0) / 100, nil, pet.mpp and COL_MP or COL_DIM, barW)
    end
    imgui.SameLine()
    tm.bar(nil, math.min(tp, 1000) / 1000, nil, (tp >= 1000) and COL_TPUP or COL_TP, barW)
    local function under(i, label, value)
        if i > 1 then imgui.SameLine(hudPad() + (i - 1) * (barW + pad), 0) end
        tm.text('label', COL_DIM, label)
        imgui.SameLine(0, tm.s(4))
        tm.text('label', COL_TEXT, value)
    end
    under(1, 'HP', ('%d%%'):format(hpp))
    if showMp then under(2, 'MP', pet.mpp and ('%d%%'):format(pet.mpp) or '?') end
    under(n, 'TP', ('%d'):format(tp))
end

-- The kind tag; a jug or charmed one is a filled bubble, light green or gold
-- with no rim, with the word in near-black on it so it reads against
-- the light fill. Drawn straight onto the draw list, with no shadow, since a
-- shadow under dark text on a light fill only smudges it.
local BUBBLE_TEXT = { 0.05, 0.05, 0.05, 1 }
local function tagText(kind)
    local fill = KIND_EDGE[kind]
    if fill == nil then
        tm.text('label', COL_DIM, KIND_TAG[kind])
        return
    end
    local s = KIND_TAG[kind]
    local padX, padY = tm.s(6), tm.s(1)
    imgui.PushFont(tm.font, tm.px('label'))
    local w, h = imgui.CalcTextSize(s)
    local x, y = imgui.GetCursorScreenPos()
    local dl = imgui.GetWindowDrawList()
    local r = (h + padY * 2) / 2
    dl:AddRectFilled({ x, y - padY }, { x + w + padX * 2, y + h + padY }, tm.u32(fill), r)
    dl:AddText({ x + padX, y }, tm.u32(BUBBLE_TEXT), s)
    imgui.PopFont()
    imgui.Dummy({ w + padX * 2, h })
end

-- The jug's time left, or the charm's time so far, at the end of the name line.
local function timerText(t)
    if t == nil then return end
    imgui.SameLine(0, tm.s(8))
    if t.left ~= nil then
        local col = (t.left <= 60) and COL_BAD or (t.left <= 300) and COL_WARN or COL_TEXT
        tm.text('text', col, (t.charm and '~' or '') .. tm.fmtLeft(t.left))
        if t.charm then
            tip(('Estimated time before the charm wears off (%s in all), from\nthe server\'s formula: your CHR, your level against the mob\'s\n(from the /check on Charm) and your charm-time gear. It can\nbreak sooner.')
                :format(tm.fmtLeft(t.total)))
        else
            tip(('Time left before the jug pet leaves (%s in all).'):format(tm.fmtLeft(t.total)))
        end
    else
        tm.text('text', COL_TEXT, tm.fmtLeft(t.since))
        tip('Time since you charmed it. It counts down instead once a /check\nof the mob has said its level (charm check, Settings).')
    end
end

local function body(v)
    local pet = v.pet
    if pet ~= nil then
        tm.head(COL_TEXT, pet.name or 'pet')
        if pet.dist ~= nil then
            imgui.SameLine(0, tm.s(6))
            tm.text('label', COL_DIM, ('%.1fy'):format(pet.dist))
            tip('Yalms between you and your pet.')
        end
        if KIND_TAG[v.kind] then
            imgui.SameLine(0, tm.s(6))
            tagText(v.kind)
        end
        timerText(v.timer)
        vitals(pet, v.kind == 'avatar' or (pet.mpp or 0) > 0)
        petStatusStrip()
        tm.targetRow()
    elseif v.kind ~= nil then
        -- out, but too far for the client to draw: nothing to read
        tm.text('text', COL_DIM, 'Pet Out of Range')
    else
        tm.text('text', COL_DIM, NO_PET[v.listKind] or 'No Pet Out')
    end
    if #v.rows > 0 then
        imgui.Separator()
        tm.jaGrid(nil, nil, nil, v.rows)
    end
end

-- The panel's look and window, at the pet window's width. hudInner() and
-- every helper that sizes off it read config.base_width, so the width is
-- swapped for the draw and put back however the draw ends.
local function draw()
    local v = tm.petView
    if v == nil then return end
    tm.rescale()
    local width = config.base_width
    config.base_width = PET_WIDTH
    tm.panelPush()
    imgui.SetNextWindowSize({ tm.s(PET_WIDTH), 0 }, ImGuiCond_FirstUseEver)
    local ok, err = true, nil
    if imgui.Begin('companion', nil, HUD_FLAGS) then
        ok, err = pcall(body, v)
    end
    imgui.End()
    tm.panelPop()
    config.base_width = width
    if not ok then error(err, 0) end
end

return { draw = draw }
