@tool
class_name LevelScene
extends Node3D

@export_category("Identity")
@export var display_name := "Untitled field"
@export var region := ""
@export var shop := false

enum Tile { FLOOR, VOID, ROCK, SWITCH, BRIDGE, WHEAT, TOUGH_WHEAT, CARROT, TOUGH_CARROT }

const TILE_KINDS := {
	Tile.FLOOR: ".",
	Tile.VOID: "~",
	Tile.ROCK: "#",
	Tile.SWITCH: "s",
	Tile.BRIDGE: "b",
	Tile.WHEAT: "w",
	Tile.TOUGH_WHEAT: "W",
	Tile.CARROT: "c",
	Tile.TOUGH_CARROT: "C"
}

func _ready() -> void:
	if not Engine.is_editor_hint():
		grid_map().visible = false

func tile_kind_at(cell: Vector2i) -> String:
	var tile := grid_map().get_cell_item(Vector3i(cell.x-5, 0, cell.y-4))
	return TILE_KINDS.get(tile, ".")

func cells_in(tile: Tile) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for grid_cell in grid_map().get_used_cells():
		if grid_map().get_cell_item(grid_cell) == tile:
			cells.append(Vector2i(grid_cell.x+5, grid_cell.z+4))
	return cells

func crop_kind_at(cell: Vector2i) -> String:
	var tile := grid_map().get_cell_item(Vector3i(cell.x-5, 0, cell.y-4))
	return TILE_KINDS.get(tile, ".") if tile in [Tile.WHEAT, Tile.TOUGH_WHEAT, Tile.CARROT, Tile.TOUGH_CARROT] else "."

func crop_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for tile in [Tile.WHEAT, Tile.TOUGH_WHEAT, Tile.CARROT, Tile.TOUGH_CARROT]:
		cells.append_array(cells_in(tile))
	return cells

func grid_map() -> GridMap:
	return get_node("Layout") as GridMap
