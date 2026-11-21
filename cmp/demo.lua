-- cmp/demo.lua - made-up automatons and other pets, so the HUD and the pet window
-- can be looked at without being on the job with a pet out and something to
-- fight. Owns tm.demo and the scenarios (four automatons, then a BST jug pet, a
-- BST charmed pet, a SMN avatar and a DRG wyvern); exports enable, disable, cycle (/cmp demo) and tick (once a frame,
-- from cmp/frame.lua).
--
-- What this is NOT: a second model. Everything the panel shows is still computed
-- by the real code from these inputs - burden decays, the ladder picks a spell,
-- the recast rows count down, the sidebar answers what-ifs. Only the handful of
-- reads that would otherwise touch the client's memory are answered from here,
-- which is the same seam the offline harness stubs. That is the point: if the
-- numbers look wrong in demo, the model is wrong, not the demo.
--
-- Runtime only, and never written to the settings file: a reload turns it off.
-- Demo state that survived a restart would be indistinguishable from a broken
-- addon, and every number on the panel would be a lie you had to remember.
local D  = require('cmp.data')
local tm = require('cmp.state')
local P  = require('cmp.pet')
local S  = require('cmp.sets')
local ELEMENTS, ATTACH_OFFSET, EQUIP_OFFSET = D.ELEMENTS, D.ATTACH_OFFSET, D.EQUIP_OFFSET

-- One per shape of automaton, because each lights a different part of the panel:
-- a melee frame has no Spell line at all, only a caster frame reaches the ladder,
-- and only Sharpshot has a shot whose recast the head and Drum Magazine change.
--
-- Attachments are named, not numbered. The harness's fixture ids and the client's
-- real ones disagree (Scanner is 210 there and 35 here), so these resolve through
-- the same name map the set store uses and a name the client does not know simply
-- leaves its slot empty.
--
-- All twelve slots are filled, and each set is inside its head+frame element
-- capacity: a half-empty automaton is not what the panel is ever looked at
-- against, and the Loadout tab's capacity bars only say anything on a real one.
-- Every attachment is one Horizon grants (ToAU era: nothing above tier II, no
-- ZNM drops), so each loadout is one a player there could actually build.
local SCENARIOS = {
    {
        name  = 'Valoredge, melee',
        head  = 'Valoredge Head', frame = 'Valoredge Frame',
        attach = { 'Strobe', 'Tension Spring II', 'Attuner', 'Inhibitor',
                   'Armor Plate II', 'Shock Absorber', 'Armor Plate', 'Schurzen',
                   'Heatsink', 'Tension Spring', 'Flashbulb', 'Optic Fiber' },
        pet = { name = 'Alpha', hpp = 84, mpp = 61, tp = 1240, dist = 3.2 },
        mob = { name = 'Steelshell Crab', hpp = 46, slot = 41 },
        maneuvers = { { element = 'Fire', remaining = 42 },
                      { element = 'Earth', remaining = 71 } },
        burden = { Fire = 22, Ice = 8, Wind = 0, Earth = 31,
                   Thunder = 14, Water = 5, Light = 0, Dark = 27 },
        -- `effects` and `used` have to agree: a buff on the strip came from an
        -- ability, so that ability's recast is running. Stoneskin (37) is Shock
        -- Absorber's, and enable() lands every effect 20 s ago, so 1946 is 20 s
        -- into its 180. No Refresh (43): it comes from Mana Converter alone
        -- (ABILITY_ICON 1948), a Dark attachment this Valoredge does not wear,
        -- so the strip would show a buff with no source and no recast behind it.
        used = { [1945] = 12, [1947] = 40, [1944] = 400, [1946] = 20 },
        effects = { 37 },
        skills = { melee = 231, ranged = 173, magic = 198 },
    },
    {
        name  = 'Sharpshot, ranged',
        head  = 'Sharpshot Head', frame = 'Sharpshot Frame',
        attach = { 'Drum Magazine', 'Turbo Charger', 'Accelerator', 'Scope',
                   'Stabilizer II', 'Target Marker', 'Tension Spring II', 'Attuner',
                   'Tension Spring', 'Inhibitor', 'Damage Gauge', 'Scanner' },
        pet = { name = 'Bravo', hpp = 97, mpp = 44, tp = 620, dist = 11.8 },
        mob = { name = 'Greater Colibri', hpp = 78, slot = 41 },
        maneuvers = { { element = 'Wind', remaining = 55 } },
        burden = { Fire = 0, Ice = 0, Wind = 18, Earth = 0,
                   Thunder = 9, Water = 0, Light = 0, Dark = 0 },
        -- the shot mid-recast, which is the row whose model the head and Drum
        -- Magazine both move: 20 s on a Sharpshot head, less the attachment
        used = { [1949] = 8 },
        effects = {},
        skills = { melee = 150, ranged = 231, magic = 120 },
    },
    {
        name  = 'Soulsoother, healer',
        head  = 'Soulsoother Head', frame = 'Stormwaker Frame',
        attach = { 'Mana Booster', 'Loudspeaker II', 'Tactical Processor', 'Ice Maker',
                   'Mana Converter', 'Economizer', 'Mana Tank', 'Eraser',
                   'Auto-Repair Kit II', 'Optic Fiber', 'Heatsink', 'Replicator' },
        pet = { name = 'Charlie', hpp = 62, mpp = 88, tp = 310, dist = 4.4 },
        mob = { name = 'Imp Ravager', hpp = 91, slot = 41 },
        maneuvers = { { element = 'Light', remaining = 63 },
                      { element = 'Water', remaining = 22 } },
        burden = { Fire = 0, Ice = 4, Wind = 0, Earth = 0,
                   Thunder = 0, Water = 26, Light = 33, Dark = 0 },
        used = { [1948] = 90, [2021] = 15, [2132] = 30 },
        effects = { 43 },
        skills = { melee = 120, ranged = 100, magic = 231 },
    },
    {
        name  = 'Spiritreaver, overloaded',
        head  = 'Spiritreaver Head', frame = 'Stormwaker Frame',
        attach = { 'Mana Booster', 'Loudspeaker', 'Tactical Processor', 'Tranquilizer',
                   'Mana Converter', 'Mana Conserver', 'Economizer', 'Mana Tank II',
                   'Mana Channeler', 'Heatsink', 'Condenser', 'Mana Tank' },
        pet = { name = 'Delta', hpp = 41, mpp = 12, tp = 0, dist = 6.1 },
        mob = { name = 'Aht Urhgan Wamoura', hpp = 12, slot = 41 },
        -- the state the model is loudest about: maneuvers dead, burden past the
        -- threshold on the elements that got it there
        maneuvers = {},
        overload = 14,
        burden = { Fire = 0, Ice = 44, Wind = 0, Earth = 0,
                   Thunder = 0, Water = 0, Light = 0, Dark = 51 },
        used = { [2068] = 20 },
        effects = {},
        skills = { melee = 110, ranged = 95, magic = 231 },
    },
}

-- The other pet jobs, drawn in the pet window (cmp/ui/petframe.lua) rather than
-- the automaton's panel. There is no model behind that window - it shows what
-- the client reports - so these are the reports themselves: the pet, its timer
-- and your recasts, each moving with the clock in tick(). `rows` are the job's
-- abilities from cmp/pets.lua's lists, by label, with how long each has left
-- (0 = ready) and its whole recast; Ready carries its charges.
local PET_SCENARIOS = {
    {
        name = 'Beastmaster, jug pet', kind = 'jug',
        pet  = { name = 'CourierCarrie', hpp = 88, tp = 300, dist = 2.4 },
        mob  = { name = 'Goblin Smithy', hpp = 71, slot = 41 },
        timer = { left = 1312, total = 1800 },
        rows = {
            { 'Call Beast', 0, 300 }, { 'Charm', 0, 15 },
            { 'Gauge', 0, 30 }, { 'Tame', 425, 600 }, { 'Reward', 52, 90 },
            { 'Ready', 18, 45, charges = 1 },
            { 'Feral Howl', 130, 300 }, { 'Killer Ins.', 0, 300 }, { 'Familiar', 0, 7200 },
        },
    },
    {
        name = 'Beastmaster, charmed pet', kind = 'charmed',
        pet  = { name = 'Forest Hare', hpp = 64, tp = 120, dist = 4.1 },
        mob  = { name = 'Tiger', hpp = 58, slot = 41 },
        timer = { left = 224, total = 402, charm = true },
        rows = {
            { 'Call Beast', 0, 300 }, { 'Charm', 9, 15 },
            { 'Gauge', 0, 30 }, { 'Tame', 0, 600 }, { 'Reward', 0, 90 },
            { 'Sic', 41, 120 },
            { 'Feral Howl', 0, 300 }, { 'Killer Ins.', 0, 300 }, { 'Familiar', 0, 7200 },
        },
    },
    {
        name = 'Summoner, avatar', kind = 'avatar',
        pet  = { name = 'Garuda', hpp = 93, mpp = 68, tp = 0, dist = 5.0 },
        mob  = { name = 'Greater Colibri', hpp = 82, slot = 41 },
        rows = {
            { 'BP: Rage', 34, 60 }, { 'BP: Ward', 0, 60 }, { 'Astral Flow', 0, 7200 },
        },
    },
    {
        name = 'Dragoon, wyvern', kind = 'wyvern',
        pet  = { name = 'Wyvern', hpp = 76, tp = 650, dist = 1.8 },
        mob  = { name = 'Ruszor', hpp = 63, slot = 41 },
        rows = {
            { 'Call Wyvern', 0, 1200 }, { 'Spirit Link', 47, 90 }, { 'Steady Wing', 0, 300 },
            { 'Deep Breath', 0, 300 }, { 'Jump', 21, 60 }, { 'High Jump', 0, 120 },
            { 'Super Jump', 88, 180 }, { 'Angon', 0, 180 }, { 'Spirit Surge', 0, 7200 },
        },
    },
}
for _, sc in ipairs(PET_SCENARIOS) do SCENARIOS[#SCENARIOS + 1] = sc end

-- The master's own job abilities, for the `you` group under the maneuver table
-- (cmp/cooldowns.lua): the same on every automaton, because they are yours, not
-- the frame's. Five are learned. Lengths are LSB's recastTime
-- (sql/abilities.sql), keyed by its recastId as the client's table is.
local JA_HAS = { activate = true, dea = true, repair = true, maneuver = true, overdrive = true }
-- Counting when a scenario opens: Activate 13:40 into its 20:00, Repair 52 s
-- into its 1:30. Each is used again `idle` seconds after it is ready, so the
-- dials keep moving however long demo stays on. Deus Ex and Overdrive stay
-- ready, and the maneuver recast is not here: it runs whenever one of the
-- scenario's maneuvers comes back up (tick), which is that maneuver being used.
local JA_RECASTS = {
    { timer = 205, total = 1200, left = 820, idle = 60 },   -- Activate
    { timer = 206, total = 90,   left = 52,  idle = 30 },   -- Repair
}
local MANEUVER_TIMER, MANEUVER_RECAST = 210, 10

-- The master's recasts t seconds in, as seconds left and whole lengths by
-- timer id; a ready ability is in neither, as in the client's table.
local function jaAt(d, t)
    local left, total = tm.clear(d.ja.left), tm.clear(d.ja.total)
    for _, j in ipairs(JA_RECASTS) do
        local into = (j.total - j.left + t) % (j.total + j.idle)
        if into < j.total then left[j.timer], total[j.timer] = j.total - into, j.total end
    end
    -- the maneuver most recently back up, by its own sawtooth
    local since = nil
    for _, m in ipairs(d.maneuvers) do
        local s = t % m.dur
        if since == nil or s < since then since = s end
    end
    if since ~= nil and since < MANEUVER_RECAST then
        left[MANEUVER_TIMER], total[MANEUVER_TIMER] = MANEUVER_RECAST - since, MANEUVER_RECAST
    end
end

-- Names by slot, the shape equippedNames answers with: 1 head, 2 frame, 3-14 the
-- twelve attachment slots.
local function slotNames(sc)
    local out = {}
    out[1], out[2] = sc.head, sc.frame
    for i = 1, 12 do out[i + 2] = sc.attach[i] or '' end
    return out
end

-- ...and the same thing as the ids the server's 0x044 would carry.
local function slotIds(sc)
    local map = S.itemIds()
    local head, frame = map.head[sc.head] or 0, map.frame[sc.frame] or 0
    local ids = {}
    for i = 1, 12 do ids[i] = map.attachment[sc.attach[i] or ''] or 0 end
    return head, frame, ids
end

-- One frame of a pet-window scenario: tm.petView as cmp/pets.lua would build
-- it, with every clock run down by the time since the scenario began. A
-- recast that reaches zero stays ready; the jug and charm timers count down.
local function petTick(d, t)
    local sc, v = d.scenario, d.view
    d.pet.tp = math.floor((sc.pet.tp + t * 45) % 1500)
    d.mob.hpp = 100 - math.floor(((100 - sc.mob.hpp) + t * 2.5) % 96)
    if sc.timer ~= nil then
        v.timer.left = math.max(0, sc.timer.left - t)
    end
    for i, r in ipairs(sc.rows) do
        local row = v.rows[i]
        local left = r[2] - t
        if r.charges ~= nil then
            -- a charge comes back every r[3] seconds, up to three; r[2] is
            -- how long the one on its way had left when the scenario began
            local progressed = (r[3] - r[2]) + t
            row.charges = math.min(3, r.charges + math.floor(progressed / r[3]))
            row.state = (row.charges > 0) and 'ready' or 'counting'
            row.remaining = (row.charges < 3) and (r[3] - progressed % r[3]) or nil
        else
            row.state = (left > 0) and 'counting' or 'ready'
            row.remaining = (left > 0) and left or nil
        end
    end
end

-- One frame of the made-up world. Everything here is an INPUT - what the client
-- would be reporting - so the real model runs on a moving picture rather than a
-- still one. Nothing in here computes burden, picks a spell or sets a recast:
-- those are the addon's own, and they move by themselves because they are read
-- against the clock.
--
-- Each value is a function of elapsed time alone, so it is cheap, needs no state
-- and cannot drift: a maneuver is a sawtooth over its own duration, which keeps
-- the COUNT steady while the seconds move (a maneuver dropping and returning
-- would make burden lurch for reasons the panel could not explain).
local function tick()
    local d = tm.demo
    if d == nil then return end
    local t = os.clock() - d.at
    if d.view ~= nil then petTick(d, t) return end
    for _, m in ipairs(d.maneuvers) do
        m.remaining = math.ceil(m.dur - (t % m.dur))
    end
    if d.overloadFor ~= nil then
        -- counts down, stays off a while, comes back: both states are worth
        -- seeing and the overloaded scenario is the one that shows them
        local period = d.overloadFor + 20
        local left = d.overloadFor - (t % period)
        d.overload = (left > 0) and math.ceil(left) or nil
    end
    -- TP climbs and rolls over, so the gold bar crosses its 1000 threshold
    d.pet.tp = math.floor((t * 45) % 1500)
    -- ...and the target loses health, then is replaced by another one
    d.mob.hpp = 100 - math.floor((t * 2.5) % 96)
    jaAt(d, t)
end

local function enablePet(i, sc)
    local rows = {}
    for j, r in ipairs(sc.rows) do
        rows[j] = { key = r[1], label = r[1], short = r[1], name = r[1], total = r[3],
                    charges = r.charges, maxCharges = r.charges and 3 or nil }
    end
    local d = {
        which = i, name = sc.name, at = os.clock(), scenario = sc,
        pet = { name = sc.pet.name, hpp = sc.pet.hpp, mpp = sc.pet.mpp,
                tp = sc.pet.tp, dist = sc.pet.dist },
        mob = { name = sc.mob.name, hpp = sc.mob.hpp, slot = sc.mob.slot },
        maneuvers = {}, ja = { has = {}, left = {}, total = {} },
        names = {}, oils = {},
    }
    d.view = {
        kind = sc.kind, listKind = sc.kind, pet = d.pet, rows = rows,
        timer = sc.timer and { left = sc.timer.left, total = sc.timer.total,
                               charm = sc.timer.charm } or nil,
    }
    tm.demo = d
    -- no automaton: nothing for the panel's model or the Loadout tab to show
    tm.auto044 = nil
    tm.auto044Seq = tm.auto044Seq + 1
    tm.ids.pet_id, tm.ids.pet_index, tm.ids.self_id = 0x01000200, 40, 0x01000100
    tm.petTarget = 0x01000300
    tm.mobName = sc.mob.name
    tm.clear(P.petEffects)
    tm.clear(tm.usedAt)
    for _, el in ipairs(ELEMENTS) do
        tm.burden[el] = 0
        tm.burdenVerified[el] = false
    end
    petTick(d, 0)
    return sc.name
end

local function enable(i)
    local sc = SCENARIOS[i]
    if sc == nil then return nil end
    if sc.kind ~= nil then return enablePet(i, sc) end
    local head, frame, ids = slotIds(sc)
    -- copies, not the scenario's own tables: tick() writes into these every
    -- frame and the scenario has to still be itself when it comes round again
    local mans = {}
    for j, m in ipairs(sc.maneuvers) do
        mans[j] = { element = m.element, remaining = m.remaining, dur = m.remaining }
    end
    tm.demo = {
        which = i, name = sc.name, at = os.clock(),
        pet = { name = sc.pet.name, hpp = sc.pet.hpp, mpp = sc.pet.mpp,
                tp = sc.pet.tp, dist = sc.pet.dist },
        mob = { name = sc.mob.name, hpp = sc.mob.hpp, slot = sc.mob.slot },
        maneuvers = mans, overload = sc.overload, overloadFor = sc.overload,
        oils = { ['Automaton Oil'] = 3, ['Automaton Oil +1'] = 1,
                 ['Automaton Oil +2'] = 12, ['Automaton Oil +3'] = 0 },
        names = slotNames(sc),
        ja = { has = JA_HAS, left = {}, total = {} },
    }
    -- The server's own view of the automaton, which is what the Loadout tab, the
    -- spell ladder and the frame/head readers all work from. Shaped as
    -- parseJobExtra builds it, minus the fields nothing on the panel reads.
    tm.auto044 = {
        head = head, frame = frame, attachments = ids,
        hp = 1284, maxhp = 1530, mp = 372, maxmp = 610,
        melee = sc.skills.melee, meleeCap = 231,
        ranged = sc.skills.ranged, rangedCap = 231,
        magic = sc.skills.magic, magicCap = 231,
        owned = string.rep(string.char(0xFF), 32),
        heads = 0xFFFFFFFF, frames = 0xFFFFFFFF,
        STR = 61, DEX = 55, VIT = 58, AGI = 49, INT = 44, MND = 47, CHR = 43,
        base = { STR = 61, DEX = 55, VIT = 58, AGI = 49, INT = 44, MND = 47, CHR = 43 },
    }
    tm.auto044Seq = tm.auto044Seq + 1
    tm.statsDirty = true
    -- tm.lastPetId is left alone: it belongs to resolveIds(), which frame.tick
    -- skips while demo is on. Set to this fake id, it would make the next
    -- real read fire a lifecycle edge against it.
    tm.ids.pet_id, tm.ids.pet_index, tm.ids.self_id = 0x01000200, 40, 0x01000100
    tm.petTarget = 0x01000300
    tm.mobName = sc.mob.name

    for _, el in ipairs(ELEMENTS) do
        tm.burden[el] = sc.burden[el] or 0
        tm.burdenVerified[el] = true
        tm.lastReconcile[el] = os.clock()
    end
    local now = os.clock()
    tm.clear(tm.usedAt)
    for id, ago in pairs(sc.used) do tm.usedAt[id] = now - ago end
    tm.edgeAt = tm.edgeAt or now
    tm.clear(P.petEffects)
    for _, ef in ipairs(sc.effects) do
        P.petEffects[ef] = now - 20
        tm.petKnown[ef] = true
    end
    return sc.name
end

local function disable()
    tm.demo = nil
    tm.auto044 = nil
    -- equippedSet() caches per auto044Seq, and enable() bumps it to publish
    -- the scenario's loadout. Bump it again here or the Loadout tab keeps the
    -- made-up set as 'current' until the next real 0x044, and Save current
    -- writes it to disk.
    tm.auto044Seq = tm.auto044Seq + 1
    tm.ids.pet_id, tm.ids.pet_index = 0, 0
    tm.petTarget = 0
    tm.clear(P.petEffects)
    tm.clear(tm.usedAt)
    for _, el in ipairs(ELEMENTS) do
        tm.burden[el] = 0
        tm.burdenVerified[el] = false
    end
end

-- /cmp demo walks the list and then turns itself off, so the command is one key
-- rather than one per automaton and there is always a way back out of it.
local function cycle()
    local at = tm.demo and tm.demo.which or 0
    if at >= #SCENARIOS then disable() return nil, #SCENARIOS end
    return enable(at + 1), #SCENARIOS
end

return { enable = enable, disable = disable, cycle = cycle, tick = tick }
