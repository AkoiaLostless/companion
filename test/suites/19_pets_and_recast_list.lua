-- ------------------------------------------- the pet window and the list --
-- cmp/pets.lua and cmp/ui/petframe.lua: which pet is which, the window every
-- pet but the automaton gets, its timer, the packet thread's light path for
-- it; and the recasts as a PetsReborn-style list (config.cd_list).
do
    local tm     = require('cmp.state')
    local config = require('cmp.config')
    local PETS   = require('cmp.pets')
    local kindOf = PETS.kindOf
    local BST, SMN, DRG, PUP, WAR, WHM = 9, 15, 14, 18, 1, 3

    -- ------------------------------------------------------ which kind --
    check('kind: PUP main is always the automaton', kindOf('Carbuncle', PUP, SMN), 'automaton')
    check('kind: an avatar by name', kindOf('Carbuncle', SMN, WHM), 'avatar')
    check('kind: a spirit by name', kindOf('Fire Spirit', SMN, WHM), 'avatar')
    check('kind: a jug by name', kindOf('CourierCarrie', BST, WHM), 'jug')
    check('kind: a jug with spaces in the name', kindOf('Sheep Familiar', BST, WHM), 'jug')
    check('kind: DRG main brings a wyvern', kindOf('Bahamut', DRG, WAR), 'wyvern')
    check('kind: WAR/PUP brings an automaton', kindOf('Ferdinand', WAR, PUP), 'automaton')
    check('kind: BST/PUP, a mob it charmed', kindOf('Forest Hare', BST, PUP), 'charmed')
    check('kind: WAR/BST charms', kindOf('Forest Hare', WAR, BST), 'charmed')
    check('kind: nothing a job explains', kindOf('Mystery', WAR, WHM), 'pet')
    check('kind: jug durations from pet_list', PETS.JUGS.CourierCarrie, 1800)

    local function petAs(name, main, sub)
        world.mainjob, world.subjob, world.petName = main, sub, name
        world.petIndex, world.petId = 5, PET + 900
        world.mobIndex, world.mobId = 9, MOB + 900
        world.petHpp, world.petMpp = 80, 0
    end
    local function clearPet()
        world.petIndex, world.petId, world.petName = 0, 0, nil
        world.recast, world.abilities = {}, {}
        world.mainjob, world.subjob = 18, 0
        tm.petTarget = 0
        handlers['d3d_present']()
    end

    -- --------------------------------------------------- the window --
    config.cd_list = true
    api.resetSwallowed()
    PETS.resetTimer()
    world.abilities = { [0x200 + 85] = true, [0x200 + 78] = true, [0x200 + 72] = true }
    world.recast = { [1] = { 104, 60 * 200 } }    -- Call Beast, 200 s
    tm.petSummonAt = nil
    tm.noteSummon(85)                              -- you just used Call Beast
    petAs('CourierCarrie', BST, WHM)
    frame('pets: a jug out')
    check('pets: the view is the pet window', tm.view, 'pet')
    check('pets: the packet thread follows it', tm.snap.other, true)
    check('pets: ...and not as an automaton', tm.snap.is_pup, false)
    check('pets: the window is drawn', saw('WINDOW:companion'), true)
    check('pets: its name', saw('CourierCarrie'), true)
    check('pets: tagged as a jug', saw('jug'), true)
    check('pets: the jug clock starts full', saw('30:00'), true)
    check('pets: no MP bar for a jug with no MP', saw('MP'), false)
    check('pets: TP', saw('TP'), true)
    check('pets: Call Beast counting, as a list row', saw('3:20'), true)
    check('pets: ...named', saw('Call Beast'), true)
    check('pets: Reward ready', saw('Reward'), true)
    check('pets: ready reads Ready', saw('Ready'), true)
    check('pets: unlearned Charm is left out', saw('Charm'), false)
    check('pets: no maneuver table', saw('burden'), false)
    check('pets: no swallowed reads', api.swallowed(), 0)

    -- the timer survives a reload: same pet, no summon seen
    PETS.resetTimer()
    tm.petSummonAt = nil
    world.petId = PET + 901                        -- a zone gives it a new id
    frame('pets: the jug after a reload')
    check('pets: the saved clock is believed', saw('30:00') or saw('29:59'), true)

    -- Ready instead of Sic where the server grants it: listed with Ready
    -- alone learned, with its charges
    world.abilities[0x200 + 72] = nil
    world.abilities[0x200 + 251] = true
    world.recast = {}
    frame('pets: Ready, full')
    check('pets: Ready listed with only Ready learned', saw('Ready'), true)
    check('pets: three charges', saw('3/3'), true)
    world.recast = { [2] = { 102, 60 * 40 } }     -- one used: 40 s to refill (learns 40 s a charge)
    frame('pets: Ready, one used')
    check('pets: two charges left', saw('2/3'), true)
    check('pets: time to the next charge', saw('40s'), true)
    world.recast = { [2] = { 102, 60 * 100 } }    -- two more used: 100 s for all three back
    frame('pets: Ready, none left')
    check('pets: none left', saw('0/3'), true)
    check('pets: the next charge in 20s', saw('20s'), true)
    world.recast = { [1] = { 104, 60 * 200 } }
    world.abilities[0x200 + 72] = true

    -- the pet's target and its status, through the light path
    send028({ actor = world.petId, category = 1, param = 0,
              targets = { { id = MOB + 900, actions = { { message = 1, param = 30 } } } } })
    check('pets: what the pet hits is its target', tm.petTarget, MOB + 900)
    send028({ actor = MOB + 900, category = 11, param = 0,
              targets = { { id = world.petId, actions = { { message = 242, param = 4 } } } } })
    world.iconsAvailable = true
    frame('pets: paralyzed')
    check('pets: a status landing on it is in its strip', tm.petLive(4, os.clock()), true)
    world.iconsAvailable = nil

    -- an avatar: MP shown, the summoner's recasts
    clearPet()
    world.abilities = { [0x200 + 91] = true, [0x200 + 172] = true }
    petAs('Garuda', SMN, WHM)
    world.petMpp = 55
    frame('pets: an avatar')
    check('pets: avatar tagged', saw('avatar'), true)
    check('pets: avatar MP shown', saw('55%'), true)
    check('pets: BP: Rage listed', saw('BP: Rage'), true)
    check('pets: no jug clock', saw('30:00'), false)

    -- a wyvern
    clearPet()
    world.abilities = { [0x200 + 61] = true, [0x200 + 80] = true }
    petAs('Bahamut', DRG, WAR)
    frame('pets: a wyvern')
    check('pets: wyvern tagged', saw('wyvern'), true)
    check('pets: Spirit Link listed', saw('Spirit Link'), true)

    -- BST with nothing out keeps the window, for Call Beast
    clearPet()
    world.mainjob, world.subjob = BST, WHM
    world.abilities = { [0x200 + 85] = true }
    frame('pets: BST, no pet')
    check('pets: the window stays for a pet job', saw('no pet out'), true)
    check('pets: ...with Call Beast in it', saw('Call Beast'), true)

    -- ...but not for a job that only charms on the side
    world.mainjob, world.subjob = WAR, BST
    frame('pets: WAR/BST, no pet')
    check('pets: no window for /BST with nothing out', saw('WINDOW:companion'), false)

    -- switched off
    petAs('CourierCarrie', BST, WHM)
    config.pet_window = false
    frame('pets: switched off')
    check('pets: pet_window off draws nothing', saw('WINDOW:companion'), false)
    check('pets: ...and the packet thread stands down', tm.snap.other, false)
    config.pet_window = true

    -- an automaton on /PUP is the panel's, not this window's
    clearPet()
    petAs('Ferdinand', WAR, PUP)
    frame('pets: WAR/PUP automaton')
    check('pets: the automaton gets the panel', tm.view, 'pup')
    check('pets: the panel draws', saw('burden') or saw('no maneuvers'), true)

    -- the light path parses nothing with no pet out but your own abilities
    clearPet()
    world.mainjob, world.subjob = BST, WHM
    frame('pets: BST again')
    tm.petSummonAt = nil
    send028({ actor = MOB + 5, category = 6, param = 85, targets = { { id = MOB, actions = { { } } } } })
    check('pets: someone else\'s Call Beast is not yours', tm.petSummonAt, nil)
    send028({ actor = 0x01000001, category = 6, param = 85, targets = { { id = 0x01000001, actions = { { } } } } })
    check('pets: your own Call Beast stamps the summon', tm.petSummonAt ~= nil, true)
    check('pets: no swallowed reads at the end', api.swallowed(), 0)
    clearPet()

    world.mainjob, world.subjob = BST, WHM
    world.abilities = { [0x200 + 85] = true }
    config.cd_list = false
    frame('pets: cells instead')
    check('pets: with the list off, the cells say ready', saw('ready'), true)
    check('pets: ...and not the list\'s Ready', saw('Ready'), false)
    clearPet()

    -- ------------------------------------------------- the recast list --
    -- The automaton's recasts and yours as rows: the time right-aligned in
    -- its own column, then the name.
    petOut(PET + 950, MOB + 950)
    config.cd_list = true
    world.abilities = { [0x200 + 136] = true, [0x200 + 137] = true }   -- Activate, Repair
    world.recast = { [3] = { 206, 60 * 47 } }      -- Repair, 47 s
    api.selectTab('status')
    frame('list: status tab')
    check('list: your counting ability shows its time', saw('47s'), true)
    check('list: a ready one says Ready', saw('Ready'), true)
    check('list: the you label', saw('you'), true)
    check('list: no dial wedges', saw('WEDGE'), false)
    config.cd_list = false
    world.recast, world.abilities = {}, {}
    petIn()
end

-- ------------------------------------------ settings from Clockwork --
-- The first load after Clockwork brings its settings file and saved sets
-- across, once, and never over Companion's own.
do
    local tm = require('cmp.state')
    local old = SCRATCH .. '/config/addons/clockwork/'
    handlers['load']()   -- nothing to bring: no Clockwork folder
    os.execute(POSIX and ('mkdir -p "' .. old .. 'sets"') or ('mkdir "' .. (old .. 'sets'):gsub('/', '\\') .. '"'))
    local function put(path, text) local f = assert(io.open(path, 'w')) f:write(text) f:close() end
    local function read(path) local f = io.open(path, 'r') if f == nil then return nil end local t = f:read('*a') f:close() return t end
    put(old .. 'settings.txt', 'ui_scale = 130\n')
    put(old .. 'sets/tank.txt', 'head = Valoredge Head\n')
    check('migrate: companion already has settings, so nothing comes', tm.migrateFromClockwork(), false)
    os.remove(tm.settingsPath())
    printed = {}
    check('migrate: with none of its own, it brings them', tm.migrateFromClockwork(), true)
    check('migrate: the settings file came', read(tm.settingsPath()), 'ui_scale = 130\n')
    local setsDir = tm.settingsPath():gsub('settings%.txt$', 'sets/')
    check('migrate: the set came', read(setsDir .. 'tank.txt'), 'head = Valoredge Head\n')
    check('migrate: and says so', printed[1] ~= nil and printed[1]:find('1 saved sets', 1, true) ~= nil, true)
    check('migrate: only once', tm.migrateFromClockwork(), false)
    os.remove(tm.settingsPath())
    os.remove(setsDir .. 'tank.txt')
end

-- ------------------------------------------------------- /cmp pets --
do
    local config = require('cmp.config')
    handlers['command']({ command = '/cmp pets' })
    check('/cmp pets turns the pet window off', config.pet_window, false)
    handlers['command']({ command = '/cmp pets' })
    check('...and on again', config.pet_window, true)
end
