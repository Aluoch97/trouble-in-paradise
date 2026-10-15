class_name TownLayout
extends RefCounted
## The street grid of Paradise. Same layout as the web prototype:
## a 40 x 40 tile grid, 4 m per tile, a two-lane road every 10 tiles.
##
## tools/generate_scenes.gd reads this to build res://scenes/world/town.tscn.
## Traffic, pedestrians and the radar read it too, so roads stay in sync.

const N := 40
const TILE := 4.0
const SIZE := N * TILE ## 160 m across
const ROAD_LINES := [0, 10, 20, 30] ## first tile of each road (roads are 2 tiles wide)

enum { GRASS, ROAD, WALK, BUILDING, WATER, DECK, LOT, TREE }

const BLOCK_COLORS := [
	Color("f28f79"), Color("f6c177"), Color("7fc8b6"), Color("e9a6c8"),
	Color("c3aef0"), Color("f3dba6"), Color("9cc3ef"),
]

## Which 10 x 10 block holds what. Block (1,1) = Knox Ridge pool, (3,3) = Quarry Trail.
const KNOX_RIDGE := Vector2i(1, 1)
const QUARRY_TRAIL := Vector2i(3, 3)

var tiles := PackedByteArray()
var heights := PackedByteArray()
var tints := PackedByteArray()
## Parked cars: { "pos": Vector2 (tile units), "facing": float (radians), "color": Color }
var parked: Array[Dictionary] = []

var _seed := 2018


func _init() -> void:
	tiles.resize(N * N)
	heights.resize(N * N)
	tints.resize(N * N)
	_generate()


func at(x: int, y: int) -> int:
	if x < 0 or y < 0 or x >= N or y >= N:
		return -1
	return tiles[y * N + x]


func height_at(x: int, y: int) -> int:
	return heights[y * N + x]


func tint_at(x: int, y: int) -> int:
	return tints[y * N + x]


static func tile_center(x: float, y: float) -> Vector3:
	return Vector3((x + 0.5) * TILE, 0.0, (y + 0.5) * TILE)


static func district_at(world_pos: Vector3) -> String:
	var bx := floori(world_pos.x / TILE / 10.0)
	var by := floori(world_pos.z / TILE / 10.0)
	if Vector2i(bx, by) == KNOX_RIDGE:
		return "Knox Ridge"
	if Vector2i(bx, by) == QUARRY_TRAIL:
		return "Quarry Trail"
	return "Paradise"


## Lanes for traffic. Right-hand traffic. Each lane: { "axis": "x" or "z", "line": float (m), "dir": 1 or -1 }
static func lanes() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: int in ROAD_LINES:
		var near := (r + 0.5) * TILE
		var far := (r + 1.5) * TILE
		out.append({"axis": "x", "line": far, "dir": 1})
		out.append({"axis": "x", "line": near, "dir": -1})
		out.append({"axis": "z", "line": near, "dir": 1})
		out.append({"axis": "z", "line": far, "dir": -1})
	return out


## Sidewalk walking lines for pedestrians: { "axis", "line" }
static func sidewalk_lines() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b in range(4):
		for k: int in [2, 9]:
			var line := (b * 10 + k + 0.5) * TILE
			out.append({"axis": "x", "line": line})
			out.append({"axis": "z", "line": line})
	return out


func _rand() -> float:
	# Same generator as the web prototype, so both versions build the same town.
	_seed = (_seed * 1664525 + 1013904223) & 0xFFFFFFFF
	return float(_seed) / 4294967296.0


func _set_tile(x: int, y: int, t: int, h: int = 0, c: int = 0) -> void:
	var i := y * N + x
	tiles[i] = t
	heights[i] = h
	tints[i] = c


func _generate() -> void:
	for y in range(N):
		for x in range(N):
			var mx := x % 10
			var my := y % 10
			if mx < 2 or my < 2:
				_set_tile(x, y, ROAD)
			elif mx == 2 or mx == 9 or my == 2 or my == 9:
				_set_tile(x, y, WALK)
			else:
				_set_tile(x, y, GRASS)

	var kinds := ["apts", "lot", "park", "shops", "apts", "park", "lot", "shops", "apts", "shops", "park", "apts", "lot", "apts"]
	var ki := 0
	for by in range(4):
		for bx in range(4):
			var x0 := bx * 10 + 3
			var y0 := by * 10 + 3
			if Vector2i(bx, by) == KNOX_RIDGE:
				_build_pool(x0, y0)
				continue
			if Vector2i(bx, by) == QUARRY_TRAIL:
				_build_home()
				continue
			var kind: String = kinds[ki % kinds.size()]
			ki += 1
			var c := int(_rand() * BLOCK_COLORS.size())
			match kind:
				"apts":
					var h := 2 + int(_rand() * 3)
					for y in range(y0, y0 + 6):
						for x in range(x0, x0 + 6):
							var court := x >= x0 + 2 and x <= x0 + 3 and y >= y0 + 2 and y <= y0 + 3
							if court:
								_set_tile(x, y, GRASS)
							else:
								_set_tile(x, y, BUILDING, h, c)
					_set_tile(x0 + 2, y0 + 2, TREE)
				"lot":
					for y in range(y0, y0 + 6):
						for x in range(x0, x0 + 6):
							_set_tile(x, y, LOT)
					for i in range(3):
						if _rand() < 0.8:
							parked.append({"pos": Vector2(x0 + 1 + i * 2, y0 + 1.1), "facing": PI / 2.0, "color": BLOCK_COLORS[int(_rand() * BLOCK_COLORS.size())]})
						if _rand() < 0.7:
							parked.append({"pos": Vector2(x0 + 1 + i * 2, y0 + 4.9), "facing": -PI / 2.0, "color": BLOCK_COLORS[int(_rand() * BLOCK_COLORS.size())]})
				"park":
					for y in range(y0, y0 + 6):
						for x in range(x0, x0 + 6):
							if _rand() < 0.32:
								_set_tile(x, y, TREE)
				_:
					var h := 1 + int(_rand() * 2)
					for y in range(y0, y0 + 6):
						for x in range(x0, x0 + 6):
							var edge := x == x0 or y == y0 or x == x0 + 5 or y == y0 + 5
							if edge:
								_set_tile(x, y, BUILDING, h, c)
							else:
								_set_tile(x, y, LOT)


func _build_pool(x0: int, y0: int) -> void:
	# Knox Ridge: apartment row at the back, pool deck in front of it.
	for y in range(y0, y0 + 6):
		for x in range(x0, x0 + 6):
			_set_tile(x, y, DECK)
	for y in range(y0 + 2, y0 + 4):
		for x in range(x0 + 1, x0 + 5):
			_set_tile(x, y, WATER)
	for x in range(x0, x0 + 6):
		_set_tile(x, y0, BUILDING, 3, 0)
	_set_tile(x0, y0 + 1, TREE)
	_set_tile(x0 + 5, y0 + 1, TREE)


func _build_home() -> void:
	# Quarry Trail: Nick and Brandon's place with a driveway.
	for y in range(35, 38):
		for x in range(35, 38):
			_set_tile(x, y, BUILDING, 2, 5)
	for y in range(34, 38):
		for x in range(33, 35):
			_set_tile(x, y, LOT)
	_set_tile(38, 33, TREE)
	_set_tile(36, 33, TREE)
	_set_tile(38, 38, TREE)
	_set_tile(33, 38, TREE)
