
extends Polygon2D

class Side:
	var start = Vector2()
	var end = Vector2()
	var normal = Vector2()
	
	func recalculate_normal():
		normal = (start - end).rotated(-PI/2).normalized() # FIXME: clockwise vs anticlockwise polygons
	
	func debug_draw(canvasitem):
		var middle = (start + end)/2
		canvasitem.draw_line(start, end, Color(1, 0, 0), 3)
		canvasitem.draw_line(middle, middle + normal*50, Color(0, 1, 0), 2)
	
	func _init(from, to):
		start = from
		end = to
		recalculate_normal()

class Corner:
	var before = Vector2()
	var position = Vector2()
	var after = Vector2()
	var normal = Vector2()
	var angle = 0
	
	func recalculate_normal(): # FIXME: clockwise vs anticlockwise polygons
		var pre_normal_1 = (position - before).normalized()
		var pre_normal_2 = (position - after).normalized()
		normal = (pre_normal_1.normalized() + pre_normal_2.normalized()).normalized()
		
		# If the angle is obtuse
		if Vector3(pre_normal_1.x, pre_normal_1.y, 0).cross(Vector3(pre_normal_2.x, pre_normal_2.y, 0)).z > 0:
			normal = -normal
		
		# Couldn't make normal, try something else
		if normal.length_squared() < 0.9:
			normal = (before - after).rotated(-PI/2).normalized()
		
		angle = abs(before.angle_to_point(position) - position.angle_to_point(after))
	
	func debug_draw(canvasitem):
		canvasitem.draw_circle(position, 5, Color(0, 0, 1))
		canvasitem.draw_line(position, position + normal*50, Color(0, 1, 0), 2)
	
	func _init(pos, pre=Vector2(), post=Vector2()):
		position = pos
		before = pre
		after = post
		recalculate_normal()

const default_uvs = [Vector2(-0.5, -0.5), Vector2(-0.5, 0.5), Vector2(0.5, 0.5), Vector2(0.5, -0.5)]

export(Texture) var top_edge_texture
export(Texture) var left_edge_texture
export(Texture) var right_edge_texture
export(Texture) var bottom_edge_texture
export(float) var thickness = 32
export(bool) var override_color = true

var side_textures = []

var sides = []
var corners = []

func _ready():
	if override_color: set_color(Color(0,0,0,0))
	side_textures.push_back({
		normal = Vector2(0, -1),
		texture = top_edge_texture
	})
	side_textures.push_back({
		normal = Vector2(-1, 0),
		texture = left_edge_texture
	})
	side_textures.push_back({
		normal = Vector2(1, 0),
		texture = right_edge_texture
	})
	side_textures.push_back({
		normal = Vector2(0, 1),
		texture = bottom_edge_texture
	})

func fit_side_texture_to_normal(normal = Vector2()):
	var best = null
	var best_dot = -2 # Lower than any possible dot product
	#print("FIT:", normal)
	for side_texture in side_textures:
		#print("\tTRY:", side_texture.normal, side_texture.normal.dot(normal))
		var current_dot = side_texture.normal.dot(normal)
		if best_dot < current_dot:
			best_dot = current_dot
			best = side_texture
	return best

func _draw():
	var points = get_polygon()
	sides = []
	corners = []
	for i in range(0, points.size()):
		corners.push_back(Corner.new(points[i], points[i-1], points[(i+1) % points.size()]))
		sides.push_back(Side.new(points[i-1], points[i]))
	
	for side in sides:
		#side.debug_draw(self)
		var side_texture = fit_side_texture_to_normal(side.normal)
		var uvs = Vector2Array(default_uvs)
		for i in range(uvs.size()):
			uvs[i] = uvs[i].rotated(side_texture.normal.angle()) + Vector2(.5,.5)
		if side_texture.texture extends AtlasTexture:
			var texture_size = side_texture.texture.get_atlas().get_size()
			var region = side_texture.texture.get_region()
			var start = region.pos / texture_size
			var size = region.size / texture_size 
			for i in range(uvs.size()):
				uvs[i] = start + uvs[i] * size
		var p = (side.start + side.end)/2
		var fake_points = [
			p + Vector2(-16,-16),
			p + Vector2(-16, 16),
			p + Vector2( 16, 16),
			p + Vector2( 16,-16)
		]
		draw_primitive([
			side.start,
			side.start + side.normal * thickness,
			side.end + side.normal * thickness,
			side.end,
		], [Color(1,1,1),Color(1,1,1),Color(1,1,1),Color(1,1,1)], uvs, side_texture.texture)
		#draw_texture(fit_side_texture_to_normal(side.normal), (side.start + side.end)/2)
	for corner in corners:
		corner.debug_draw(self)

