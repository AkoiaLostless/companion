-- pw/ui/petframe.lua - the pet window for every pet that is not an automaton
-- (pw/pets.lua decides which, and builds tm.petView): the pet's name, how far
-- it is and its timer; HP, MP and TP; what is on it; what it is fighting; and
-- your recasts for its job as a list. Drawn in the main panel's window, so it
-- sits where the panel sits, and narrower than the panel: it carries less.
-- Exports draw().
local imgui = require('imgui')
local config = require('pw.config')
local tm = require('pw.state')
local SF = require('pw.ui.surface')
local COL_TEXT, COL_DIM, COL_GOOD, COL_WARN, COL_BAD = SF.COL_TEXT, SF.COL_DIM, SF.COL_GOOD, SF.COL_WARN, SF.COL_BAD
local COL_MP, COL_TP, COL_TPUP, HUD_FLAGS = SF.COL_MP, SF.COL_TP, SF.COL_TPUP, SF.HUD_FLAGS
local hudPad, hudInner, tip = SF.hudPad, SF.hudInner, SF.tip
local petStatusStrip = SF.petStatusStrip

-- The window's width at 100%, against the panel's config.base_width.
local PET_WIDTH = 260

local KIND_TAG = { jug = 'jug', charmed = 'charmed', avatar = 'avatar', wyvern = 'wyvern' }
local NO_PET = { charmed = 'no pet out', avatar = 'no avatar out', wyvern = 'no wyvern out' }

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

-- The jug's time left, or the charm's time so far, at the end of the name line.
local function timerText(t)
    if t == nil then return end
    imgui.SameLine(0, tm.s(8))
    if t.left ~= nil then
        local col = (t.left <= 60) and COL_BAD or (t.left <= 300) and COL_WARN or COL_TEXT
        tm.text('text', col, tm.fmtLeft(t.left))
        tip(('Time left before the jug pet leaves (%s in all).'):format(tm.fmtLeft(t.total)))
    else
        tm.text('text', COL_TEXT, tm.fmtLeft(t.since))
        tip('Time since you charmed it. When a charm wears off depends on\nyour CHR and the pet\'s level, so this counts up rather than down.')
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
            tm.text('label', COL_DIM, KIND_TAG[v.kind])
        end
        timerText(v.timer)
        vitals(pet, v.kind == 'avatar' or (pet.mpp or 0) > 0)
        petStatusStrip()
        tm.targetRow()
    elseif v.kind ~= nil then
        -- out, but too far for the client to draw: nothing to read
        tm.text('text', COL_DIM, 'pet out of range')
    else
        tm.text('text', COL_DIM, NO_PET[v.listKind] or 'no pet out')
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
    if imgui.Begin('petworks', nil, HUD_FLAGS) then
        ok, err = pcall(body, v)
    end
    imgui.End()
    tm.panelPop()
    config.base_width = width
    if not ok then error(err, 0) end
end

return { draw = draw }
