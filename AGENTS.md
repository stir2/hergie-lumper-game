# Working on Orbit & Harvest

This folder is the runnable Godot project. Continue editing it here. Read current files before changing them: the user also edits assets and project settings directly. Preserve unrelated changes. Later user instructions take precedence over this document.

## Project map

- `project.godot` → `scenes/main.tscn` → `scripts/game.gd`.
- `scripts/game.gd` builds the 3D board, HUD, shops, input, charge/throw logic, and level layouts at runtime. Most scene changes belong here, not in the minimal `.tscn`.
- `scripts/space.gd` renders and rotates the panorama skybox in a separate viewport.
- `Materials/SpaceSky.tres` references `assets/panorama_image.webp`, supplied by the user.
- `assets/icons/wheat.png` and `carrot.png` are the current HUD/shop icons. Preserve these user-updated PNGs; do not revert to the older JPG placeholders.
- `Meshes/`, `Materials/`, `Atlases/`, `Imported/`, and `Sounds/` contain assets originally copied from sibling `../jam-collegiate`. The game is self-contained; do not modify that sibling folder.
- `Imported/PNG/Jefferson/` contains the dirt, sandy, rocky, and seeds/weeds floor textures. `floor_tile()` selects them and creates thick dark tile borders.
- `tests/input_check.gd` exercises actual input and saves screenshots. `smoke_test()` in `game.gd` checks puzzle solvability and core rules. `README.md` documents play and commands.

## User's established direction

- Tile-based, screen-based space farming with the supplied bunny and throwable scythe.
- Keep the HUD minimal. The user removed the top-left logo/title/subtitle, field names, region/orbit display, progress bar, remaining-crop text, tutorials, hints, and control instructions. Do not reintroduce these without a request.
- Keep separate wheat/carrot inventory icons and counts. They are spendable resources, not a unified seed-credit currency.
- Keep the supplied panorama, slowly rotating on both yaw and pitch axes.
- Keep the supplied dirt floor textures, thick tile borders, and closer orthographic camera.
- The aim line is hidden by default. It appears only while charging and indicates charged throw range.
- Make targeted changes; preserve user-authored assets and unrelated settings. No external services or plugins are needed.

## Gameplay contracts

- Left click walks via grid pathfinding. Crops and rocks block walking; empty space cannot be crossed without a bridge.
- Hold right click to charge; release to throw. Charging takes 0.9 seconds, from a one-tile tap to the current `reach`. The line grows with that range. Scythe power is a separate upgrade.
- Release is handled in `_input()` so UI cannot swallow it. Press is handled in `_unhandled_input()`. Preserve coordinate conversion and cancel charging on pause, focus loss, screen/reset changes, or release outside the view. Movement and transitions cannot proceed during charging.
- A throw snapshots its charged range in `shot_limit`; outbound collision uses substeps. Rocks stop it, gaps do not. It returns automatically. A crop is hit once per throw.
- Clear all crops to use the eastern gate at `(10,4)`. The western gate `(0,4)` returns to the previous screen. Gold switches open bridges. All six fields are solvable at starter power/range through repeated throws and positioning.
- Eight screens: six fields, with greenhouse stops at indices 2 and 5. Layout symbols: `.` floor, `~` void, `#` rock, `w/c` ordinary crops, `W/C` tough crops, `s` switch, `b` bridge location.
- Each harvested crop adds one to `harvest.w` or `harvest.c`. Power costs `8 * power` carrots, capped at power 3. Range costs `10 * (reach - 2)` wheat, capped at reach 6. Update inventory, affordability, and displayed prices together.
- Reset reverses an unsaved field's harvested resources; revisited/saved fields retain their state. Avoid resource duplication. Progress persists across screens for the running session, not across app launches.

## Rendering and input coordinates

- Godot 4, GL Compatibility renderer; tested locally with Godot 4.7.2.
- Logical UI coordinates are 1280×800, with a 1920×1200 default window.
- The game SubViewport is 1940×1156, displayed at half scale, with 4× MSAA. The sky viewport also renders at twice logical resolution. Keep these scales consistent when changing resolution.
- `mouse_world()` converts logical screen coordinates through the container's inverse global transform before ray projection. Do not merely subtract its position.
- Test clicks convert projected viewport coordinates through the container transform and then the root viewport's final transform. Injected input may be buffered; wait for processing before asserting immediate state changes.
- Screenshot tests explicitly call `RenderingServer.force_draw()`; waiting only for `frame_post_draw` can stall when the window is obscured.

## Run and verify

Use `godot` if on PATH. On this machine the binary is `/Applications/Godot.app/Contents/MacOS/Godot`:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . -- --smoke
godot --path . -- --input-check
godot --path .
```

For visual changes, launch with `-- --capture` and inspect `screenshot.png`; `-- --stage=2 --capture` previews a greenhouse. The graphical input check also produces `screenshot-charge.png`, `screenshot-greenhouse.png`, and `screenshot-final-field.png`.

Run checks relevant to the change. Charging/input/currency changes warrant input checks; camera/layout changes warrant screenshot inspection and click accuracy checks. Plain documentation changes do not require a game test. Report exactly what passed; do not treat headless tests as visual verification. Keep `.godot/` and generated screenshots out of source control. The sandbox can deny native window launch or Godot's user-data/editor-settings writes; use the environment's normal approval mechanism when needed and distinguish those errors from script failures.
