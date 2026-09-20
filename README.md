# Orbit & Harvest

A complete, small Godot 4 game about a bunny harvesting floating space gardens with a returning scythe. Built with the supplied `jam-collegiate` bunny, crop, rock, greenhouse, scythe, texture, and sound assets. Assets are copied into this project; the original folder is untouched.

## Play

Open `project.godot` in Godot 4.3 or newer (verified in Godot 4.7.2), then press **F6** on `scenes/main.tscn` or **F5**.

- **Left click** an empty tile: walk along a calculated path.
- **Right click** toward a crop: throw the scythe. The dotted line previews its direction and range. It returns automatically; throws are unlimited.
- Harvest **every wheat and carrot** to open the eastern edge tile marked with an arrow. Walk onto it to enter the next screen. The western middle edge goes back.
- Rocks block both movement and throws. Scythes fly across gaps. Crops block walking until harvested.
- Step on a **gold switch** to open a bridge.
- Each crop adds **1** to its separate icon counter. Greenhouses trade **carrots for power** (8 × current power; up to 3) and **wheat for range** (10 × (current range − 2); up to 6 tiles).
- Amber wheat takes 2 power; reinforced carrots take 3. Repeated throws work with the starter blade, so upgrades are helpful but never required.
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

- `scripts/game.gd`: level layouts, gameplay, UI, shops, and smoke checks.
- `scripts/space.gd`: full-window panorama skybox rotating at 0.5 degrees per second.
- `scenes/main.tscn`: entry scene.
- `assets/icons/`: the wheat and carrot icons referenced by the supplied item resources.
- `assets/panorama_image.webp`, `Materials/SpaceSky.tres`: supplied panorama and sky material.
- `Meshes/`, `Materials/`, `Atlases/`, `Imported/`, `Sounds/`: supplied assets.

No plugins, downloads, or external services required.
