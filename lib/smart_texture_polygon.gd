
extends Polygon2D

const helpers = preload("smart_texture_helpers.gd")
const Corner = helpers.Corner
const CornerTexture = helpers.CornerTexture
const Side = helpers.Side
const SideTexture = helpers.SideTexture

const SIDE_MODE_SCALE = 0
const SIDE_MODE_TILE_CUT = 1
const SIDE_MODE_TILE_SCALE = 2
const SIDE_MODE_TILE_SCALE_ENDS = 3

const CORNER_MODE_PARALLELOGRAM = 0
const CORNER_MODE_KITE = 1
const CORNER_MODE_TRIANGLE = 2

const default_uvs = [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]

export(Texture) var top_edge_texture
export(Texture) var left_edge_texture
export(Texture) var right_edge_texture
export(Texture) var bottom_edge_texture
export(Texture) var top_left_corner_texture
export(Texture) var top_right_corner_texture
export(Texture) var bottom_right_corner_texture
export(Texture) var bottom_left_corner_texture
export(float) var thickness = 32
export(bool) var override_color = true
export(int, "Scale", "Tile (Cut last)", "Tile (Scale to fit)", "Tile (Scale only ends)") var side_texture_mode = SIDE_MODE_SCALE
export(int, "Parallelogram", "Kite", "Triangle") var corner_texture_mode = CORNER_MODE_KITE
export(bool) var debug = true

var side_textures = []
var corner_textures = []

var sides = []
var corners = []

func _ready():
	if override_color: set_color(Color(0,0,0,0))
	side_textures.push_back(SideTexture.new(top_edge_texture, Vector2(0, -1)))
	side_textures.push_back(SideTexture.new(left_edge_texture, Vector2(-1, 0)))
	side_textures.push_back(SideTexture.new(bottom_edge_texture, Vector2(0, 1)))
	side_textures.push_back(SideTexture.new(right_edge_texture, Vector2(1, 0)))
	
	corner_textures.push_back(CornerTexture.new(top_left_corner_texture, Vector2(-1, -1), side_textures[1], side_textures[0]))
	corner_textures.push_back(CornerTexture.new(top_right_corner_texture, Vector2(1, -1), side_textures[0], side_textures[3]))
	corner_textures.push_back(CornerTexture.new(bottom_right_corner_texture, Vector2(1, 1), side_textures[3], side_textures[2]))
	corner_textures.push_back(CornerTexture.new(bottom_left_corner_texture, Vector2(-1, 1), side_textures[2], side_textures[1]))
	
	for side_texture in side_textures:
		corner_textures.push_back(CornerTexture.new(side_texture.texture, side_texture.normal, side_texture, side_texture, false))

func fit_side_texture(side):
	var best = null
	var best_weigth = 0
	for side_texture in side_textures:
		var weigth = side_texture.get_weight(side)
		if best == null or best_weigth < weigth:
			best = side_texture
			best_weigth = weigth
	side.texture = best

func fit_corner_texture(corner, previous_side, next_side):
	if !previous_side.texture: fit_side_texture(previous_side)
	if !next_side.texture: fit_side_texture(next_side)
	var best = null
	for corner_texture in corner_textures:
		var pre = corner_texture.previous_side_texture == previous_side.texture
		var post = corner_texture.next_side_texture == next_side.texture
		if pre and post:
			corner.texture = corner_texture
			return
		elif best == null and (pre or post) and corner_texture.is_source_corner:
			best = corner_texture
	corner.texture = best

func draw_side_texture(side, uvs, offset=0, size=-1):
	if !side.texture: return
	var start = side.start + side.direction * offset
	var end = start + side.direction * size
	if size == -1:
		end = side.end
	
	draw_primitive([
		start,
		start + side.normal * thickness,
		end + side.normal * thickness,
		end,
	], [Color(1,1,1), Color(1,1,1), Color(1,1,1), Color(1,1,1)], uvs, side.texture.texture)

func draw_corner_texture(corner, uvs):
	if corner.is_inset: return
	if !corner.texture: return
	if corner.texture.is_source_corner and corner_texture_mode != CORNER_MODE_TRIANGLE:
		var points = [
			corner.position,
			corner.position + corner.after_side_normal * thickness,
			corner.position + (corner.before_side_normal + corner.after_side_normal) * thickness,
			corner.position + corner.before_side_normal * thickness,
		]
		if corner_texture_mode == CORNER_MODE_KITE:
			var after_tangent = corner.after_side_normal.rotated(PI/2) / tan(corner.angle / 2)
			points[2] = corner.position + (corner.after_side_normal + after_tangent) * thickness
		elif corner_texture_mode == CORNER_MODE_PARALLELOGRAM:
			pass
		else:
			return
		draw_primitive(points, [Color(1,1,1), Color(1,1,1), Color(1,1,1), Color(1,1,1)], uvs, corner.texture.texture)
	else:
		draw_primitive([
			corner.position,
			corner.position + corner.after_side_normal * thickness,
			corner.position + corner.before_side_normal * thickness,
			corner.position,
		], [Color(1,1,1), Color(1,1,1), Color(1,1,1)], uvs, corner.texture.texture)
		
	

func _draw():
	var points = get_polygon()
	sides = []
	corners = []
	for i in range(0, points.size()):
		corners.push_back(Corner.new(points[i], points[i-1], points[(i+1) % points.size()]))
		sides.push_back(Side.new(points[i-1], points[i]))
	
	for side in sides:
		fit_side_texture(side)
		var uvs = side.texture.transform_uvs(default_uvs)
		
		if side_texture_mode == SIDE_MODE_SCALE:
			draw_side_texture(side, uvs)
		elif side_texture_mode >= SIDE_MODE_TILE_CUT:
			var side_length = side.get_length()
			var texture_length = side.texture.get_length(thickness)
			var side_direction =(side.end - side.start).normalized()
			
			var leftover = fmod(side_length, texture_length)
			var tiles = floor(side_length / texture_length)
			
			for i in range(tiles):
				var start
				var end
				if side_texture_mode == SIDE_MODE_TILE_SCALE:
					var distance = texture_length + leftover / tiles
					draw_side_texture(side, uvs, i * distance, distance)
				else:
					draw_side_texture(side, uvs, i * texture_length + leftover / 2, texture_length)
			
			if side_texture_mode == SIDE_MODE_TILE_CUT:
				var ratio = leftover/2/texture_length
				var left_uvs = side.texture.transform_uvs(helpers.cut_uvs(default_uvs, Vector2(ratio, 1), Vector2(1-ratio, 0)))
				var right_uvs = side.texture.transform_uvs(helpers.cut_uvs(default_uvs, Vector2(ratio, 1)))
				draw_side_texture(side, left_uvs, 0, leftover/2)
				draw_side_texture(side, right_uvs, side_length - leftover/2)
			elif tiles == 0:
				draw_side_texture(side, uvs)
			elif side_texture_mode == SIDE_MODE_TILE_SCALE_ENDS:
				var ratio = leftover/2/texture_length
				draw_side_texture(side, uvs, 0, leftover/2)
				draw_side_texture(side, uvs, side_length - leftover/2)
				
		
		if debug: side.debug_draw(self)
	
	for i in range(0, points.size()):
		var corner = corners[i]
		fit_corner_texture(corner, sides[i], sides[(i+1) % points.size()])
		if !corner.texture: continue
		var uvs = corner.texture.transform_uvs(default_uvs)
		
		draw_corner_texture(corner, uvs)
		
		if debug: corner.debug_draw(self)

