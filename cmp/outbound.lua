-- cmp/outbound.lua - the one outgoing packet companion looks at, and the one
-- it touches: your Charm, and the /check it asks for so the charm countdown
-- knows the mob's level (cmp/pets.lua). Pure byte work, no native reads.
-- Exports onPacketOut.
local config = require('cmp.config')
local tm = require('cmp.state')

local function u16(d, o) local a, b = d:byte(o + 1, o + 2) return (a or 0) + (b or 0) * 0x100 end
local function u32(d, o)
    local a, b, c, e = d:byte(o + 1, o + 4)
    return (a or 0) + (b or 0) * 0x100 + (c or 0) * 0x10000 + (e or 0) * 0x1000000
end

local ACTION_OUT, CHECK_OUT = 0x01A, 0x0DD
local CAT_JA, ABIL_CHARM = 0x09, 52   -- 0x001A ActionID 9 is a job ability; Charm is abilityId 52

local function onPacketOut(e)
    if e.injected or not config.charm_check then return end
    local d = e.data
    if e.id == ACTION_OUT then
        if d == nil or #d < 0x0E then return end
        if u16(d, 0x0A) ~= CAT_JA or u16(d, 0x0C) ~= ABIL_CHARM then return end
        -- with a pet already out the Charm fails, so there is nothing to time
        if tm.snap.pet_id ~= 0 then return end
        tm.charmWant = { id = u32(d, 0x04), idx = u16(d, 0x08), at = os.clock(), state = 'want' }
        tm.modelDirty = true   -- the next frame sends the /check
    elseif e.id == CHECK_OUT then
        local w = tm.charmWant
        if w == nil or w.state ~= 'sent' or d == nil or #d < 0x0C then return end
        w.state = 'waiting'
        if u32(d, 0x04) == w.id then return end   -- your target was the mob: as typed
        -- Something else was targeted: the check goes to the charmed mob
        -- instead. 0x00DD: UniqueNo at 0x04, ActIndex (32 bits) at 0x08.
        local b = d:totable()
        for i = 0, 3 do b[5 + i] = math.floor(w.id / 0x100 ^ i) % 0x100 end
        b[9], b[10], b[11], b[12] = w.idx % 0x100, math.floor(w.idx / 0x100) % 0x100, 0, 0
        e.data_modified = b
    end
end

return { onPacketOut = onPacketOut }
