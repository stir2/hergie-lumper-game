# Orbit & Harvest

A complete, small Godot 4 game about a bunny harvesting floating space gardens with a returning scythe. Built with the supplied `jam-collegiate` bunny, crop, rock, greenhouse, scythe, texture, and sound assets. Assets are copied into this project; the original folder is untouched.

## Play

Open `project.godot` in Godot 4.3 or newer (verified in Godot 4.7.2), then press **F6** on `scenes/main.tscn` or **F5**.

- **Left click** an empty tile: walk along a calculated path.
- **Hold right click** toward a crop to charge, then **release** to throw. The dotted line appears only while charging and grows to the current range over 0.9 seconds. A quick tap throws one tile; a full charge uses the entire upgraded range. The scythe returns automatically; throws are unlimited. Releasing outside the game view, pausing, or switching away from the window cancels charging.
- The eastern edge tile marked with an arrow is always available to enter the next screen. The western middle edge goes back; unharvested crops remain when a field is revisited.
- Rocks block movement and throws until the appropriate breaking upgrade is installed. Scythes fly across gaps; the Jumping upgrade lets the bunny cross one void tile. Crops block walking until harvested.
- Step on a **gold switch** to open a bridge.
- Each crop adds **1** to its separate icon counter. Titanium rocks yield **1 titanium** when broken after **Break Titanium Level 2**, which also reveals the titanium HUD counter. Step onto a **Shop** tile to open the exchange; its beacon flashes green whenever any resource can afford a remaining upgrade. The five upgrades are **Break Rock Level 1** (ordinary rock), **Break Titanium Level 2**, two **Scythe Reach** levels (+1 tile each), and **Jumping** across one void tile. Carrots buy breaking upgrades, wheat buys reach, and titanium buys jumping.
- Amber wheat takes 2 hits; reinforced carrots take 3. Repeated throws work with the starter blade, so upgrades are helpful but never required for crops.
- **R:** reset the current unsaved field, reversing its harvest rewards. Saved fields keep their collected crops.
- **Esc:** pause. **M:** mute. **F11:** fullscreen.

Six harvest puzzles and two greenhouse waystations form an eight-screen journey with a completion screen and replay. Harvest, bridge state, upgrades, and crop inventories persist across screen changes **for the current session**; closing the game starts a new run.

## Checks

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . -- --smoke
godot --path . -- --input-check
```

The graphical input check injects mouse events to verify walking, throws, locked and unlocked exits, backtracking, actual shop buttons, bridge activation, completion, and replay; it saves screenshots.

The smoke check exercises movement/path blocking, a real scythe flight and return, solvability of every field at starter range, bridges, purchases, and crop persistence. For a visual check, run `godot --path . -- --capture`; it writes `screenshot.png`. `--stage=2` previews the first greenhouse.

The default window is 1920×1200. The game view renders at 1940×1156 with 4× MSAA, and the skybox renders at twice the logical window resolution. Floor tiles use the supplied Jefferson dirt textures.

## Project

- `scenes/levels/`: editor-editable 3D scenes for the eight screens. Open a scene, select its `Layout` GridMap, then use the shared tile palette to paint terrain, crop, and scenery tiles. Buildings, broken glass, concrete debris, and titanium rocks block movement; railings remain decorative. Paint Floor to restore an ordinary tile. The playable board spans GridMap `x` values −5 through 5 and `z` values −4 through 4.
- `scenes/levels/level_tiles.tres`: the shared GridMap mesh library and its tile palette.
- `scripts/level_scene.gd`: the 3D level-scene schema and GridMap-to-tile conversion.
- `scripts/game.gd`: gameplay, UI, shops, and smoke checks.
- `scripts/space.gd`: full-window panorama skybox rotating at 0.5 degrees per second in yaw and 0.22 in pitch.
- `scenes/main.tscn`: entry scene.
- `assets/icons/`: the wheat and carrot icons referenced by the supplied item resources.
- `assets/panorama_image.webp`, `Materials/SpaceSky.tres`: supplied panorama and sky material.
- `Meshes/`, `Materials/`, `Atlases/`, `Imported/`, `Sounds/`: supplied assets.

No plugins, downloads, or external services required.
