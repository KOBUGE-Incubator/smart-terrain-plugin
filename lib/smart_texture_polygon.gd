
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

const default_uvs = [Vector2(0, 0), Vector2(0, 1), Vector2(1, 1), Vector2(1, 0)]

export(Texture) var top_edge_texture
export(Texture) var left_edge_texture
export(Texture) var right_edge_texture
export(Texture) var bottom_edge_texture
export(Texture) var top_left_corner_texture
export(float) var thickness = 32
export(bool) var override_color = true
export(int, "Scale", "Tile (Cut last)", "Tile (Scale to fit)", "Tile (Scale only ends)") var side_texture_mode = SIDE_MODE_SCALE

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
	
	corner_textures.push_back(CornerTexture.new(top_left_corner_texture, Vector2(-1, -1), PI/2))

func fit_side_texture(normal = Vector2()):
	var best = null
	for side_texture in side_textures:
		if best == null or side_texture.is_better(best, normal):
			best = side_texture
	return best

func fit_corner_texture(normal = Vector2(), angle = 0):
	var best = null
	for corner_texture in corner_textures:
		if best == null or corner_texture.is_better(best, normal, angle):
			best = corner_texture
	return best

func draw_side_texture(side, side_texture, uvs, offset=0, size=-1):
	var start = side.start + side.direction * offset
	var end = start + side.direction * size
	if size == -1:
		end = side.end
	draw_primitive([
		start,
		start + side.normal * thickness,
		end + side.normal * thickness,
		end,
	], [Color(1,1,1), Color(1,1,1), Color(1,1,1), Color(1,1,1)], uvs, side_texture.texture)

func _draw():
	var points = get_polygon()
	sides = []
	corners = []
	for i in range(0, points.size()):
		corners.push_back(Corner.new(points[i], points[i-1], points[(i+1) % points.size()]))
		sides.push_back(Side.new(points[i-1], points[i]))
	
	for side in sides:
		var side_texture = fit_side_texture(side.normal)
		var uvs = side_texture.transform_uvs(default_uvs)
		
		if side_texture_mode == SIDE_MODE_SCALE:
			draw_side_texture(side, side_texture, uvs)
		elif side_texture_mode >= SIDE_MODE_TILE_CUT:
			var side_length = side.get_length()
			var texture_length = side_texture.get_length(thickness)
			var side_direction =(side.end - side.start).normalized()
			
			var leftover = fmod(side_length, texture_length)
			var tiles = floor(side_length / texture_length)
			
			for i in range(tiles):
				var start
				var end
				if side_texture_mode == SIDE_MODE_TILE_SCALE:
					var distance = texture_length + leftover / tiles
					draw_side_texture(side, side_texture, uvs, i * distance, distance)
				else:
					draw_side_texture(side, side_texture, uvs, i * texture_length + leftover / 2, texture_length)
			
			if side_texture_mode == SIDE_MODE_TILE_CUT:
				var ratio = leftover/2/texture_length
				var left_uvs = side_texture.transform_uvs(helpers.cut_uvs(default_uvs, Vector2(ratio, 1), Vector2(1-ratio, 0)))
				var right_uvs = side_texture.transform_uvs(helpers.cut_uvs(default_uvs, Vector2(ratio, 1)))
				draw_side_texture(side, side_texture, left_uvs, 0, leftover/2)
				draw_side_texture(side, side_texture, right_uvs, side_length - leftover/2)
			elif tiles == 0:
				draw_side_texture(side, side_texture, uvs)
			elif side_texture_mode == SIDE_MODE_TILE_SCALE_ENDS:
				var ratio = leftover/2/texture_length
				draw_side_texture(side, side_texture, uvs, 0, leftover/2)
				draw_side_texture(side, side_texture, uvs, side_length - leftover/2)
				
		
		side.debug_draw(self)
	
	for corner in corners:
		pass#corner.debug_draw(self)

