-- cmp/cooldowns.lua - your own job abilities' recasts, for the Status tab's
-- recast column. The client keeps these itself, so they are READ, not
-- modelled: nothing here is logged, and there is nothing to calibrate. Native
-- reads, so render thread only - the packet thread must never require this
-- file. Publishes tm.jaList, tm.jaBuild and tm.jaRefresh; tm.jaRefresh writes
-- tm.jaRows.
local config = require('cmp.config')
local tm = require('cmp.state')
local U  = require('cmp.util')
local safe, player = U.safe, U.player

-- The PUP job abilities, in the order the column lists them: bringing the
-- automaton back, keeping it alive, the next maneuver, the tank tools, then
-- the ten-second housekeeping and the two-hour. `short` is the name under a
-- dial (DEA is the usual shorthand for Deus Ex, so Deactivate is Dct).
-- `ability` is LSB's abilityId, `timer` its recastId (sql/abilities.sql),
-- which is the id the server puts in the client's recast table. Each is
-- listed while config['cd_' .. key] is on. Tactical Switch, Cooldown and
-- Heady Artifice are past the level cap.
tm.jaList = {
    { key = 'activate',      label = 'Activate',   short = 'Act', name = 'Activate',         ability = 136, timer = 205 },
    { key = 'dea',           label = 'Deus Ex',    short = 'DEA', name = 'Deus Ex Automata', ability = 310, timer = 115 },
    { key = 'repair',        label = 'Repair',     short = 'Rep', name = 'Repair',           ability = 137, timer = 206 },
    -- LSB tags it ABYSSEA; HasAbility says whether this server grants it
    { key = 'maintenance',   label = 'Maint.',     short = 'Mnt', name = 'Maintenance',      ability = 322, timer = 214 },
    -- all eight maneuvers share timer 210, so one row; Fire Maneuver stands in
    -- for the eight when asking whether you have them
    { key = 'maneuver',      label = 'Maneuver',   short = 'Man', name = 'Maneuver',         ability = 141, timer = 210 },
    { key = 'role_reversal', label = 'Reversal',   short = 'RR',  name = 'Role Reversal',    ability = 179, timer = 211 },
    { key = 'ventriloquy',   label = 'Ventrilo',   short = 'Ven', name = 'Ventriloquy',      ability = 180, timer = 212 },
    { key = 'deploy',        label = 'Deploy',     short = 'Dep', name = 'Deploy',           ability = 138, timer = 207 },
    { key = 'retrieve',      label = 'Retrieve',   short = 'Ret', name = 'Retrieve',         ability = 140, timer = 209 },
    { key = 'deactivate',    label = 'Deactivate', short = 'Dct', name = 'Deactivate',       ability = 139, timer = 208 },
    -- the two-hour: slot 0 of the recast table, whose timer id is 0
    { key = 'overdrive',     label = 'Overdrive',  short = 'OD',  name = 'Overdrive',        ability = 135, timer = 0 },
}

-- HasAbility takes the resource id, which for a job ability is 0x200 on top of
-- LSB's abilityId: thotbar scans GetAbilityById over 0x200..0x600 for them and
-- XIUI hands HasAbility that same id. Inferred from those two, not read off
-- the SDK. If it is wrong, every row reads as unlearned and the group is
-- simply absent - never a wrong number.
local JA_RESOURCE = 0x200

-- Seconds left on every recast the client is counting, by timer id. A ready
-- ability holds no slot at all. Slot 0 is the two-hour and its timer id is 0,
-- which in any other slot means empty - hence (id ~= 0 or i == 0), the guard
-- Ashita's own recast addon uses. The timer counts 1/60 s ticks.
-- The client also keeps, beside each timer, the seconds one charge of a
-- charge ability takes: RecastCalc2, an int16 in the same 8-byte entry as the
-- timer id (Ashita SDK ffxi/player.h abilityrecast_t; IRecast GetAbilityCalc2;
-- PetsReborn reads it the same way for Ready). Kept in tm.recastCalc by timer
-- id while it counts; an answer that is not a plausible charge time leaves it
-- out, and Ready falls back to learning it (cmp/pets.lua).
tm.recastCalc = {}
local function calcOf(r, i)
    local ok, v = pcall(function() return r:GetAbilityCalc2(i) end)
    if ok and type(v) == 'number' and v >= 5 and v <= 300 then return v end
    return nil
end
local function recastLeft()
    local r, left = AshitaCore:GetMemoryManager():GetRecast(), {}
    tm.clear(tm.recastCalc)
    for i = 0, 31 do
        local id, ticks = r:GetAbilityTimerId(i), r:GetAbilityTimer(i)
        if (id ~= 0 or i == 0) and ticks > 0 then
            left[id] = ticks / 60
            if id == 102 then tm.recastCalc[id] = calcOf(r, i) end
        end
    end
    return left
end

-- How long each recast is, by timer id. The client says only what is left,
-- but this runs every frame, so the first value seen after a use is the whole
-- recast - merits and gear included - and the most seen since is kept until
-- the ability is ready again. After a reload mid-recast the first value seen
-- is part of one, so that recast's dial starts full.
local longest = {}

-- Whether you have learned it: the client's answer, or under /cmp demo the
-- made-up master's.
local function learned(d, p, ja)
    if d ~= nil then return d.has[ja.key] == true end
    if p:HasAbility(JA_RESOURCE + ja.ability) then return true end
    -- one row for two abilities on one timer (Sic and Ready, cmp/pets.lua):
    -- learned when either is
    return ja.alt ~= nil and p:HasAbility(JA_RESOURCE + ja.alt)
end

-- The client's recast table, read once: what is left on each timer and the
-- longest each has been seen at, by timer id. Under /cmp demo the made-up
-- master answers instead (cmp/demo.lua), whole lengths included: a demo opens
-- mid-recast, where first sight would start each dial full. `longest` is the
-- client's and is left be. Also answers the player, for learned().
local function readRecasts()
    local d = tm.demo and tm.demo.ja
    if d ~= nil then return d.left, d.total, nil, d end
    local left, p = recastLeft(), player()
    for timer in pairs(longest) do
        if left[timer] == nil then longest[timer] = nil end
    end
    for timer, rem in pairs(left) do
        if rem > (longest[timer] or 0) then longest[timer] = rem end
    end
    return left, longest, p, nil
end

-- The rows for `list` (entries shaped as tm.jaList's), keeping those `on`
-- accepts and you have learned, and leaving a ready one out under
-- cd_hide_ready. The other pet jobs' window (cmp/pets.lua) builds its rows
-- here too, from its own lists.
tm.jaBuild = function(list, on)
    local left, total, p, d = readRecasts()
    local rows = {}
    for _, ja in ipairs(list) do
        local rem = left[ja.timer]
        if on(ja) and learned(d, p, ja)
           and (rem ~= nil or not config.cd_hide_ready) then
            rows[#rows + 1] = { key = ja.key, label = ja.label, short = ja.short, name = ja.name,
                                state = (rem ~= nil) and 'counting' or 'ready',
                                remaining = rem, total = total[ja.timer] }
        end
    end
    return rows
end

local function switchedOn(ja) return config['cd_' .. ja.key] end

-- Render thread, at the model's pace from frame.tick, below its visibility
-- gates: this is display only, so it has no reason to run with the window
-- down. One safe() round the lot, so a failed read is an empty group and one
-- count in tm.swallowed.
tm.jaRefresh = function()
    tm.jaRows = safe(function() return tm.jaBuild(tm.jaList, switchedOn) end, {})
end

return {}
