# libeo

The shared library for the e-scripts on Lich 5: ebounty, eloot, eherbs,
ecleanse and eohunter. One loader, `scripts/libeo.lic`, over a directory of
small files, `scripts/eo/`, each about one thing and readable on its own.

```
;eohunter, ;ebounty ...         scripts that use it
Script.loadlib('libeo')         how a script loads it, once per session
EO.require('0.2.0')             the version the script was built against
```

## What is in it

| File | What it holds |
|---|---|
| `eo/version.rb` | `EO.require` and `EO.version`, the version gate |
| `eo/help.rb` | `EO.help`, the help table every e-script prints |
| `eo/travel.rb` | `EO.go2`, `EO.at?`, `EO.nearest`, `EO.visit`, `EO.room_id`, `EO.wander` (one step, least recently visited first) |
| `eo/wander.rb` | `EO::Wander`: a step from anywhere (the Elemental Confluence learned as it is walked), picking a creature to stop for, learning what TARGET accepts (from ewander) |
| `eo/command.rb` | `EO.command`, `EO.result`, `EO.settle`: send a command and wait out roundtime |
| `eo/containers.rb` | `EO::Containers`: open a container only when it is closed, see one open, read contents the game does not refresh |
| `eo/hands.rb` | `EO::Hands`: free a hand, take an item, wear, put into a container, the READY list; every outcome comes back as a word (from eloot) |
| `eo/town.rb` | `EO::Town`: which shop to walk to and whether to go at all, a bounty town's region, Four Winds Isle, the trash can, the locksmith pool's worker (from eloot) |
| `eo/items.rb` | `EO::Items`: toss unless marked, phase and unphase a box, lift a curse, and the disk that follows the character (from eloot) |
| `eo/locker.rb` | `EO::Locker`: the character's locker rooms, getting into a booth (taken, elsewhere, a debt), opening it to a container, leaving (from eloot) |
| `eo/skinning.rb` | `EO::Skinning`: who needs a blunt tool, the candidates, getting ready, the skinning and what it learned (from eloot) |
| `eo/appraisal.rb` | `EO::Appraisal`: ask a shop what an item is worth and read the answer (from eloot) |
| `eo/loot.rb` | `EO::Loot`: the room's non-loot (features, spell effects, disks), and which loot a `Policy` wants (from eloot) |
| `eo/selling.rb` | `EO::Selling`: sell one item at a shop: sold, refused or kept (from eloot) |
| `eo/locksmith.rb` | `EO::Locksmith`: the town locksmith (activator, open, fee) and the locksmith pool (box order, incremental tips, the give, the list and depth, taking boxes back) (from eloot) |
| `eo/hoard.rb` | `EO::Hoard`: hoarding gems and reagents in jars: label names, the kind check, reading a jar, the stash inventory by looking or from a premium locker manifest, filling and shaking (from eloot) |
| `eo/casting.rb` | `EO::Casting`: the multicast count by lore, casting at a target, waiting for mana or stamina and making it (Sign of Wracking, Sigil of Power, Symbol of Mana), another character's active spells, manna bread (from ewaggle) |
| `eo/cleanse/tables.rb` | `EO::Cleanse`: the dispellable debuffs, the hazards and TARGET's answers, the `Policy`, the spell this character has for a job, whether the wounds allow a cast (the Sigil of Determination cast when it helps) (from ecleanse) |
| `eo/cleanse/hazards.rb` | `EO::Cleanse::Hazards`: clouds, magic globes, webs and runestones in the room: find one, target it, dispel, cleave or thieve it, break a runestone |
| `eo/cleanse/afflictions.rb` | `EO::Cleanse::Afflictions`: poison and disease, magical debuffs, a root or press, a stun, a web or bind, each cured the first way the policy allows; settling a room before a recovery |
| `eo/cleanse/disarms.rb` | `EO::Cleanse::Disarms`: the disarms not yet recovered, kept across restarts; RECOVER ITEM searching, a bonded weapon's return, the spirit servant, prying a webbed weapon, a floated weapon, the Sanctum's clench |
| `eo/cleanse/traps.rb` | `EO::Cleanse::Traps`: hive traps searched out and disarmed, the itchy curse's safe room and wait, the Sanctum vat |
| `eo/coordination/` | `EO::Coordination`: opt-in coordination between independent Lich sessions: a bounded loopback transport, read-only observations, discovery, explicitly granted operations, a parser projection. Loading it starts nothing (from eohunter's libeocoordination) |
| `eo/guild/tables.rb` | towns, NPC names and rooms, response texts, the task-type crosswalk |
| `eo/guild/policy.rb` | `TaskPolicy`: which tasks a character takes, and why one is handed back |
| `eo/guild/npcs.rb` | find an NPC, the taskmaster (with the Sailor's Grief sweep), a town's guards |
| `eo/guild/location.rb` | a task's location to a start room and boundaries, capped to a connected region |
| `eo/guild/forage.rb` | herb rooms by tag and distance, herb name fixes |
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
| `eo/herbs/injuries.rb` | the next herb type a wound wants, whether casting still works, another character's wounds from APPRAISE or LOOK |
| `eo/herbs/doses.rb` | the doses left in each item, learned from the game as herbs are used, bought and bundled |
| `eo/herbs/sack.rb` | the herb sack: finding, opening, contents by form, storing and taking, the Survivalist's Kit and its distiller |
| `eo/herbs/heal.rb` | healing yourself from the sack, a dead player by pouring, an escort client by handing over |
| `eo/herbs/shop.rb` | the herbalist: menu, prices, buying, bundling, the shopping list against dose targets |

`EO::Guild` is the Adventurer's Guild task logic that came out of ebounty.
Each method's comment names the ebounty line it was taken from. The plan for
what moves next is [docs/ebounty-extraction-plan.md](docs/ebounty-extraction-plan.md).

What lives here is script-side glue that Lich itself should not carry.
Anything that is a game rule or parser plumbing belongs in Lich (Stance,
Mana.pulse, issue_command, the Bounty parser) and is called directly; a
script that needs it raises its required Lich version.

## Installing

libeo needs Lich 5.22.0 or later. It ships as a gem that carries the
library and an installer:

```
gem install libeo-<version>.gem
libeo install            # copies libeo.lic and eo/ into Lich's scripts/
libeo doctor             # what is installed and whether it is intact
libeo uninstall
```

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
