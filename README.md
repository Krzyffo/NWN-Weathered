# NWN-Weathered

Dust, snow and blood on characters, monsters, placeables and doors in Neverwinter Nights: Enhanced Edition, one at a time.

- **Dust** builds up from the ground: boots first, then the legs, past the waist when heavy. In a dust storm it settles over the whole body. It comes in patches and never covers everything: at full dust about 80% of the surface near the ground, thinning to about 60% where it reaches highest. Like blood, the patches are placed on the model in 3D rather than by its (mostly mirrored) texture, and the left and right halves of the body get different patterns.
- **Snow** settles in matte clumps where surfaces face up (shoulders, hoods, the tops of boots).
- **Blood** from fighting: blows leave a creature's own blood on it, and melee attackers get their victims' blood on their hands, arms and front, in each victim's colour. Blood dries darker over a few minutes.
- **Gradual:** dust and snow come and go step by step, blood builds up hit by hit, and a noise texture breaks everything into natural patches.
- **Cloaks** take dust, snow and blood like the rest of the creature: the hem gets dusty with the shins. Helmets, robes and weapons can't (see [Limits](#limits)).
- **Per creature, in multiplayer:** the look belongs to the creature, so every player sees the same dusty traveller.
- **Designer-controlled:** nothing is detected from tilesets. You decide where dust and snow build up, what the weather does, and how the area's own creatures start out.

Status: dust, snow and blood all work in game, including movement.

## Who changes over time

- **Players** and their henchmen, animal companions, familiars and summons build up dust and snow where it applies, and lose it slowly where it doesn't.
- **Monsters and NPCs** get a starting look when a player first comes near and keep it. To let one weather like a player, give it `WTHR_WEATHERS = 1`.

## Setup in a module

1. Run `py tools/build.py` (see [Building](#building)). It writes `nwn_weathered.hak` and `nwn_weathered.erf` into `tools/`.
2. Copy `nwn_weathered.hak` into your NWN `hak` folder. In the toolset: Module Properties > Custom Content > add `nwn_weathered`.
3. File > Import > `nwn_weathered.erf`. This brings in the scripts and the **Clothes Brush** item blueprint (`wthr_brush`).
4. Module Properties > Events > **OnModuleLoad**: `wthr_modload`. If the module already has a script there, add `ExecuteScript("wthr_modload", OBJECT_SELF);` to it. When the module loads, `wthr_modload` puts our scripts on these events and keeps the module's own scripts running first:

   | Event | Script | Does |
   |---|---|---|
   | OnClientEnter | `wthr_enter` | Starts each player's weathering |
   | OnPlayerChat | `wthr_chat` | `/dirt`, `/brush` and the test commands |
   | OnActivateItem | `wthr_activate` | The clothes brush |
   | OnPlayerTarget | `wthr_target` | A DM picking a creature for a test command |
   | OnPlayerEquipItem / OnPlayerUnEquipItem | `wthr_equip` | Keeps the look across armour and cloak changes |
   | OnPlayerRest | `wthr_rest` | Resting cleans up |
   | Every area's OnEnter | `wthr_areaenter` | Creatures get their starting look and blood the moment they appear (placed, spawned, summoned or walking in) |

   Each area's own OnEnter script, and each creature's own OnDamaged script, still runs first. NPCs and monsters get `wthr_damaged` on their OnDamaged when they get their starting look.

   Leave those events as they are; don't also call our scripts from the module's own ones.
5. Mark where dust and snow build up (next section). Then Build Module and save.

## Where dust and snow build up

Float variables are rates per minute of game time. 0 or unset means nothing, and -1 means "none here" where a default would apply.

**On an area**, or on a **trigger** with `wthr_zone` as its OnEnter and OnExit script (the trigger wins while a creature is inside it, for something like a dune field inside a bigger map):

| Variable | Type | Meaning |
|---|---|---|
| `WTHR_DUST_RATE` | float | Dust per minute of travel; a quarter of that while standing |
| `WTHR_SNOW_RATE` | float | Snow per minute, outdoors |
| `WTHR_DUST_STORM` | int | 1 = dust settles over the whole body, not just from the ground up |

**Weather**, on an area or on the module as the default for every area. Negative values wash off:

| Variable | Type | Meaning |
|---|---|---|
| `WTHR_RAIN_DUST`, `WTHR_RAIN_SNOW` | float | Per minute while it rains, e.g. -0.15 |
| `WTHR_SNOWFALL_DUST`, `WTHR_SNOWFALL_SNOW` | float | Per minute while it snows, e.g. `WTHR_SNOWFALL_SNOW` 0.1 |
| `WTHR_IGNORE_WEATHER` | int | On an area: 1 = the weather does nothing here |

The weather does nothing until you set these.

**Fading**, on the module. Dust doesn't fade wherever a dust rate applies, and snow doesn't fade wherever a snow rate applies. Everywhere else they fade at:

| Variable | Default | Meaning |
|---|---|---|
| `WTHR_FADE_DUST` | 0.03 | Dust per minute |
| `WTHR_FADE_SNOW` | 0.05 | Snow per minute, outdoors |
| `WTHR_FADE_SNOW_INDOORS` | 0.4 | Snow per minute, in interiors and underground |

## Starting looks

**On an area**, for its own creatures, or **on a creature** or blueprint, for that creature (overrides the area):

| Variable | Type | Meaning |
|---|---|---|
| `WTHR_START_DUST` | float | Dust 0-1 |
| `WTHR_START_SNOW` | float | Snow 0-1 |
| `WTHR_START_VARY` | float | Random variation 0-1 (default 0.3) |

**On a creature only:**

| Variable | Type | Meaning |
|---|---|---|
| `WTHR_WEATHERS` | int | 1 = builds up and fades like a player |
| `WTHR_SKIP` | int | 1 = never touched (ghosts, constructs, anything that shouldn't look dirty) |

In an area with `WTHR_DUST_STORM = 1`, creatures start with dust over their whole body.

## Blood

Blood needs no setup: it comes from fights anywhere, on players, companions, NPCs and monsters alike.

- **Wounds:** physical damage (slashing, piercing, bludgeoning) leaves the creature's own blood on it. Taking three times its maximum hit points in damage takes it from clean to fully bloodied; healing doesn't remove blood, so it builds up over an adventure until it's washed off. Fire, cold, acid and other damage leave none.
- **Spatter:** a melee attacker (within 3.5 m, not using a ranged weapon) gets the victim's blood on its hands and forearms first, then on its chest and face, mostly on the front. Archers and casters stay clean.
- **Colour:** each creature bleeds in the colour from `appearance.2da`: red, green, yellow, white, or none (skeletons, golems, elementals, which leave nothing on their attackers either). Override it with a string `WTHR_BLOOD_COLOR` on a creature: `R`, `G`, `Y`, `W` or `N`. Each colour of spatter is a layer of its own, using different drops: after fighting orcs and a troll, red and green drops sit side by side instead of mixing.
- **Placement:** blood is placed on the model in 3D, not by its texture. Most creature textures are mirrored (one half serves both sides of a chest, one texture both shins), so placing by texture made every stain appear twice, symmetrically. Drops are a mix of round ones and stretched splashes with trailing tails, of varying sizes, and they gather in clusters rather than spreading evenly.
- **Drying:** fresh blood darkens to a dried brown. New blood on top looks fresher.
- **Gore setting:** a player whose game has gore turned off (Options > Game) sees no blood on anyone. Others still see it.
- **Cleaning:** rain washes it off slowly; resting, washing and the clothes brush remove it.

Classic NWN gave player characters no "damaged" event, but EE accepts one: on login the scripts put `wthr_damaged` on each player's own OnDamaged (keeping any script already there), so blood on players works the same way as on monsters. If a game ever refuses it, players get no blood, and with `WTHR_DEBUG = 1` they're told so. On players the game reports no damage type, so a hit counts as physical when the damager is a creature attacking them with a weapon (melee or ranged). Creatures fighting a player are set up for blood at once, so even a monster that spawns and charges bleeds from the first blow.

**On the module:**

| Variable | Default | Meaning |
|---|---|---|
| `WTHR_BLOOD_DRY_MINUTES` | 5 | Real minutes for blood to dry completely; -1 = it never dries |
| `WTHR_BLOOD_FULL_HP` | 3 | Damage, in multiples of the creature's max HP, that takes its own blood from none to full. Healing doesn't remove blood, so it builds up over an adventure |
| `WTHR_BLOOD_SPATTER` | 1 | How much spatter melee hits leave (a multiplier) |
| `WTHR_RAIN_BLOOD` | 0.1 | Blood washed off per minute in the rain; also on an area; -1 = none |
| `WTHR_BLOOD_OFF` | | Int, 1 = no blood at all |

`WTHR_SKIP = 1` on a creature also keeps it free of blood.

## Placeables and doors

Barrels, crates, carts, tents, placeable buildings and doors take a fixed look from their own variables. Set them on the instance in the area, or on the blueprint. They're shown when a player enters the area and never change over time.

| Variable | Type | Meaning |
|---|---|---|
| `WTHR_DUST` | float | Dust 0-1, climbing from the bottom of each part of the model |
| `WTHR_SPREAD` | float | 0-1: 0 = dust from the bottom up, 1 = all over |
| `WTHR_SNOW` | float | Snow 0-1, on surfaces that face up (lids, roofs, ledges) |
| `WTHR_BLOOD` | float | Blood 0-1 |
| `WTHR_BLOOD_COLOR` | string | `R`, `G`, `Y` or `W` (default `R`) |
| `WTHR_DRY` | float | 0 = fresh blood, 1 = dried |

To change an object's look later from your own script, call `WthrSetObject(oObject, fDust, fSnow, fBlood, "R")` from `wthr_inc`. DMs can also use the test commands on placeables and doors: the cursor accepts them.

**Untick Static.** Most placeables are Static by default (it comes from `placeables.2da`), and the game draws a static placeable as part of the area, so a look set on it never shows. Untick Static on each placeable you give a look; usable placeables are never static. Scripts can't change the flag, but with `WTHR_DEBUG = 1` (or as a DM) you get a message naming every static placeable that has a look when you enter its area, and `/wthr` on a placeable says whether it's static.

Area tiles (the walls, floors and buildings that come from the tileset) can't take a look. They aren't objects, so a script can't point at one wall; the only way to change them is per tileset, for every area that uses it. For a dusty or snowy building, use a placeable building or wall piece instead.

## Checking how dirty you are

Anyone, player or DM, can type `/dirt` to see their own dust, snow and blood, and their companions':

```
You: dusty (34%), a dusting of snow (10%), bloodstained (mostly others'), spattered red and green.
Tomi Undergallows: very dusty (61%), all over, no snow, a few spots of blood (mostly its own, dried).
```

- **Dust:** "a little dusty", then "dusty" and "very dusty", up to "caked in dust". "All over" means storm dust rather than dust from the ground up.
- **Snow:** "a dusting of snow", then "snowy" and "covered in snow", up to "buried in snow".
- **Blood:** "a few spots of blood", then "bloodstained" and "covered in blood", up to "drenched in blood". It also says whose blood it mostly is, whether it has dried, and which colours of spatter are on you.

## Cleaning up

- **Clothes brush:** use it from the quickbar, or type `/brush` with one in your inventory. Your character brushes down for three seconds, removing most of the dust and all of the snow and blood. Sell it in shops or give it at character start.
- **Washing:** `wthr_wash` as a trigger's OnEnter (a stream, a pool), a placeable's OnUsed (a basin, a barrel) or a conversation's Actions Taken (a bathhouse). An optional float `WTHR_WASH` on the trigger, placeable or speaker sets the share removed (default 1 = all).
- **Resting:** the blood is gone and the snow melts. Indoors, the dust goes too; outdoors it stays.
- **Rain:** washes blood off slowly (`WTHR_RAIN_BLOOD`).

## Testing

Test commands work for DMs, or for everyone when the module has the int variable `WTHR_DEBUG = 1`.

- **A DM** gets a cursor after typing a command: click the creature (player, NPC or monster) it applies to, or right-click to cancel.
- **Everyone else** uses the commands on themselves.
- **Add `near`** to use a command on the nearest creature instead, or `me` (DMs) for yourself.

| Command | Effect |
|---|---|
| `/wthr` | All levels and the blood colour, plus what builds up here and what the weather adds |
| `/wthr mats` | The materials found |
| `/dust 0.6`, `/snow 0.6` | Set dust or snow (0-1) |
| `/storm 1` | How far the dust spreads (0 = ground up, 1 = all over) |
| `/blood 0.5` | Set own blood, as from wounds (0-1) |
| `/spatter 0.5 g` | Set others' blood of one colour (0-1): `r`, `g`, `y` or `w` (default red). The other colours stay, so `/spatter 0.5` then `/spatter 0.5 g` gives both |
| `/dry 0.5` | Set how dried the blood is (0 = fresh, 1 = dried) |
| `/clean` | Remove everything |

What to check:

- **Dust climbs:** `/dust 0.2`, then 0.5, then 1. The dust should start at the boots and climb, and `/storm 1` should cover everything. On monsters this depends on the game giving the shader each mesh's size. If dust on a monster appears all at once instead of climbing, tell me.
- **Snow:** `/snow 1` should show white clumps on shoulders, head and boot tops, not on faces or the sides of arms and legs.
- **Building up:** set `WTHR_DUST_RATE` 0.2 on an area and walk around. `/wthr` shows the levels rising, and leaving the area makes them fade.
- **Brush, washing and resting:** each should clean as described above.
- **Blood from fighting:** fight something in melee. Its blood should appear on you (hands and forearms first) and yours on it where you're hit. Try a green-blooded creature too (trolls, for example), and a skeleton, which should leave nothing.
- **Blood looks:** `/blood 1`, `/spatter 1 g` and `/dry 1` show each layer on its own.
- **Gore off:** turn gore off in Options > Game, wait up to 10 seconds, and blood should disappear for you only.
- **Multiplayer:** a second player sees the same dust, snow and blood, including a player who joins after it appeared.

If shader errors show, they're in `logs/nwclientLog1.txt` in your NWN user folder.

## How it works

NWN:EE gives a texture a material when a `.mtr` file of the same name exists. The hak has one material for each creature texture in the base game, cloaks included, 2,047 in all, using `vs_weather` and `fs_weather`. These are the stock lit shaders plus dust, snow and blood blended in before lighting, so they're shaded like the cloth under them. Each material carries:

- **The noise texture** in the shader's unused height-map slot.
- **A height range for its body part** (feet low, head high), so dust can climb. The build bakes in a default, and for player-shaped creatures the scripts send each material the range of the parts it's actually on for that creature, from `wthr_parts.2da`: one texture can dress a thigh in one armour and a shoulder pad in another, and with only the baked-in shoulder range those thighs stayed clean until dust reached the shoulders.
- **How much blood its body part catches:** wounds anywhere, spatter on hands and arms first. Sent per creature the same way.
- **Where a cloak hangs**, for cloaks only. A cloak is a skin mesh, which the engine gives no bounding box, so its height on the figure comes from the cloak model and the race's skeleton, per race, gender and phenotype.
- **Values a script sets on one creature**, via `SetMaterialShaderUniformVec4`: `DustAmount`, `DustSpread`, `SnowAmount`, `BloodWounds`, `BloodDry`, `BloodOwn` (its blood colour) and `SpatterRed`, `SpatterGreen`, `SpatterYellow`, `SpatterWhite` (others' blood, one layer per colour). Only the values that changed are sent, and blood from a fight is bundled into one send per second. Each creature also gets a random `PatternSeed`, which shifts its dust, blood and snow patterns, so two guards with the same race and armour don't get them in the same spots. It's kept in a local variable, so it is new after a server restart.

Gore is a per-player switch: the scripts set a global shader value (`scriptableInt16`) for each player from their gore setting, and the shader skips blood for that player.

Scripts need a creature's texture names for that call, and those don't follow from the model names (an elf's `pelvis003` is textured with `pfh0_pelvis001`). So `tools/build.py` reads every player body-part, cloak, monster, placeable and door model in the game and writes lookup tables into the hak:

- `wthr_<part>.2da` per body part;
- `wthr_cloak.2da` for cloaks. A cloak's texture is `cloak_NNN` from the TEXTURE column of `cloakmodel.2da`, which replaces the cloak model's own;
- `wthr_parts.2da`: each part's height range and blood weights, for the scripts;
- `wthr_appear.2da` for monsters;
- `wthr_plc.2da`, `wthr_door.2da` and `wthr_gdoor.2da` for placeables, tileset doors and generic doors.

A placeable's or door's appearance is read from its saved fields (`ObjectToJson`), since NWScript has no function for it.

## Building

1. Unzip the [neverwinter.nim](https://github.com/niv/neverwinter.nim/releases) release for your system into `tools/neverwinter/`. The script compiler and the GFF tool come from it.
2. Run:

   ```bash
   py tools/build.py
   ```

It reads the game's models (about half a minute) and writes `nwn_weathered.hak` and `nwn_weathered.erf` next to the script. The build finds the game in your Steam libraries; for a GOG or Beamdog copy, set `NWN_ROOT` to the folder that contains `data` (see `tools/nwn_paths.py`).

## Limits

- **Helmets, robes and weapons stay clean.** The game does draw them with a material of the same name, but it never passes a creature's material values on to their models. `SetMaterialShaderUniformVec4` reaches the body, head and cloak, but not these, whether it's called on the creature or on the item. In tests, a helmet, a robe and a greatsword drawn through a test shader kept their default values after a script set new ones (on the greatsword, set both on the creature and on the weapon item). The other ways to change a texture don't fit: `ReplaceObjectTexture` can't take PLT textures, which helmets and robes use, and `SetTextureOverride` changes a texture on every creature a player sees, not just one. So the hak has no materials for them, and they keep the game's own shader. A robe texture that another body part also uses (some robes wear `pmh0_pelvis001`) keeps its material for that part, and it shows nothing on the robe. If a later NWN:EE version passes material values on to these models, as 1.88 did for cloaks, they can be added back.
- Only base-game creatures, placeables and doors are covered. Custom content from other haks (CEP and similar) needs its textures added to the tables.
- Textures that already ship with a material keep it: the two old-style heads, `oldf_head` and `oldm_head`.
- The materials replace the engine's default shader for these textures with the standard lit one, so EE's optional normal-mapped texture packs lose their normal maps on creatures.
- Some placeable and door textures are also used by area tiles (`plc_wood256`, for one). Those tiles now render through the weather shader too, which looks the same with nothing set; a look you set applies only to the placeable or door you set it on.
- The brush uses the stock Rags icon until it gets its own art.

## Repository

- `src/shaders/`: `inc_wthr_vs` (height, facing and standing-pose position on the body) and `inc_wthr_fs` (dust, snow, blood, noise), shared by two variants: `vs_weather`/`fs_weather` with the environment map (creatures, whose texture alpha is shininess) and `vs_wthr_plain`/`fs_wthr_plain` without (placeables and doors, whose alpha is transparency unless their `.txi` asks for an environment map).
- `src/nss/`: `wthr_inc` (all the logic), the event scripts `wthr_modload`, `wthr_enter`, `wthr_chat`, `wthr_activate`, `wthr_equip` and `wthr_rest`, plus `wthr_damaged` (blood on NPCs and monsters), `wthr_target` (DM cursor), `wthr_cmd_inc` (commands), `wthr_zone` (triggers) and `wthr_wash` (washing).
- `tools/build.py`: reads the game's models; generates the materials, tables, noise texture and brush; compiles; packs.
- `tools/nwn_key.py`, `tools/nwn_paths.py`: read the game's archives and find the game.
- `reference/` (not committed): Beamdog's stock shaders and files, extracted for study.
