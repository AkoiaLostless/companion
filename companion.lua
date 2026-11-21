addon.name    = 'companion'
addon.author  = 'Pathead (Clockwork), AkoiaLostless'
addon.version = '1.3.1'
addon.desc    = 'Puppetmaster burden, maneuvers, weaponskill prediction and loadout, and a pet window for BST, SMN and DRG.'

require('common')
local chat  = require('chat')

-- The modules, in dependency order: each requires only modules above it,
-- which keeps the graph acyclic. The shared state is cmp/state.lua (`tm`). A
-- function a module publishes on tm is looked up at call time, which is how a
-- module calls one defined below it (tm.saveSettings, tm.sidebarInvalidate).
require('cmp.config')
require('cmp.data')
local tm     = require('cmp.state')
local U      = require('cmp.util')
local L      = require('cmp.log')
require('cmp.reading')
require('cmp.gear')       -- publishes tm.statBasis
require('cmp.cooldowns')  -- publishes tm.jaList and tm.jaRefresh
require('cmp.attachments')
require('cmp.burden')
require('cmp.timers')
local P      = require('cmp.pet')
require('cmp.pets')       -- publishes tm.petRefresh and tm.noteSummon
require('cmp.spell')      -- publishes tm.fn, tm.predictSpell and the rest
require('cmp.settings')   -- publishes tm.loadSettings, tm.saveSettings, tm.restoreDefaults
local S      = require('cmp.sets')
require('cmp.demo')
local IN     = require('cmp.inbound')
local OUT    = require('cmp.outbound')
local C      = require('cmp.commands')
local F      = require('cmp.frame')
require('cmp.ui.surface')
require('cmp.ui.whatif')  -- publishes tm.whatIf, tm.sidebarRows and the rest
require('cmp.ui.loadout')
local PN     = require('cmp.ui.panel')
local PF     = require('cmp.ui.petframe')

ashita.events.register('packet_in', 'companion_packet', IN.onPacket)
ashita.events.register('packet_out', 'companion_packet_out', OUT.onPacketOut)

-- tm.frameId numbers the frames, and tm.inFrame says one is being drawn:
-- reads that cannot change inside a frame are made once per frame id
-- (activeManeuvers in cmp/burden.lua). Cleared even when the frame errors.
tm.frameId, tm.inFrame = 0, false
local function present()
    if F.tick() then
        if tm.view == 'pet' then PF.draw() else PN.draw() end
    end
end
ashita.events.register('d3d_present', 'companion_present', function()
    tm.frameId, tm.inFrame = tm.frameId + 1, true
    local ok, err = pcall(present)
    tm.inFrame = false
    if not ok then error(err, 0) end
end)

-- A command can change what the model shows (a stat, a set, demo mode), so
-- the next frame re-runs it rather than waiting out its interval.
ashita.events.register('command', 'companion_cmd', function(e)
    tm.modelDirty = true
    C.onCommand(e)
end)

ashita.events.register('load', 'companion_load', function()
    P.resolveIds()
    -- BEFORE logOpen: `logging` and `anomaly_file` decide whether a file is
    -- opened at all, and the saved values are the ones that should decide it.
    tm.migrateFromClockwork()   -- once, before the settings it may bring are read
    tm.loadSettings()
    tm.fontLoad()
    L.logOpen()
    U.safe(function() ashita.fs.create_directory(S.setsDir()) end)
    -- Burden starts at zero and unverified, so the first maneuver of each
    -- element after a (re)load is a reseed, not an anomaly. Mark the edge in
    -- the log.
    L.logEvent('load', { version = addon.version, pet = (tm.ids.pet_id ~= 0) })
    print(chat.header('companion'):append(chat.message(
        'loaded. /cmp show - /cmp attachments')))
end)

ashita.events.register('unload', 'companion_unload', function()
    L.close()
end)
