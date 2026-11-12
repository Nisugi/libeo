# ebounty extraction: what moves into libeo

Decision (2026-11-11): the Adventurer's Guild task logic comes out of
ebounty into libeo, the one shared library. ebounty stays as the driver for
bigshot users; eohunter grows its own bounty module over the same library,
and group bounties are built there. The earlier "no ebounty in eohunter"
rule and libeo's header line "ebounty's Task stays in its script" are
both withdrawn by this decision.

Source read: `scripts/custom/ebounty.lic` 1.13.0 (3,900 lines). Lines
below refer to it.

## The boundary

A method moves to the library when it talks to the game about the task
and would read the same way under any hunter: the guild, the guard, the
NPC assignments, the town tables, the location resolution, the completion
rules, and the non-hunting task types (forage, heirloom search, escort,
gem and skin counting). A method stays with the driver when it starts or
shapes a hunt, decides when to rest, or owns the settings UI.

The library must not reach into `UserVars.op`, `EBounty.data`, or
`$bigshot_bandits`. Every such read below is listed so the extraction
replaces it with an argument or a policy object.

## Library: primitives (no policy, no settings)

| Method | Lines | What it does | Hidden inputs to remove |
|---|---|---|---|
| `bounty_change` | 385 | wait up to 3s for the bounty text to change | - |
| `get_command` / `get_res` | 629, 648 | issue a command, re-issue after roundtime | - |
| `open_container` | 673 | open a container only if closed, remember to close it | `data.close_containers` -> returned list |
| `wait_rt` | 921 | roundtime wait | - |
| `uid_match` | 906 | uid or room id -> room id | - |
| `change_stance` | 397 | stance with Stance Perfection | already in Lich `Stance`; call that instead |
| `mana_pulse` | 532 | mana pulse before a spell | already in Lich `Mana.pulse`; call that instead |
| `find_npc` | 2670 | find an NPC by name regex, 5 tries | exits the script on failure -> raise |
| `find_taskmaster` | 2629 | walk to the guild, pick Taskmaster / Halfwhistle / Seldit (Sailor's Grief sweep) | exits -> raise |
| `guard_list` | 2698 | advguard rooms for the task's town | `data.bounty_towns_uid` -> library table |
| `find_location` + `limit_crawl_area` | 2791, 2836 | location name -> start room and boundary list, capped at 100 rooms BFS | `data.bad_rooms` -> argument; writes `data.location_*` -> return value |
| `forage_find` / `find_herb_stow_list` | 3044, 3092 | herb rooms by tag and distance; herb name fixes | - |
| `check_boost` / `check_voucher` | 2423, 2439 | counts from BOOST INFO / BOUNTY | `settings[:use_*]` -> caller decides |

## Library: the guild and the task cycle (policy as arguments)

| Method | Lines | Hidden inputs to remove |
|---|---|---|
| `ask_taskmaster(get / turn-in / remove / expedite / failure)` | 2564 | `settings[:boost_type]`; exits on failure -> raise |
| `ask_assignment(furrier / herbalist / jeweler)` | 2517 | NPC name and room tables from `data` |
| `ask_guard` | 2718 | `data.containers` (heirloom in hand), `settings[:remove_heirloom]`, `settings[:keep_hunting]`, `go2_rest` + exit paths -> return a result the driver acts on |
| `check_removal` | 2455 | `settings[:*_exclude]`, `settings[:bounty_types]`, `data.crosswalk`, `data.reject_bounties`, `settings[:once_and_done]` -> one `TaskPolicy` object (accepted types, exclusions) |
| `bounty_get` / `bounty_remove` | 2905, 2911 | `settings[:use_vouchers]` |
| `fetch_bounty_details` | 2500 | - |
| `wait_until_next_bounty_available` | 3646 | - |
| `wait_for_bounty` | 3684 | mixes boost use with "go hunting" -> split: the boost part moves, the hunt stays |
| `check_exp` | 434 | time-to-rest estimate from fxp |
| `set_eval` (the completion rule) | 2133 | the whole thing is driver-shaped today: a Ruby string for bigshot's `bounty_eval` with `$bigshot_bandits`, `@CORRECT_PERCENT_MIND`, `UserVars.op['fried']`, `data.containers`, `data.remaining_*`. The library gets a `complete?` predicate per task type (succeeded text, bandit variant, child contact, skin and gem counts); each driver wraps it (bigshot as a string, eohunter as a lambda) |

## Library: task types that are not a hunt

| Method | Lines | Hidden inputs to remove |
|---|---|---|
| `forage_bounty` | 3103 | `settings[:forage_options]` (spells, hiding, gambit, run) -> `ForagePolicy`; `pre_hunt("forage")` / `post_hunt` / `prep` / `go2_rest` / `check_health` -> callbacks or driver hooks; `data.gambits_available` |
| `forage_turnin` / `forage_return` | 3282, 3329 | `data.herbalist_*`, `bounty_towns_uid`; `fog` and `go2_rest` -> hooks |
| `heirloom_search` | 3449 | `settings[:heirloom_options]`; `UserVars.op['hunting_room_id']` and `['hunting_boundaries']` -> the location from `find_location`; `loot_script` -> hook; `switch_profile` -> gone |
| `gem_bounty` / `skin_bounty` counting | 3390, 3585 | `data.containers`, `extra_skin`, eloot's sell types check -> `have_enough?(task)` returning the count; the "go hunting" branch stays with the driver |
| `escort` | 2989 | `settings[:escort_types]`, `escort_script`; portal flag toggling; `pre_hunt` / `post_hunt` hooks |
| `child_found` / the rescue half of `child_bounty` | 2923, 2940 | `rescue_script`; the garrote retry and Bard 1011 stop |
| `fog`, `fog_return_spirit`, `fog_return_voln` | 546-628 | `UserVars.op['fog_*']`, `['resting_room_id']`, `$rest_reason` -> a `FogPolicy`. Lich has `Fog` now (#1584); check whether this is a duplicate before moving it |
| `silver_check` / `silver_deposit` | 879, 884 | eloot's `EO::Silver` is the same thing; use it |

## Library: tables (from `Data`, lines 938-1240)

`crosswalk` (Lich task type -> ebounty bounty_type name), `taskmaster_responses`,
`guard_regex`, `furrier_names`, `herbalist_names`, `herbalist_rooms`,
`jeweler_names`, `forage_result`, `forage_injury`, `get_regex`, `put_regex`,
`bounty_towns_uid`, `resting_spots`, and `escort_pickup` / `escort_dropoff`
(inside `escort`). These are game facts and move as constants.

## Driver (stays in ebounty; eohunter's module gets its own)

| Method | Lines | Why |
|---|---|---|
| `bounty_check` dispatch | 2360 | the cycle: which handler per task type, `basic` and `once_and_done` exits |
| `should_hunt?` | 2044 | rest policy: mana, spirit, mind, cooldown, `exp_pause`, `keep_hunting`; reads `UserVars.op['rest_till_*']` |
| `go_hunting`, `keep_hunting`, `pre_hunt`, `post_hunt` | 2289, 2097, 2173, 2220 | starting bigshot, rewriting the profile, the single pass, prep and rest scripts |
| `switch_profile`, `load_default_profile`, profile letters | 775, 297 | bigshot profile model |
| `bandit_bounty`, `creature_culling`, `heirloom_bounty(loot)`, the hunt half of `child_bounty`, `gem_bounty` / `skin_bounty` hunt branches | 2857, 2982, 3437 | each is "pick profile, go hunting" |
| `bounty_complete`, `prep` | 2866, 3631 | rest-then-turn-in ordering, selling and banking hooks |
| `go2_rest`, `go2`, `regroup`, `check_health`, `over_watch`, death restart | 829, 812, 708, 451, 461 | rest spot choice reads five settings; death recovery restarts the driver |
| `Setup` (WebUI editor), settings load/save/CLI, `help`, `msg`, `test` | 223-381, 1436-2043 | UI and config |
| `set_variables`, `run_scripts`, `duration` / `elapsed` | 717, 745, 508 | driver bookkeeping |

## Settings that become library policy objects

- `TaskPolicy`: `bounty_types`, `creature_exclude`, `herb_exclude`,
  `gem_exclude`, `location_exclude`, `remove_heirloom`, `use_boosts`,
  `boost_type`, `use_vouchers`, `extra_skin`
- `ForagePolicy`: `forage_options`, `skip_healing`
- `HeirloomPolicy`: `heirloom_options`
- `EscortPolicy`: `escort_types`
- `FogPolicy`: `fog_return`, `fog_rift`, `fog_optional` (from the bigshot profile today)
- Hooks the driver supplies: `rest` (go2_rest), `heal`, `sell`, `pre_hunt(type)`,
  `post_hunt(type)`, `rescue_script`, `escort_script`, `loot_script`

ebounty keeps its settings file and UI unchanged and builds these objects
from it, so the extraction is invisible to a bigshot user.

## Order of work

1. Tables and primitives (no behaviour change, ebounty calls the library).
   **Built 2026-11-11**: `eo/guild/tables.rb`, `npcs.rb`, `location.rb`,
   `forage.rb`, plus `eo/command.rb`, `eo/containers.rb`, `EO.room_id`.
2. The guild and NPC dialogue with `TaskPolicy`; `check_removal`; errors
   raised instead of `exit_script`, caught by small wrappers in ebounty's
   `Task` module. **Built 2026-11-11**: `eo/guild/policy.rb`,
   `taskmaster.rb`, `assignments.rb`, `guards.rb`. One fix over ebounty:
   "Who are you trying to ask" now really asks again, where the old
   `ask_count.times` loop never grew.
3. `complete?` per task type; ebounty's `set_eval` wraps it. **Built
   2026-11-12**: `eo/guild/completion.rb`, `Completion::Rule` and the skin
   and gem counting; ebounty's bounty_eval is one call into the rule, and
   skin_bounty / gem_bounty count through the library.
4. Forage, heirloom search, escort, rescue-contact with their policies and hooks.
   **Built 2026-11-12**: `eo/guild/forage.rb` (Policy, gather, give),
   `heirloom.rb` (Policy, search, wander, the shared helper Spells),
   `escort.rb`, `rescue.rb`; ebounty's fog goes through Lich's `Fog.return`
   and its change_stance is gone (Lich's `Stance.change`). One fix over
   ebounty: the heirloom search stopped 213 by the forage options, not its own.
   ebounty 1.14.0 is 2,790 lines, from 3,900.
5. ebounty runs on the library for a few cycles with bigshot before any
   eohunter work starts.

## echild (built 2026-11-12)

echild 1.20.4 (519 lines, ~250 of logic) into the library the same way:

- `eo/guild/disablers.rb`: the spell table with town-safe and single-target
  flags, the can-cast check (wounds, debuffs), the justice check by hook,
  the choice (forced, cheapest, town-safe, multi-target, per-creature
  exclusions, the two sanctuaries preferred), TARGET RANDOM with the
  learned untargetable names, and the cast with the Song of Peace renew.
  Its `Policy` is built by the driver from CharSettings and Settings; the
  untargetable list is shared so what the walk learns is saved.
- `eo/guild/rescue.rb`: finding the child, the home table, the dropoff
  rooms (advguard, advguard2, Ta'Vaalor's), the destination, and `Walk`:
  step script per room, wait for the child, disable hostiles, the Maaghara
  root, the next dropoff when no one is there to report to, and the
  failed-task abort back to the first dropoff.
- echild 1.21.0 is 214 lines: settings and their commands, the test
  switch, the policy, one call.

Behaviour kept: the walk's conditions for casting (no players, no reportee,
not only the child), `$child_last_seen`, the seeking toggle. One change:
the failed-task watch sets a flag the walk checks between steps and then
walks back, where echild used to start go2 and kill itself at once.

## escortgo2 (built 2026-11-12)

escortgo2 1.0.5 (1,640 lines; ~900 of them the per-edge movement table) into
the library:

- `eo/guild/escort_routes.rb`: the 87 special edges as `[kind, argument]`
  rows: climbs, the careful moves (protect, check, haste), the Darkstone
  cave sneaks, the hidden-path searches, the Ta'Illistim ferry, the Zul
  Logoth mining carts, the crack, the multi-step stretches, the rope
  ladder, the misty trail, the two path loops. One helper per kind in
  `Walk#take_route`, behaviour as the original's procs.
- `eo/guild/escort.rb`: the pickup and dropoff tables, the travel-cost
  table, `trip_from` (the task text to a Trip), `Policy`, `Ambush` (the
  exec script's hook, now a DownstreamHook on the Walk), and `Walk`:
  client here or fetched (bank, pickup, WAIT, tell to follow), the map
  path with Ta'Vaalor's shortcut, seeking and portals off and restored
  after, the step with the route table, backtrack, the room check with
  target learning, poach and justice rules and the attack script or
  pause, hide, haste, the shield before a hiding-breaking move, eherbs
  when hurt, and the lost-client counter.
- escortgo2 1.1.0 is 179 lines: settings and their commands, the options,
  the policy, `$ego2_travel_cost` as an override of the library's table,
  one call. `$ego2_escort_id` is still set for scripts that read it.

Kept: every room-check and wait cadence of the original loop. Changed: the
walk ends `:delivered` when the task text drops the escort, `:lost` after
ten rooms without the client; the shortcuts and portal settings are
restored on exit, where the original left them off.

## eherbs (built 2026-11-12, not yet run)

eherbs 2.3.0 (3,597 lines) into `eo/herbs/`, a namespace of its own since
healing is not the guild's:

- `table.rb`: the 247-row herb table verbatim, the blood tiers, the
  drinkable and unbundleable name rules, the stock targets, and the
  lookups (what an item cures, what a location sells, by form).
- `injuries.rb`: the next herb type a wound wants (the general order and
  the spellcast / ranged orders), `status`, `hurt?` (ebounty's
  check_health uses the same rule), `can_cast?`, APPRAISE and LOOK
  readings for a dead player and an escort client.
- `doses.rb`: the dose monitor as a DownstreamHook object over the
  `$eherbs_measure` hash other scripts read. One fix: a bundle whose
  count was unknown was stored under a stale `$1`; it is stored under
  the bundle now.
- `sack.rb`: the sack as an object: find, open (remembering to close),
  contents by form for a carried sack, a kit, or a room container, store
  (raising Full), take, free hand, the kit's analyze, stock targets and
  distiller.
- `heal.rb`: `Heal.use` (the healing loop with the policy, a buy proc and
  a walk-back proc, returning healed / enough / must_take and the types it
  lacked), `deader`, `escort`, `cast_spells`.
- `shop.rb`: menu, prices, buy with a more-silver proc, bundle_all,
  bundle_hands (mismatch reported, not acted on), the shopping list
  against targets, cost, buy_list, put_away, missing_types.
- The bank is Lich's `Bank` (deposit, deposit_note, withdraw, note
  withdrawal, Pinefar, free-to-play); the silver count is `Currency`.
- eherbs 2.4.0 is 1,710 lines: the settings, the WebUI Setup, the
  listings (Msg) and the command line verbatim, over a thin Actions.

Not run in the game yet. The first live checks: `;eherbs` alone with a
wound, `;eherbs check`, `;eherbs stock` on a kit, `;eherbs fill` in a
potion town, and a bounty's forage run which heals through it.

## eloot, first slice (built 2026-11-12, not yet run)

eloot 2.15.0 (8,611 lines) is the script most tangled with its own state:
nearly every method reads `ELoot.data`, the room-scope leases, or the
saved lists. The first slice takes the primitives that are generic once
their outcome is handed back as a word instead of acted on in place:

- `eo/hands.rb` (`EO::Hands`): holding?, usable? and free? per hand,
  free_hand with a stow proc, take (held / missing / overloaded / failed),
  wear (worn / cant / stuck), store into a container (stored / full /
  not_yours / gone / unlootable / crumbled / failed, with an on_closed
  callback for bags that close themselves), the READY list's stow and ready.
- `eo/containers.rb` grew eloot's OPEN / LOOK / CLOSE answer sets,
  `listed?`, `ensure_open` (listed / nothing / unknown), `contents_ready?`,
  `fresh_contents` and `close`.
- `eo/town.rb` (`EO::Town`): fwi?, the Hinterwilds shop guard and
  `nearest_shop`, a shop in a named town, `in_region` with the region
  edges (ferry, carts, boot, transports, portmasters), `fwi_return`, the
  trash can, the locksmith pool's worker.
- `eo/items.rb` (`EO::Items`): marked?, toss (tossed / marked / kept),
  phase and unphase a box, decurse (clean / cast / gauntlet / no_mana /
  cannot), and `Items::Disk` (mine, watch with a change callback, wait,
  contents).
- The bank is Lich's `Bank`: deposit, deposit_note, note_value, withdraw,
  free-to-play and Pinefar; eloot's own f2p deposit and withdraw loops
  are gone.

eloot 2.16.0 keeps every method name as a thin wrapper that maps the
library's words onto its own lists (sacks_full, auto_close, crumbly,
unlootable, sell_containers) and its exits. 8,091 lines, from 8,611.
Not run in the game yet.

## eloot, second slice (built 2026-11-12, not yet run)

- `eo/locker.rb` (`EO::Locker`): the town-name aliases, the house's
  locker rooms in a town and the town LOCKER INFO names, nearest-first,
  the booth approach (go2 to the room outside, the last step taken here),
  `enter` returning entered / in_use / elsewhere / debt (with the silver
  owed) / no_way / unreachable / refused, `open` to the hoard container
  (or on the counter), `leave`.
- `eo/skinning.rb` (`EO::Skinning`): who wants a blunt tool, the
  candidates against the never-skinned and the driver's lists,
  `prepare` (kneel, Sigil of Resolve, 604), `skin` returning the names
  the game refused.
- `eo/appraisal.rb` (`EO::Appraisal`): `parse` (the value, not the
  lowball offer) and `ask`, answering amount, raw, too_valuable and
  wrong_shop.

eloot's Hoard keeps its names as wrappers; the debt at the locker door is
still paid by the driver (withdraw, pay, withdraw again, retry). 7,870
lines, from 8,611. Not run in the game yet.

Still eloot's own: the shop visits (furrier, gemshop, pawnshop, locksmith,
the pool), the loot decision (should_grab, custom lists), the hoarding
lists and the premium locker inventory.

## eloot, slices three to five (built 2026-11-12)

- Slice 3, `eo/loot.rb` and `eo/selling.rb`: the room's non-loot (reject
  names and nouns, disk nouns, categories) and `Loot::Policy` with
  `junk?` and `wanted?`; selling one item. eloot's tables point at these.
  Installed and running.
- Slice 4, `eo/locksmith.rb`: the town locksmith (the table's bell, keys
  or chime, the open with its fee: open / paid / refused / short /
  unknown, the pool-only "case" boxes) and the pool (box order, the
  incremental tip, the give: deposited / short / full / already_open, the
  list and its depth with the reget fallback, taking one box back).
  `EO.command` gained a timeout for the slow pool list.
- Slice 5, `eo/hoard.rb`: gem and reagent jars: the label name, the kind
  check against Lich's type data, reading a jar, the stash inventory by
  looking or parsed from a premium locker manifest, the inventory filter,
  putting into a jar (added / started / filled / full / unsuitable) and
  shaking one out.

eloot 2.16.0 after slice 5 is 7,531 lines, from 8,611. Slices 4 and 5 are
not yet run in the game. What is left in eloot is its own: settings and
setup, the room-scope leases, the sell routing between shops, which items
to hoard and the bounty-gem turn-in rules.

## ewaggle and ewander (built 2026-11-12)

- `eo/casting.rb` from ewaggle 2.2.0: the multicast count, casting at a
  target (:success / :refused_here / :bad_target), making mana
  (`Resources`: wracking, Sigil of Power, Symbol of Mana, stamina), the
  spells active on another character, manna bread. ewaggle 2.3.0 is
  1,565 lines.
- `eo/wander.rb` from ewander 2.0.1: a step from anywhere (the Elemental
  Confluence learned as it is walked), picking a creature to stop for,
  learning what TARGET accepts. ewander 2.1.0 is 320 lines, from 557.

## ecleanse (built 2026-11-12, not yet run)

`eo/cleanse/`, from ecleanse 2.4.0 (the WebUI setup branch merged first):

- `tables.rb`: the dispellable debuffs, hazard names, TARGET's answers,
  `Cleanse::Policy` (ecleanse's own setting names), the spell for a job,
  `able_to_cast?` on Lich's `Injured` with the Sigil of Determination cast
  when it lifts the block, `BadTargets`, and `Cleanse.command` (resent
  after "...wait" only; a Roundtime in the answer is part of it).
- `hazards.rb`: clouds, globes, webs, runestones: find, aim, clear
  (:breeze / :dispelled / :cleaved / :thieved / :untargetable /
  :unaffordable / :no_means), break a runestone.
- `afflictions.rb`: cure poison or disease, dispel debuffs, unground,
  the stun and web means in ecleanse's order and their use, settling a
  room before a recovery.
- `disarms.rb`: the saved list (UserVars.last_disarm), the RECOVER ITEM
  search (:recovered / :cannot_search / :nothing_here / :not_found, with
  the stash count), restoring hands oldest first, 213/1011, the servant,
  a bonded weapon, pry, the floated weapon, the Sanctum clench.
- `traps.rb`: hive trap search and disarm, the itchy curse's safe room
  and wait, the vat.

The line hook stays ecleanse's own at priority 100, so the hands are read
the moment a disarm happens, but it matches with Lich's
`Combat::Messages.scan` over the :disarm and :hazard families instead of
thirteen private patterns. ecleanse 2.5.0 is 1,139 lines, from 2,057.

Fixed on the way: the main loop's conditions were Hash keys, so two
afflictions true at once collapsed into one (poisoned and stunned: the
poison waited for the stun to end).

eohunter (branch feat/eohunter-libeo) loads libeo and takes from it
Cleanse's tables, `BadTargets`, the hazard finder (`Hazards.find` over a
loot list, so the engine's World still supplies the room), the disarm
list and the RECOVER ITEM reading (an earlier disarm found keeps the
search going; "nothing recoverable" stops it), and the trap texts. Its
actions keep the engine's shape: World, Results, interrupts, travel jobs.

## eocoordination (moved 2026-11-12)

eohunter's `libeocoordination` (0.1.0, seven files, about 2,000 lines) is
`eo/coordination/` here, loaded by `libeo.lic`, under `EO.require` in
place of its own `require_version`. Its specs are `spec/eo/coordination/`
and its Windows CI job came with it; its guide is
`docs/coordination-library.md`. eohunter stops shipping it, and its
installer's manifest removes the old copy on upgrade.

## Open points

- Namespace: `EO::Guild` or `EO::Tasks`; `EO::Bounty` would shadow Lich's
  `Bounty` inside the module.
- Upstream: ebounty is an elanthia-online script. Once it loads the
  library, the library ships there too, as one PR with both.
- `fog` and `silver_*` may already be covered by Lich's `Fog` and
  libeo's `EO::Silver`; verify before moving.
- `guard_list` carries two parser workarounds (Kraken's Fall sentry, Cold
  River tavernkeeper, line 2703) that belong in Lich's Bounty parser.
