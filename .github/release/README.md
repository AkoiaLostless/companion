# petworks

> **Approved for use on HorizonXI.**

An Ashita addon for HorizonXI (requires Ashita 4.3 or later): a HUD for **Puppetmaster**. Burden and overload risk
per element, the maneuvers you have up, the automaton's next weaponskill and spell, its
recasts, and your loadout.

Documentation, screenshots and source: https://github.com/patheed-ffxi/petworks

## Install

Put this `petworks` folder in your Ashita `addons` directory, so that you have
`addons/petworks/petworks.lua` with `pw/` and `assets/` beside it. Then, in game:

    /addon load petworks

`/pw` lists the commands. Logging is off by default; the Settings tab turns it on.

Many of the values petworks uses were taken from LandSandBoat and have not been
verified on HorizonXI yet. To report a wrong prediction, see the "Reporting a wrong
prediction" section on the GitHub page.

## License

MIT - see `LICENSE`. The element icons in `assets/elements/` are Final Fantasy XI's own
art and are not covered by that license. Final Fantasy XI is the property of Square Enix;
this is a fan-made tool with no affiliation or endorsement.
