addon.name    = 'petworks'
addon.author  = 'Pathead (Clockwork), AkoiaLostless'
addon.version = '1.23.0'
addon.desc    = 'Puppetmaster burden, maneuvers, weaponskill prediction, loadout and anomaly logging.'

require('common')
local chat  = require('chat')

-- The modules, in dependency order: each requires only modules above it,
-- which keeps the graph acyclic. The shared state is pw/state.lua (`tm`). A
-- function a module publishes on tm is looked up at call time, which is how a
-- module calls one defined below it (tm.saveSettings, tm.sidebarInvalidate).
require('pw.config')
require('pw.data')
local tm     = require('pw.state')
local U      = require('pw.util')
local L      = require('pw.log')
require('pw.reading')
require('pw.gear')       -- publishes tm.statBasis
require('pw.cooldowns')  -- publishes tm.jaList and tm.jaRefresh
require('pw.attachments')
require('pw.burden')
require('pw.timers')
local P      = require('pw.pet')
require('pw.spell')      -- publishes tm.fn, tm.predictSpell and the rest
require('pw.settings')   -- publishes tm.loadSettings, tm.saveSettings, tm.restoreDefaults
local S      = require('pw.sets')
require('pw.demo')
local IN     = require('pw.inbound')
local C      = require('pw.commands')
local F      = require('pw.frame')
require('pw.ui.surface')
require('pw.ui.whatif')  -- publishes tm.whatIf, tm.sidebarRows and the rest
require('pw.ui.loadout')
local PN     = require('pw.ui.panel')

ashita.events.register('packet_in', 'petworks_packet', IN.onPacket)

-- tm.frameId numbers the frames, and tm.inFrame says one is being drawn:
-- reads that cannot change inside a frame are made once per frame id
-- (activeManeuvers in pw/burden.lua). Cleared even when the frame errors.
tm.frameId, tm.inFrame = 0, false
local function present()
    if F.tick() then PN.draw() end
end
ashita.events.register('d3d_present', 'petworks_present', function()
    tm.frameId, tm.inFrame = tm.frameId + 1, true
    local ok, err = pcall(present)
    tm.inFrame = false
    if not ok then error(err, 0) end
end)

-- A command can change what the model shows (a stat, a set, demo mode), so
-- the next frame re-runs it rather than waiting out its interval.
ashita.events.register('command', 'petworks_cmd', function(e)
    tm.modelDirty = true
    C.onCommand(e)
end)

ashita.events.register('load', 'petworks_load', function()
    P.resolveIds()
    -- BEFORE logOpen: `logging` and `anomaly_file` decide whether a file is
    -- opened at all, and the saved values are the ones that should decide it.
    tm.loadSettings()
    tm.fontLoad()
    L.logOpen()
    U.safe(function() ashita.fs.create_directory(S.setsDir()) end)
    -- Burden starts at zero and unverified, so the first maneuver of each
    -- element after a (re)load is a reseed, not an anomaly. Mark the edge in
    -- the log.
    L.logEvent('load', { version = addon.version, pet = (tm.ids.pet_id ~= 0) })
    print(chat.header('petworks'):append(chat.message(
        'loaded. /pw show - /pw attachments')))
end)

ashita.events.register('unload', 'petworks_unload', function()
    L.close()
end)
