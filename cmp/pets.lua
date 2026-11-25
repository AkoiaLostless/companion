-- cmp/pets.lua - every pet that is not an automaton: a BST jug or charmed
-- pet, a SMN avatar or spirit, a DRG wyvern. Works out which kind of pet is
-- out (tm.petKind), and for the pet window (cmp/ui/petframe.lua) builds
-- tm.petView: the pet's vitals, its timer and your own recasts for its job.
-- Native reads, so render thread only, at the model's pace (cmp/frame.lua).
-- The packet thread only stamps tm.petSummonAt (cmp/inbound.lua).
--
-- The tables below are written for this addon from LandSandBoat's
-- sql/abilities.sql (abilityId and recastId) and sql/pet_list.sql (jug pet
-- names and durations), the same sources cmp/cooldowns.lua cites.
local config = require('cmp.config')
local tm = require('cmp.state')
local U  = require('cmp.util')
local safe, player = U.safe, U.player
local R  = require('cmp.reading')
local petInfo = R.petInfo
local ids = tm.ids

local JOB_BST, JOB_SMN, JOB_DRG, JOB_PUP = 9, 15, 14, 18

-- ------------------------------------------------------------- the data --
-- Your abilities for each kind of pet, in the order the window lists them,
-- shaped as tm.jaList's (cmp/cooldowns.lua): `ability` is LSB's abilityId,
-- `timer` its recastId. Only what you have learned is listed (HasAbility), so
-- a subjob, a level sync or an ability Horizon does not grant simply leaves a
-- row out. The pet commands with a few seconds' recast (Fight, Heel, Stay,
-- Leave, Assault, Retreat, Release) are left out: they are never waited on.
-- The two-hours share slot 0 of the recast table, whose timer id is 0.
-- Level-75 era as Horizon runs it: Bestial Loyalty (removed in Horizon's
-- 1.1 update), Snarl, Apogee, Elemental Siphon and Avatar's Favor are not on
-- Horizon and are not listed. Ready and Steady Wing are (Horizon's wiki).
local BEAST = {
    { key = 'call_beast',      label = 'Call Beast', short = 'Call', name = 'Call Beast',      ability = 85,  timer = 104 },
    { key = 'charm',           label = 'Charm',      short = 'Chm',  name = 'Charm',           ability = 52,  timer = 97 },
    { key = 'gauge',           label = 'Gauge',      short = 'Gau',  name = 'Gauge',           ability = 53,  timer = 98 },
    { key = 'tame',            label = 'Tame',       short = 'Tam',  name = 'Tame',            ability = 54,  timer = 99 },
    { key = 'reward',          label = 'Reward',     short = 'Rwd',  name = 'Reward',          ability = 78,  timer = 103 },
    -- Sic, and Ready where the server grants it instead: one timer, listed
    -- when you have either, and the label and charges follow which (sicRow)
    { key = 'sic',             label = 'Sic',        short = 'Sic',  name = 'Sic',             ability = 72,  timer = 102, alt = 251 },
    { key = 'feral_howl',      label = 'Feral Howl', short = 'FH',   name = 'Feral Howl',      ability = 161, timer = 105 },
    { key = 'killer_instinct', label = 'Killer Ins.', short = 'KI',  name = 'Killer Instinct', ability = 162, timer = 106 },
    { key = 'familiar',        label = 'Familiar',   short = 'Fam',  name = 'Familiar',        ability = 24,  timer = 0 },
}
local ABIL_READY = 251
-- Familiar (the two-hour) sets a charmed pet's time left to about half an
-- hour: 28-30 minutes, as seen on Horizon. Thirty is shown.
local ABIL_FAMILIAR, FAMILIAR_CHARM = 24, 1800
local AVATAR = {
    { key = 'bp_rage',         label = 'BP: Rage',   short = 'Rage', name = 'Blood Pact: Rage', ability = 91,  timer = 173 },
    { key = 'bp_ward',         label = 'BP: Ward',   short = 'Ward', name = 'Blood Pact: Ward', ability = 172, timer = 174 },
    { key = 'astral_flow',     label = 'Astral Flow', short = 'AF2', name = 'Astral Flow',      ability = 30,  timer = 0 },
}
local WYVERN = {
    { key = 'call_wyvern',     label = 'Call Wyvern', short = 'Call', name = 'Call Wyvern',    ability = 61,  timer = 163 },
    { key = 'spirit_link',     label = 'Spirit Link', short = 'SL',  name = 'Spirit Link',     ability = 80,  timer = 162 },
    { key = 'steady_wing',     label = 'Steady Wing', short = 'SW',  name = 'Steady Wing',     ability = 295, timer = 70 },
    { key = 'deep_breathing',  label = 'Deep Breath', short = 'DB',  name = 'Deep Breathing',  ability = 169, timer = 164 },
    { key = 'jump',            label = 'Jump',       short = 'Jmp',  name = 'Jump',            ability = 66,  timer = 158 },
    { key = 'high_jump',       label = 'High Jump',  short = 'HJ',   name = 'High Jump',       ability = 67,  timer = 159 },
    { key = 'super_jump',      label = 'Super Jump', short = 'SJ',   name = 'Super Jump',      ability = 68,  timer = 160 },
    { key = 'angon',           label = 'Angon',      short = 'Ang',  name = 'Angon',           ability = 170, timer = 165 },
    { key = 'spirit_surge',    label = 'Spirit Surge', short = 'SS', name = 'Spirit Surge',    ability = 29,  timer = 0 },
}
local LISTS = { jug = BEAST, charmed = BEAST, avatar = AVATAR, wyvern = WYVERN }

-- The abilities that bring a pet out, by abilityId: the packet thread stamps
-- tm.petSummonAt when you use one (cmp/inbound.lua), which is how a new pet is
-- told from one that was already out when the addon loaded.
local SUMMONS = { [85] = true, [387] = true, [52] = true, [61] = true }

-- The summoner's pets, by the name the client gives the entity.
local AVATARS = {}
for n in ('Carbuncle Fenrir Ifrit Titan Leviathan Garuda Shiva Ramuh Diabolos Alexander Odin '
       .. 'Atomos FireSpirit IceSpirit AirSpirit EarthSpirit ThunderSpirit WaterSpirit LightSpirit '
       .. 'DarkSpirit CaitSith Siren'):gmatch('%S+') do
    AVATARS[n] = true
end

-- Jug pets: how long each lasts, in minutes. The client names the entity as
-- the server does, with no spaces; names are compared with spaces removed
-- anyway.
local JUGS = {}
for n, mins in ([[
SheepFamiliar 60 HareFamiliar 90 CrabFamiliar 30 CourierCarrie 30 Homunculus 60
FlytrapFamiliar 60 TigerFamiliar 60 FlowerpotBill 60 EftFamiliar 60 LizardFamiliar 60
MayflyFamiliar 60 FunguarFamiliar 60 BeetleFamiliar 60 AntlionFamiliar 60 MiteFamiliar 60
LullabyMelodia 60 KeenearedSteffi 90 FlowerpotBen 60 SaberSiravarde 60 ColdbloodComo 60
ShellbusterOrob 60 VoraciousAudrey 60 AmbusherAllie 60 LifedrinkerLars 60 PanzerGalahad 60
ChopsueyChucky 60 AmigoSabotender 30 SlipperySilas 30 CraftyClyvonne 120 LuckyLulush 120
DiscreetLouise 120 DipperYuly 120 FlowerpotMerle 180 NurseryNazuna 120 DapperMac 120
TurbidToloi 120]]):gmatch('(%S+)%s+(%d+)') do
    JUGS[n] = tonumber(mins) * 60
end

-- Charm-time gear: item id -> CHARM_TIME points, each 5% more charm (LSB
-- item_mods.sql, mod 360). Anything else you wear adds nothing here.
local CHARM_GEAR = {
    [10658] = 6, [10678] = 8, [10698] = 5, [10718] = 3, [10738] = 4, [12517] = 4, [12646] = 5,
    [13969] = 3, [14097] = 2, [14222] = 6, [14481] = 6, [14508] = 7, [14898] = 3, [14917] = 4,
    [15080] = 5, [15095] = 6, [15110] = 4, [15125] = 2, [15140] = 3, [15233] = 4, [15253] = 5,
    [15360] = 2, [15569] = 6, [15588] = 2, [15673] = 3, [17936] = 1, [23048] = 30, [23071] = 12,
    [23138] = 14, [23205] = 11, [23272] = 9, [23339] = 10, [23383] = 35, [23674] = 12,
    [26640] = 8, [26641] = 10, [26816] = 8, [26817] = 12, [26992] = 7, [26993] = 9, [27168] = 5,
    [27169] = 7, [27344] = 6, [27345] = 8, [27671] = 5, [27692] = 5, [27815] = 7, [27836] = 7,
    [27951] = 4, [27972] = 5, [28098] = 7, [28119] = 7, [28231] = 3, [28252] = 3,
}

-- How long a charm lasts, in seconds: LSB's getCharmDuration
-- (scripts/globals/job_utils/beastmaster.lua). The base is 1.25 x CHR + 150;
-- a mob 7 or more levels above you cuts it to a 24th and one 9 or more below
-- multiplies it by 6, with LSB's fitted curve between; each CHARM_TIME point
-- on your gear adds 5%. An estimate of the server's number: anything the
-- server adds that this does not see (a food, a buff) moves it.
local function charmSeconds(chr, myLevel, mobLevel, charmTime)
    local base = math.floor(1.25 * chr + 150)
    local d = myLevel - mobLevel
    local mult = 1 / 24
    if d >= 9 then
        mult = 6
    elseif d >= -6 then
        mult = 0.9997336 + 0.3652882 * d + 0.02097742 * d ^ 2 - 0.004106429 * d ^ 3
             + 0.000007231037 * d ^ 4 + 0.00005102634 * d ^ 5
    end
    local dur = base * mult
    return math.floor(dur + dur * (charmTime * 0.5 / 10))
end

-- Your side of it, read now: CHR as the server counts it (base and gear),
-- your main job's level, and the charm-time points on what you wear.
local function charmNow(mobLevel)
    return safe(function()
        local p = player()
        local chr = p:GetStat(6) + p:GetStatModifier(6)
        local pts = 0
        for slot = 0, 15 do pts = pts + (CHARM_GEAR[U.equippedItemId(slot)] or 0) end
        return charmSeconds(chr, p:GetMainJobLevel(), mobLevel, pts)
    end, nil)
end

local function squash(name) return (tostring(name or ''):gsub('%s+', '')) end

-- ---------------------------------------------------------- which kind --
-- Which kind of pet `name` is, given your jobs. The automaton is decided by
-- job, as the rest of the addon decides it: on PUP main every pet is one, and
-- on /PUP it is one unless your main job brings its own pet, or the 0x044
-- names it. Avatars and jugs are known by name, a wyvern by DRG main, and
-- anything else a BST brings out is a charmed pet.
local function kindOf(name, main, sub)
    if main == JOB_PUP then return 'automaton' end
    local n = squash(name)
    if AVATARS[n] then return 'avatar' end
    if JUGS[n] then return 'jug' end
    if main == JOB_DRG then return 'wyvern' end
    if sub == JOB_PUP then
        local a = tm.auto044
        if (a ~= nil and a.name ~= nil and squash(a.name) == n)
           or (main ~= JOB_BST and main ~= JOB_SMN) then
            return 'automaton'
        end
    end
    if main == JOB_BST or sub == JOB_BST then return 'charmed' end
    return 'pet'
end

-- ------------------------------------------------------------ the timer --
-- A jug pet's time left, or how long a charmed pet has been yours. Kept in
-- one small file so a reload or a zone does not lose it - written only when
-- a new pet comes out, never in a frame otherwise.
local timer = nil   -- { name, kind, start = os.time() } for the pet out now, or nil
local saved = nil   -- the file's record, read once
local timerFor = nil   -- the pet id `timer` was settled for

local function timerPath()
    return ('%s/config/addons/companion/pet.txt'):format(tm.installRoot())
end
local function readSaved()
    if saved ~= nil then return saved end
    saved = false
    safe(function()
        local f = io.open(timerPath(), 'r')
        if f == nil then return end
        local line = f:read('*l') or ''
        f:close()
        local name, kind, start, dur = line:match('^([^|]+)|(%a+)|(%d+)|?(%d*)$')
        if name ~= nil then
            saved = { name = name, kind = kind, start = tonumber(start), dur = tonumber(dur) }
        end
    end)
    return saved
end
local function writeSaved(t)
    saved = t
    safe(function()
        ashita.fs.create_directory(timerPath():gsub('pet%.txt$', ''))
        U.writeFile(timerPath(), ('%s|%s|%d|%s\n'):format(t.name, t.kind, t.start,
                                                         t.dur and tostring(t.dur) or ''))
    end)
end

-- Settle the timer once for each pet that comes out. A pet you were seen
-- summoning in the last 15 s is new and starts now; otherwise the saved record
-- is believed if it is the same pet and still could be (a jug inside its
-- time), which is the reload and the zone. Anything else started before the
-- addon could see it, and has no timer rather than a wrong one.
local function settleTimer(kind, name)
    if ids.pet_id == timerFor then return end
    timerFor, timer = ids.pet_id, nil
    if kind ~= 'jug' and kind ~= 'charmed' then return end
    local now = os.time()
    local fresh = tm.petSummonAt ~= nil and os.clock() - tm.petSummonAt < 15
    local s = readSaved()
    if fresh then
        timer = { name = name, kind = kind, start = now }
        writeSaved(timer)
    elseif s and s.name == name and s.kind == kind
           and (kind ~= 'jug' or now - s.start < (JUGS[squash(name)] or 0) + 60) then
        timer = s
    end
end

-- What the header's clock says: a jug's time left, or a charmed pet's time
-- since the charm. nil when there is nothing to count.
local function timerView(kind, name)
    if timer == nil then return nil end
    local since = math.max(0, os.time() - timer.start)
    -- A charm's length, once the /check of that mob has answered (cmp/inbound.lua
    -- keeps every level a check reports, by the mob's id, which the pet keeps).
    if kind == 'charmed' and timer.dur == nil then
        local level = tm.checked[ids.pet_id]
        if level ~= nil then
            timer.dur = charmNow(level)
            if timer.dur ~= nil then writeSaved(timer) end
        end
    end
    -- Familiar used since this charm began: about thirty minutes from then.
    if kind == 'charmed' and tm.familiarAt ~= nil and tm.familiarAt ~= timer.familiarSeen then
        timer.familiarSeen = tm.familiarAt
        local at = os.time() - math.floor(math.max(0, os.clock() - tm.familiarAt))
        if at >= timer.start then
            timer.dur = (at - timer.start) + FAMILIAR_CHARM
            writeSaved(timer)
            since = math.max(0, os.time() - timer.start)
        end
    end
    if kind == 'charmed' and timer.dur ~= nil then
        return { left = math.max(0, timer.dur - since), total = timer.dur, charm = true }
    end
    if kind == 'jug' then
        local dur = JUGS[squash(name)]
        if dur == nil then return nil end
        return { left = math.max(0, dur - since), total = dur }
    end
    return { since = since }
end

-- --------------------------------------------------------------- the view --
-- Ready works on charges: three, each refilled over READY_CHARGE seconds,
-- and the client's recast timer counts down until all three are back
-- (LSB abilities_charges.sql: recastId 102, 3 charges, 30 s upstream). How
-- long one charge takes on this server, with your gear and merits, is learned
-- from the timer itself: a use from a full stock starts it at exactly one
-- charge. Until one is seen, Horizon's 45 s.
local READY_MAX, chargeSecs, sicWas = 3, 45, nil
local function sicRow(row, kind)
    if row.key ~= 'sic' then return end
    local hasReady = safe(function() return player():HasAbility(0x200 + ABIL_READY) end, false)
    if not hasReady then return end
    if kind ~= 'charmed' then row.label, row.short, row.name = 'Ready', 'Rdy', 'Ready' end
    local rem = row.remaining or 0
    -- the client's own per-charge figure when it gives one; else learned
    if tm.recastCalc[102] ~= nil then
        chargeSecs = tm.recastCalc[102]
    elseif sicWas == 0 and rem > 0 and rem <= 120 then
        chargeSecs = math.max(5, math.ceil(rem))
    end
    sicWas = rem
    local missing = math.min(READY_MAX, math.ceil(rem / chargeSecs - 0.01))
    row.charges, row.maxCharges = READY_MAX - math.max(0, missing), READY_MAX
    if rem > 0 then
        -- the time to the NEXT charge, which is the one you are waiting on
        row.remaining = rem - (missing - 1) * chargeSecs
        row.total = chargeSecs
        -- one in stock is usable now: ready, with the next on its way
        if row.charges > 0 then row.state = 'ready' end
    end
end
local function always() return true end

-- The pet jobs whose window stays up with no pet out, so the recast that
-- brings one back is in view: BST, SMN and DRG main.
local PET_MAIN = { [JOB_BST] = 'charmed', [JOB_SMN] = 'avatar', [JOB_DRG] = 'wyvern' }

-- The model's pass for the pet window. Sets tm.petKind ('automaton', 'jug',
-- 'charmed', 'avatar', 'wyvern', 'pet' or nil with no pet out) and returns
-- whether the pet window should draw; when it should, tm.petView holds what
-- it draws. An automaton answers false: the main panel is its window.
-- The /check a Charm asks for (cmp/outbound.lua noted the Charm). Sent from
-- here, the render thread, as a typed /check of your target: outbound.lua
-- points it at the charmed mob should your target be something else.
local function sendCharmCheck()
    local w = tm.charmWant
    if w == nil or w.state ~= 'want' then return end
    if os.clock() - w.at > 3 then tm.charmWant = nil return end
    w.state, w.at = 'sent', os.clock()
    safe(function() AshitaCore:GetChatManager():QueueCommand(1, '/check <t>') end)
end

tm.petRefresh = function()
    sendCharmCheck()
    local main, sub = safe(function() return player():GetMainJob() end, 0),
                      safe(function() return player():GetSubJob() end, 0)
    if tm.demo ~= nil then main = JOB_PUP end
    local pet = (ids.pet_id ~= 0) and petInfo() or nil
    if ids.pet_id == 0 then timerFor, timer = nil, nil end
    local kind = nil
    if pet ~= nil then kind = kindOf(pet.name, main, sub)
    elseif ids.pet_id ~= 0 then kind = tm.petKind   -- culled: still out, still the same kind
    end
    tm.petKind = kind
    if kind == 'automaton' then return false end
    if not config.pet_window then return false end
    local listKind = kind or PET_MAIN[main]
    if listKind == nil then return false end
    if pet ~= nil then settleTimer(kind, pet.name) end
    local rows = safe(function() return tm.jaBuild(LISTS[listKind] or {}, always) end, {})
    for _, r in ipairs(rows) do sicRow(r, listKind) end
    tm.petView = {
        kind  = kind,
        listKind = listKind,
        pet   = pet,
        timer = (pet ~= nil) and timerView(kind, pet.name) or nil,
        rows  = rows,
    }
    return true
end

-- The packet thread's half: one of your own abilities just went off.
tm.noteSummon = function(abilityId)
    if SUMMONS[abilityId] then tm.petSummonAt = os.clock() end
    if abilityId == ABIL_FAMILIAR then tm.familiarAt = os.clock() end
end

return { kindOf = kindOf, JUGS = JUGS, AVATARS = AVATARS, LISTS = LISTS,
         charmSeconds = charmSeconds, CHARM_GEAR = CHARM_GEAR,
         -- for the harness: forget the timer and the saved record
         resetTimer = function() timer, timerFor, saved = nil, nil, nil end }
