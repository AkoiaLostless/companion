# Companion

An Ashita addon for HorizonXI (requires Ashita 4.3 or later): one HUD for every pet.
On **Puppetmaster**, burden and overload risk per element (with your stat read when you
use each maneuver, so a gear-swap maneuver set counts), the maneuvers you have up, the
automaton's next weaponskill and spell, your cooldowns, what your maneuvers add, and your
loadout. On
**Beastmaster, Summoner and Dragoon**, a pet window: HP, MP and TP, the pet's target and
status, a jug pet's time left, and your pet abilities' recasts.

Built from Clockwork by Pathead, which is approved for use on HorizonXI. Companion's own
changes have not been reviewed by Horizon staff.

Documentation and source: https://github.com/AkoiaLostless/companion

## Install

Put this `companion` folder in your Ashita `addons` directory, so that you have
`addons/companion/companion.lua` with `cmp/` and `assets/` beside it. Companion replaces
Clockwork, so unload that first. Then, in game:

    /addon load companion

`/cmp` lists the commands. The first load copies your Clockwork settings and saved sets
across. Logging is off by default; the Settings tab turns it on.

Many of the values Companion uses were taken from LandSandBoat and have not been
verified on HorizonXI yet. To report a wrong prediction, see the "Reporting a wrong
prediction" section on the GitHub page.

## License

MIT - see `LICENSE`. The element icons in `assets/elements/` are Final Fantasy XI's own
art and are not covered by that license. Final Fantasy XI is the property of Square Enix;
this is a fan-made tool with no affiliation or endorsement.
