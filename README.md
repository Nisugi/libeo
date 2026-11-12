# libeo

The shared library for the e-scripts on Lich 5 (ebounty, eloot, eherbs,
ecleanse, ewaggle, echild, escortgo2, ewander) and for eohunter. One loader,
`scripts/libeo.lic`, over a directory of small files, `scripts/eo/`, each
about one thing and readable on its own.

The repo also carries the e-scripts themselves, built on the library, in
`scripts/*.lic`. eohunter lives in its own repo and uses libeo's data and
rules.

```
;eohunter, ;ebounty ...         scripts that use it
Script.loadlib('libeo')         how a script loads it, once per session
EO.require('0.3.0')             the version the script was built against
```

## What is in it

| File | What it holds |
|---|---|
| `eo/version.rb` | `EO.require` and `EO.version`, the version gate |
| `eo/help.rb` | `EO.help`, the help table every e-script prints |
| `eo/messages.rb` | `EO.say` and `EO.word_wrap`: a message the way the e-scripts send one |
| `eo/settings.rb` | `EO::Settings`: whether the setup window can open, the settings table's lookups and defaults, the profile file, and `ListForm`: the ListSettingsForm window ebounty and eloot share (from the e-scripts' `Setup`) |
| `eo/travel.rb` | `EO.go2`, `EO.at?`, `EO.nearest`, `EO.visit`, `EO.room_id`, `EO.wander` (one step, least recently visited first), `EO.fog_wanted?` (bigshot's fog_return rule) |
| `eo/wander.rb` | `EO::Wander`: a step from anywhere (the Elemental Confluence learned as it is walked), picking a creature to stop for, learning what TARGET accepts (from ewander) |
| `eo/scripts.rb` | `EO.run_scripts`, `EO.split_script`: the scripts a setting lists, each run to its end |
| `eo/command.rb` | `EO.command`, `EO.result`, `EO.settle`: send a command and wait out roundtime; `EO.stand`: STAND a few tries at most |
| `eo/containers.rb` | `EO::Containers`: open a container only when it is closed, see one open, read contents the game does not refresh; a carried container is asked of Lich's `Inventory`, the rest by LOOK IN |
| `eo/hands.rb` | `EO::Hands`: free a hand, take an item, wear, put into a container, the READY list; every outcome comes back as a word (from eloot), over Lich's `Stash` for which hand holds what and opening the way to an item |
| `eo/stow.rb` | `EO::Stow`: where an item goes by the STOW list (its type's bag, the default, the overflow bags in order), which bags are full, the bags to open before looting, and what a put taught: a bag that closes itself, a crumbly or unlootable item (from eloot) |
| `eo/town.rb` | `EO::Town`: which shop to walk to and whether to go at all, a bounty town's region, Four Winds Isle, the trash can, the locksmith pool's worker (from eloot) |
| `eo/items.rb` | `EO::Items`: toss unless marked, phase and unphase a box, lift a curse, and the disk that follows the character (from eloot) |
| `eo/locker.rb` | `EO::Locker`: the character's locker rooms, getting into a booth (taken, elsewhere, a debt), opening it to a container, leaving (from eloot) |
| `eo/skinning.rb` | `EO::Skinning`: who needs a blunt tool, which dead to skin and with which tool, the tool drawn and put back, getting ready, the skinning and what it learned, standing up after (from eloot) |
| `eo/appraisal.rb` | `EO::Appraisal`: ask a shop what an item is worth and read the answer (from eloot) |
| `eo/loot.rb` | `EO::Loot`: the room's non-loot (features, spell effects, disks), and which loot a `Policy` wants (from eloot) |
| `eo/selling.rb` | `EO::Selling`: sell one item at a shop: sold, refused or kept (from eloot) |
| `eo/locksmith.rb` | `EO::Locksmith`: the town locksmith (activator, open, fee) and the locksmith pool (box order, incremental tips, the give, the list and depth, taking boxes back) (from eloot) |
| `eo/hoard.rb` | `EO::Hoard`: hoarding gems and reagents in jars: label names, the kind check, reading a jar, the stash inventory by looking or from a premium locker manifest, filling and shaking (from eloot) |
| `eo/casting.rb` | `EO::Casting`: the multicast count by lore, casting at a target (a hindered spell given up after three tries), waiting for mana or stamina and making it (Sign of Wracking, Sigil of Power, Symbol of Mana), another character's active spells, manna bread (from ewaggle) |
| `eo/brooch.rb` | `EO::Brooch`: the quintuple orb brooch: which orb ANALYZE says is ready, rubbing one (taken from a container and put back), the effects that last |
| `eo/chain.rb` | `EO::Chain`: chaining bounties: planar and order rubbed before a turn-in, a reducer after it to get under the field experience cap |
| `eo/cleanse/tables.rb` | `EO::Cleanse`: the dispellable debuffs, the hazards and TARGET's answers, the `Policy`, the spell this character has for a job, whether the wounds allow a cast (the Sigil of Determination cast when it helps) (from ecleanse) |
| `eo/cleanse/hazards.rb` | `EO::Cleanse::Hazards`: clouds, magic globes, webs and runestones in the room: find one, target it, dispel, cleave or thieve it (counted only when the game says it hit the wards), break a runestone |
| `eo/cleanse/afflictions.rb` | `EO::Cleanse::Afflictions`: poison and disease, magical debuffs, a root or press, a stun, a web or bind, each cured the first way the policy allows; settling a room before a recovery |
| `eo/cleanse/disarms.rb` | `EO::Cleanse::Disarms`: the disarms not yet recovered, kept across restarts; RECOVER ITEM searching, a bonded weapon's return, the spirit servant, prying a webbed weapon, a floated weapon, the Sanctum's clench |
| `eo/cleanse/traps.rb` | `EO::Cleanse::Traps`: hive traps searched out and disarmed, the itchy curse's safe room and wait, the Sanctum vat |
| `eo/coordination/` | `EO::Coordination`: opt-in coordination between independent Lich sessions: a bounded loopback transport, read-only observations, discovery, explicitly granted operations, a parser projection. Loading it starts nothing (from eohunter's libeocoordination) |
| `eo/guild/tables.rb` | towns, NPC names and rooms, response texts, the task-type crosswalk |
| `eo/guild/policy.rb` | `TaskPolicy`: which tasks a character takes, and why one is handed back |
| `eo/guild/npcs.rb` | find an NPC, the taskmaster (with the Sailor's Grief sweep), a town's guards |
| `eo/guild/location.rb` | a task's location to a start room and boundaries, capped to a connected region |
| `eo/guild/forage.rb` | herb rooms by tag and distance, herb name fixes, FORAGE SENSE's slots left, and the forage loop's steps one at a time |
| `eo/guild/taskmaster.rb` | get, turn in, remove and expedite a task; boosts, vouchers, the cooldown wait |
| `eo/guild/assignments.rb` | the furrier, herbalist and gem dealer visits that set a task |
| `eo/guild/guards.rb` | the guard visit that sets or completes a task, heirloom in hand |
| `eo/guild/completion.rb` | `Completion::Rule`: when a task is done enough to go to town; skin and gem counting |
| `eo/guild/heirloom.rb` | the heirloom search (wander, SEARCH, stow) and the helper spells foraging shares |
| `eo/guild/escort.rb` | the escort: the trip from the task, fetching the client, the road, the room checks and the ambush watch (from escortgo2) |
| `eo/guild/escort_routes.rb` | the escort roads' special edges: climbs, the Darkstone sneaks, the mining carts, the ferry |
| `eo/guild/disablers.rb` | choosing and casting a disabling spell on whatever is met on a walk (from echild) |
| `eo/guild/rescue.rb` | the child: finding it, its home, the walk to a guard (from echild); running a rescue script with the garrote and Bard retries |
| `eo/herbs/table.rb` | every herb: where it is sold, what it cures, its doses, and the lookups (from eherbs) |
| `eo/herbs/injuries.rb` | the next herb type a wound wants, another character's wounds from APPRAISE or LOOK |
| `eo/herbs/doses.rb` | the doses left in each item, learned from the game as herbs are used, bought and bundled |
| `eo/herbs/sack.rb` | the herb sack: finding, opening, contents by form, storing and taking, the Survivalist's Kit and its distiller |
| `eo/herbs/heal.rb` | healing yourself from the sack, a dead player by pouring, an escort client by handing over |
| `eo/herbs/shop.rb` | the herbalist: menu, prices, buying, bundling, the shopping list against dose targets |

`EO::Guild` is the Adventurer's Guild task logic that came out of ebounty,
echild and escortgo2. Each method's comment names the script method it was
taken from. [docs/ebounty-extraction-plan.md](docs/ebounty-extraction-plan.md)
is the plan that move followed, kept for its reasoning.

What lives here is script-side glue that Lich itself should not carry.
Anything that is a game rule or parser plumbing belongs in Lich and is called
directly; a script that needs it raises its required Lich version. libeo
leans on Lich's `Injured` (whether wounds allow a cast), `Spell#affordable?`
(mana, the spirit floor included), `Script.require_lich_version!`,
`Inventory`, `Stash`, `Combat::Messages`, `Fog.return`, `Stance`,
`Mana.pulse`, `issue_command` and the Bounty parser.

## Why it exists

Every e-script carried its own copy of the same things: the setup window,
`;<script> settings <name> <value>` parsing, version checks, messages, sending a command and waiting
out roundtime, the go2 wrapper. Each had drifted. They are now one copy here,
and the game knowledge each script owned (herbs, cleansing, casting, guild
tasks, looting, wandering) sits beside them so the next script can use it
instead of copying it. eohunter is the first: it takes the cleanse spell
lists and patterns, the disarm searches, the appendage nouns, the cast
patterns, the fog rule and `EO.command`.

What that buys:

- **A fix lands everywhere.** The hindered-cast cap in `EO::Casting` reaches
  every caster; the go2 wrapper behaves the same in every script.
- **Tests.** The library has rspec examples (no running Lich needed); the
  e-scripts had none. eohunter's specs run against libeo's tables.
- **Behaviour kept.** Every setup window was recorded before and after the
  move and came out identical, and the command-line settings editor was checked
  command by command. The intended changes: eloot settings take decimals, and
  two typos fixed.
- **Closer to Lich.** Where Lich already knows something, the scripts ask it,
  so a Lich improvement reaches them without a script change.

What it did not buy is shorter scripts. They keep their own logic, so they
shrank only a little (eloot 7,348 lines to 7,138, ebounty 2,627 to 2,373,
ewaggle 1,805 to 1,510). The gain is one tested copy of what they share.

### Left where it was

| Not moved | Why |
|---|---|
| The help tables | Each script's help text is its own. |
| Group aid and Troubadour's Rally (eohunter) | For ecleanse this would be a new feature (casting on other players, new settings), not shared code. Held for later. |
| Most of eohunter's actions | eohunter acts through its own testing layer (checked results, interruptible actions); libeo's helpers read Lich directly. Swapping them in would mean redesigning eohunter, so it takes the data, patterns and rules instead. |
| eohunter's background script starts | They run through eohunter's spec stand-ins, which `EO.run_scripts` doesn't fit. |
| Mana making through society modules | Not needed: `Spell#affordable?` already has the spirit floor. |
| Each script's own job | ebounty's bounty flow, eloot's sell loop, ewaggle's spell-up order: one script uses each. |
| eloot's looting routine | The corpse search, floor loot, routing each item to its STOW container, boxes, coins, and the container setup at startup. eohunter still launches eloot to loot and skin; calling these in-process would mean moving about 1,400 lines and redesigning how eohunter loots. libeo has the parts (`EO::Loot`, `EO::Skinning`, `EO::Hands`, `EO::Containers`) but not the routine. |
| BlackArts | Written the same way and full of the same helpers, but left out of this round. Porting it would also mean rebuilding its GTK setup window on the web forms. |

## Installing

libeo needs Lich 5.22.0 or later. It ships as a gem that carries the
library and an installer:

```
gem install libeo-<version>.gem
libeo install            # copies libeo.lic and eo/ into Lich's scripts/
libeo doctor             # what is installed and whether it is intact
libeo uninstall
```

Lich is found from `--lich-dir PATH`, else the `LICH_DIR` environment
variable, else the usual install places. From a checkout, `ruby exe/libeo install --lich-dir PATH` does the
same. The installer carries only the library; the e-scripts in `scripts/*.lic`
are copied into Lich's `scripts/custom/` by hand while they are being tested.

The installer records what it put there, so an upgrade removes files a newer
version dropped and an uninstall removes exactly what was installed.

## Developing

```
bundle install
bundle exec rspec        # the library's specs and the installer's
bundle exec rubocop
bundle exec rake gem     # builds dist/libeo-<version>.gem
```

The specs stand in for Lich's globals with small fakes (`spec/eo/eo_helper.rb`);
nothing needs a running Lich. A tag `v<version>` builds the gem and attaches it
to a GitHub release.
