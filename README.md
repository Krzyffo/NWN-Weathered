# NWN-Weathered

Dust and snow on characters and monsters in Neverwinter Nights: Enhanced Edition, one creature at a time.

- **Dust:** patchy, sand-coloured, dulls the cloth under it. A little shows as scattered patches; a lot covers most of the outfit.
- **Snow:** settles where surfaces face up, such as shoulders, hoods and the tops of boots, and moves with the creature.
- **Per creature:** each player character, NPC or monster has its own amounts, set from script.
- **Multiplayer:** the amounts are stored on the creature, so every player sees the same dusty traveller.

Status: **first test build**. The parts below are untested in game.

## How it works

NWN:EE gives a texture a material when a `.mtr` file with the same name exists. The hak has one material for each creature texture in the base game, 2,054 in all. Each material renders that texture with `fs_weather`, the stock lit shader plus dust and snow, which are blended into the cloth colour before lighting so they are lit like the cloth. Each material has two values, `DustAmount` and `SnowAmount`, and `SetMaterialShaderUniformVec4` sets them on a single creature.

Scripts need the creature's texture names for that call, and those don't follow from the model names (an elf's `pelvis003` is textured with `pfh0_pelvis001`). So `tools/build.py` reads every player body-part model and every monster model in the game and writes lookup tables into the hak:

- `wthr_<part>.2da`: one per body part. The row is the part number and the column is the model prefix, such as `pmd0` for a male dwarf.
- `wthr_appear.2da`: the textures of each `appearance.2da` row, for monsters.

`wthr_inc` looks up the textures of what a creature is wearing right now, armour parts or bare body, and sets the values on each one.

## Testing

1. Get the files: run `py tools/build.py` (see [Building](#building)). It writes `nwn_weathered.hak` and `nwn_weathered.erf` into `tools/`.
2. Copy `nwn_weathered.hak` into your NWN `hak` folder. In the toolset: Module Properties > Custom Content > add `nwn_weathered`.
3. File > Import > `nwn_weathered.erf`.
4. Module Properties > Events:
   - **OnPlayerChat:** `wthr_chat`. If the module already has a script there, add `ExecuteScript("wthr_chat", OBJECT_SELF);` to it.
   - **OnPlayerEquipItem** and **OnPlayerUnEquipItem:** `wthr_equip`, so dust and snow move to new armour. If the module already has scripts there, add `ExecuteScript("wthr_equip", OBJECT_SELF);` to them.
5. Build Module, save, and test.

| Command | Effect |
|---|---|
| `/dust 0.6` | Make yourself dusty (0-1) |
| `/snow 0.6` | Make yourself snowy (0-1) |
| `/dust 0.6 near` | The same on the nearest creature, player or monster |
| `/clean` | Remove dust and snow from yourself (`/clean near` for the nearest creature) |
| `/wthr mats` | List the materials found for you (`/wthr mats near` for the nearest creature) |

What to check:

- `/dust 1` and `/snow 1` show on your character and not on the creatures around you.
- `/dust 1 near` next to a monster dusts only that monster.
- Changing armour keeps the dust.
- In multiplayer, the other player sees your dust too, including a player who joins after it was set.

If nothing shows, compare `/wthr mats` with what the creature wears. An empty list means the lookup failed. A list with no visible change means the engine didn't apply the materials. If the game logs shader errors, they're in `logs/nwclientLog1.txt` in your NWN user folder.

## Building

1. Unzip the [neverwinter.nim](https://github.com/niv/neverwinter.nim/releases) release for your system into `tools/neverwinter/`. The script compiler comes from it.
2. Run:

   ```bash
   py tools/build.py
   ```

It reads the game's models (about half a minute) and writes `nwn_weathered.hak` and `nwn_weathered.erf` next to the script. The build finds the game in your Steam libraries; for a GOG or Beamdog copy, set `NWN_ROOT` to the folder that contains `data` (see `tools/nwn_paths.py`).

## Limits

- Only base-game creatures are covered. Custom content from other haks (CEP and similar) needs its textures added to the tables.
- Textures that already ship with a material keep it: the two old-style heads, `oldf_head` and `oldm_head`.
- The material replaces the engine's default shader for these textures with the standard lit one, so EE's optional normal-mapped texture packs lose their normal maps on creatures.

## Repository

- `src/shaders/fs_weather.shd`: the shader.
- `src/nss/`: `wthr_inc` (look-ups and setting values), `wthr_chat` (test commands), `wthr_equip` (keeps the effect across armour changes).
- `tools/build.py`: reads the game's models, generates the materials and tables, compiles and packs.
- `tools/nwn_key.py`, `tools/nwn_paths.py`: read the game's archives and find the game.
- `reference/` (not committed): Beamdog's stock shaders and files, extracted for study.
