# Companion

> Companion is built from [Clockwork](https://github.com/patheed-ffxi/clockwork) by Pathead,
> which is **approved for use on HorizonXI**, by way of the
> [AkoiaLostless/clockwork](https://github.com/AkoiaLostless/clockwork) fork. It adds
> gear-aware stat reads, a lighter per-frame load, recasts laid out as a list, and a pet
> window for Beastmaster, Summoner and Dragoon. None of those changes has been reviewed by
> Horizon staff.

An [Ashita](https://www.ashitaxi.com/) 4.3 addon for [HorizonXI](https://horizonxi.com/):
one HUD for every pet.

- On **Puppetmaster** it shows you what your automaton is actually doing: burden and
  overload risk per element, which maneuvers are up, what weaponskill is coming next, what
  your attachments are worth right now. It can log every case where its own prediction
  did *not* match the server, so the model can be corrected from real play.
- On **Beastmaster, Summoner and Dragoon** it shows a pet window instead: the pet's HP,
  MP and TP, how far it is, what it is fighting, what is on it, a jug pet's time left, and
  your pet abilities' recasts.

![The Status tab](screenshots/status.png)

## Features

- **Burden and overload per element.** Burden is tracked for all eight elements
  separately, with the current overload chance, the chance your *next* maneuver would
  create, and how long an overload would last (the **OL s** column; **overload duration**
  on the Settings tab turns it off). The threshold is read off the gear you are
  actually wearing, so a Fire maneuver in Puppetry Dastanas resolves at a different number
  than a Water maneuver in Devotee's Mitts. An element with nothing up that cannot
  overload anything yet can be hidden from the table (**hide burden at 0% OL**, Settings
  tab).
- **Maneuver stat checks that follow your gear swaps.** Whether a maneuver costs 15 or
  20 burden depends on your stat as it goes off. The stat is read with the gear you have
  on at that moment, so a LuAshitacast or GearSwap maneuver set is counted with no menu
  opening and no setting. See *Gear swaps* below.
- **Maneuver slots and decay.** What is up, how long each has left, and the real decay
  rate — the Heatsink behaviour this model assumes for Horizon, not upstream's.
- **Weaponskill prediction.** What the automaton will use next, and why, with skillchain
  properties for automaton skills, player weaponskills and avatar skills.
- **Recasts as a list.** Live timers for the automaton's abilities and its ranged shot
  beside the maneuver table, and under it, headed `you`, your own job abilities' recasts,
  read straight from the client: Activate, Deus Ex Automata, Repair, Maneuver, Role
  Reversal, Ventriloquy, Overdrive and the rest. Each is a row the way PetsReborn lays its
  recasts out: the time first, right-aligned in its own column, then the name. **Ready**
  is green, a recast in its last 30% is amber, and one still counting is white. Each of
  your abilities has a switch (Retrieve and Deactivate start off), and **hide when ready**
  leaves a ready one out (Settings tab, **display**). Turning **as a list** off goes back
  to Clockwork's icon cells and dials; the compact strip always uses those, since it has
  no room for names.
- **Loadout tab.** Head, frame and every attachment with its live modifier values, plus
  capacity per element. Saved attachment sets with a preview and a confirmed apply,
  paced a second a step as pupsets is — from the tab's Apply button, or from a macro
  with `/cmp load <name>`.
- **What-if sidebar.** For each of the eight elements, what using that maneuver *right
  now* would change and what it would cost.
- **Anomaly log.** A JSONL record of every maneuver and automaton weaponskill, with
  mismatches between prediction and reality flagged. Off by default; turn it on from
  the Settings tab.
- **Pet window for other jobs.** See *Beastmaster, Summoner and Dragoon* below.
- **Demo mode.** `/cmp demo` walks four made-up automatons so you can see and size the HUD
  without being on PUP.

## Beastmaster, Summoner and Dragoon

When the pet out is not an automaton, Companion draws a smaller pet window where the
Puppetmaster panel goes:

- **The pet's name**, how many yalms away it is, and what kind of pet it is (`jug`,
  `charmed`, `avatar` or `wyvern`).
- **A jug pet's time left**, counting down from its jug's duration (30, 60, 90, 120 or
  180 minutes), amber in the last 5 minutes and red in the last minute. It starts when
  you use Call Beast or Bestial Loyalty, and it survives zoning and an addon reload. A
  jug pet that was already out when Companion loaded has no timer until the next one.
- **A charmed pet's charm time left**, an estimate shown as `~3:44`. The server never
  tells your client how long a charm lasts, so Companion works it out with the server's
  own formula (LandSandBoat's): your CHR, your level against the mob's, and the
  charm-time gear you are wearing. The mob's level comes from a /check: when you use
  Charm, Companion sends a `/check <t>` for you (pointed at the mob you charmed, if your
  target was something else), and a /check you make yourself counts too. The charm can
  still break sooner. With **charm check** off on the Settings tab, and no /check of
  that mob, the timer counts up from the charm instead.
- **HP and TP bars**, plus **MP** for avatars and for any pet that reports MP.
- **What is on the pet**: buffs on the left and debuffs on the right, the same strip the
  automaton gets.
- **What the pet is fighting**, and that mob's HP.
- **Your recasts for that job**, as the list above. Beastmaster: Call Beast, Bestial
  Loyalty, Charm, Reward, Sic (or Ready), Snarl, Feral Howl, Killer Instinct, Familiar.
  Summoner: Blood Pact: Rage and Ward, Apogee, Elemental Siphon, Avatar's Favor, Astral
  Flow. Dragoon: Call Wyvern, Spirit Link, Steady Wing, Deep Breathing, Jump, High Jump,
  Super Jump, Angon, Spirit Surge. Only abilities you have learned at your current level
  are listed.

With Beastmaster, Summoner or Dragoon as your main job the window stays up with no pet
out, so the recast that brings one back is in view. A pet you get from a subjob (Charm
on /BST, say) gets the window only while it is out. An automaton always gets the full
Puppetmaster panel, on PUP main or /PUP.

The pet window draws with the game's own status icons and Windows' Segoe UI, like the
rest of Companion: it needs no extra fonts or images. **pet window** on the Settings tab
(or `/cmp pets`) turns it off, for example if another addon draws your pets.

## Screenshots

| | |
|---|---|
| **Loadout** — head, frame and attachments, capacity per element, and the saved-set picker | **What-if sidebar** — what each maneuver would change if you used it now |
| ![The Loadout tab](screenshots/loadout.png) | ![The what-if sidebar](screenshots/what_if.png) |
| **Tuning → model** — automaton skill, the overload threshold, anomalies and spell windows | **Tuning → maneuver cost** — each element's stat check and what its 1st, 2nd and 3rd maneuver costs |
| ![The Tuning tab, model view](screenshots/tuning_model.png) | ![The Tuning tab, maneuver cost view](screenshots/tuning_maneuver_cost.png) |

**Compact** (`/cmp compact`) — the whole HUD on one line:

![The compact layout](screenshots/compact.png)

`/cmp compact 2`, or the strip's `2` button, puts it on two rows instead: the gems over
the recasts and the buttons, the bars over the weaponskill and spell. `/cmp compact 1`,
or the `1` button, goes back to one.

![The compact layout on two rows](screenshots/compact_two_rows.png)

## Install

1. On [github.com/AkoiaLostless/companion](https://github.com/AkoiaLostless/companion),
   press **Code → Download ZIP**, or clone this repo.
2. Put the `companion` folder into your Ashita `addons` directory, so that you have
   `addons/companion/companion.lua` with `cmp/` and `assets/` beside it.
3. In game: `/addon unload clockwork` if you run it, then `/addon load companion`.

Companion replaces Clockwork, so load one or the other, not both. To load it every time,
put `/addon load companion` in your Ashita script in place of `/addon load clockwork`.

The first time it loads, Companion copies your Clockwork settings and saved attachment
sets from `config/addons/clockwork/` into its own folder. Clockwork's folder is left as
it was.

## Commands

`/companion` and `/cmp` are the same command. Bare `/cmp` prints this list.

| Command | Does |
|---|---|
| `/cmp show` | the panel (or the pet window) on or off (the model and the log run either way) |
| `/cmp pets` | the pet window for Beastmaster, Summoner and Dragoon on or off |
| `/cmp compact` | the compact strip instead of the full panel; `/cmp compact 2` for two rows, `/cmp compact 1` for one |
| `/cmp demo` | made-up automatons, for looking at the HUD off PUP; each `/cmp demo` is the next one, then off again |
| `/cmp attachments` | the attachments you own |
| `/cmp equipped` | head, frame and attachments |
| `/cmp load <name>` | put a saved attachment set on the automaton, as the Loadout tab's Apply does — the same checks, the same apply, so the automaton has to be deactivated first. Works from a macro; a name with a space needs no quotes. Bare `/cmp load` lists your sets |
| `/cmp stat` | the stat you wear when each maneuver goes off, read off your gear — or set it: `/cmp stat wind 83`, `now` to take what you are wearing, `off` to go back to reading it. See *Gear swaps* below |
| `/cmp reset` | clear burden, learned costs and counters |
| `/cmp sync` | burden to zero — manual resync only |

## Settings and files

Companion writes these under your Ashita config directory:

- `config/addons/companion/settings.txt` — plain `key = value`, one per line, saved
  whenever you change a setting in game. A whitelist of display and reporting keys only;
  the model constants are deliberately *not* reachable from the UI, so an old settings
  file can never resurrect a value that has since been corrected.
  Unknown keys and wrong types are ignored. The one thing saved here that is not a
  display key is `stat_<Element>` — your own stat for that maneuver, from `/cmp stat`.
- `config/addons/companion/<Character>_YYYY.MM.DD.jsonl` — the log, one JSON object per
  line. Off by default: turn it on from the Settings tab.
- `config/addons/companion/sets/<name>.txt` — saved attachment sets, one item name per
  line: the same format the `pupsets` addon uses, so a file copied either way just works.
- `config/addons/companion/pet.txt` — the jug or charmed pet out now and when it came
  out, one line, so its timer survives a zone or a reload. Written only when a new pet
  comes out.

## Accuracy — please read

Companion re-implements a slice of the server's Puppetmaster logic on the client. It does
not read the server's mind.

Where this model departs from upstream LandSandBoat for HorizonXI — the Heatsink decay,
the burden an automaton arrives with, the weaponskill tie-break — the departure is a model
assumption, not a verified server rule. **Many of the other values were transcribed from
LandSandBoat and are unverified on HorizonXI**, including most attachment effects and several
ability recasts. Treat a number on the HUD as the model's answer rather than the
server's, and please report the ones that turn out wrong. Your own job abilities' recasts
are the exception: those are the client's own numbers.

### Gear swaps

A maneuver costs 15 burden when your stat meets or beats the automaton's and 20 when it
does not, compared as the maneuver goes off — so a gear-swap addon that puts a stat set on
for the maneuver changes the answer.

The client is only told your stats when it asks (opening the status or equipment menu) or
when something like a level or zoning makes the server send them, and *never* because you
swapped gear. What it *does* see straight away is what is in each equipment slot. So
Companion remembers the gear you had on the last time the server sent your stats, and
corrects the stat in memory by the difference:

    your stat now = stat in memory − that gear's stats + the stats of what you wear now

A LuAshitacast or GearSwap maneuver set is therefore counted with no menu opening and no
setting. The gear's stats are read from each item's description, plain lines only
(`STR+3`, `AGI-2`, `All attributes +1`): latent effects, set bonuses and automaton/pet
lines are conditional and are left out, and food, buffs and merits ride along inside the
number in memory. If you load Companion mid-session it assumes the gear on at load is what
your last stat refresh saw; open the equipment menu once if you loaded it in other gear.

If the read is still wrong for you — a set bonus or latent that matters — tell it what you
wear: `/cmp stat wind 83`. A typed number outranks the read, and is compared against the
automaton's live stat, so the check is still lost once that element is stacked. `/cmp stat
wind now` takes the corrected read, and `/cmp stat wind off` goes back to reading it.

## Reporting a wrong prediction

Report problems at
[github.com/AkoiaLostless/companion/issues](https://github.com/AkoiaLostless/companion/issues),
not to Clockwork's author: Companion has changed things the original does not have. For a
stat read wrong after a gear swap, note the item's name and its description text, which is
what the read is taken from. For anything else, include:

- the Companion version (`addon.version` at the top of `companion.lua`);
- your automaton's head, frame and attachments (`/cmp equipped`), and which maneuvers were up;
- what Companion predicted, and what the automaton or the server actually did;
- a short excerpt of the log around it. Turn on **write a log file** (or **anomalies to
  the file**) on the Settings tab first; the records where the prediction missed are
  tagged `burden_mismatch`, `ws_mispredicted`, `spell_mispredicted` or `recast_early`.

The log's filename carries your character's name, and its records name the mobs and the
abilities involved — check an excerpt before you post it.

## Requirements

- Ashita 4.3 or later — the HUD uses the ImGui font API that version brings
- Built for HorizonXI (era-locked, level cap 75). It will load anywhere Ashita
  runs, but the burden and overload constants are the model's Horizon assumptions.

## Future improvements

- Configure attachment sets directly from the Loadout tab.
- A more customizable Status tab.

## Credits

Companion stands on other people's work:

- **Clockwork** (Pathead, [patheed-ffxi/clockwork](https://github.com/patheed-ffxi/clockwork))
  — the Puppetmaster HUD Companion is built from. Everything on the Puppetmaster side but
  the gear-aware stat read, the lighter frame and the recast list is theirs.
- **PetsReborn** (Zaldas) — the idea of one pet window for every pet job, and the recast
  list's layout: the time, then the name, green when ready. Companion borrows those ideas
  only. None of PetsReborn's code, data, fonts or images is in Companion, which is why
  Companion can stay under the MIT License while PetsReborn is GPL-3.0.
- **[LandSandBoat](https://github.com/LandSandBoat/server)** — the burden, overload,
  weaponskill, spell and attachment logic is re-implemented from its
  `automatonentity.cpp`, `automaton_controller.cpp`, `automaton.lua` and SQL tables, and
  the pet window's ability recast ids and jug pet durations come from its
  `abilities.sql` and `pet_list.sql`.
  Where this model departs from it for Horizon, the departure is a model assumption.
- **chains** (Ivaar) — the skillchain properties of player weaponskills, automaton skills
  and avatar skills, which are era-tuned and differ from upstream on several skills.
- **fancychat** (Arielfy) — the action packet `0x028` bit layout is adapted from its
  `lib/combat_packets.lua`, itself adapted from the Azu-XI fork of atom0s' simplelog.
- **pupsets** (built on atom0s' Ashita v4 blusets) — the automaton attachment memory
  layout and the equip call are adapted from it, and the saved set file format is
  deliberately compatible.
- **mobdb** (ThornyFFXI) — the eight element gems in `assets/elements/` are its icon files,
  which are the game's own element art. See the README there.

## License

Companion's code is released under the [MIT License](LICENSE), as Clockwork's is. That license covers the
code in this repository, not Square Enix's artwork: the element gems in
`assets/elements/` are Final Fantasy XI's own art, redistributed as other Ashita addons
do, and remain Square Enix's property.

This is a fan-made tool for a fan-run server. Final Fantasy XI is the property of Square
Enix; no affiliation or endorsement is claimed.
