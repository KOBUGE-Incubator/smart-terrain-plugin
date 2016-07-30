
# Namespace

class SideTexture:
	var normal
	var texture
	
	func _init(_texture, _normal):
		texture = _texture
		normal = _normal
	
	func get_length(thickness):
		return (texture.get_size().get_aspect() * thickness * normal).length()
	
	func is_better(other, target_normal):
		return other.normal.dot(target_normal) < normal.dot(target_normal)
	
	func transform_uvs(uvs):
		uvs = Vector2Array(uvs)
		for i in range(uvs.size()):
			uvs[i] = (uvs[i] - Vector2(.5,.5)).rotated(normal.angle()) + Vector2(.5,.5)
		
		if texture extends AtlasTexture:
			var real_size = texture.get_atlas().get_size()
			var real_region = texture.get_region()
			var region = Rect2(real_region.pos / real_size, real_region.size / real_size)
			for i in range(uvs.size()):
				uvs[i] = region.pos + uvs[i] * region.size
		return uvs


class CornerTexture:
	var normal
	var angle
	var texture
	
	func _init(_texture, _normal, _angle):
		texture = _texture
		normal = _normal
		angle = _angle
	
	func is_better(other, target_normal, target_angle):
		return other.normal.dot(target_normal) < normal.dot(target_normal) # FIXME


class Side:
	var start = Vector2()
	var end = Vector2()
	var normal = Vector2()
	var direction = Vector2()
	
	func _init(_start, _end):
		start = _start
		end = _end
		recalculate_normal()
	
	func get_length():
		return start.distance_to(end)
	
	func recalculate_normal():
		direction = (end - start).normalized()
		normal = (start - end).rotated(-PI/2).normalized() # FIXME: clockwise vs anticlockwise polygons
	
	func debug_draw(canvasitem):
		var middle = (start + end)/2
		canvasitem.draw_line(start, end, Color(1, 0, 0), 3)
		canvasitem.draw_line(middle, middle + normal*50, Color(0, 1, 0), 2)


class Corner:
	var before = Vector2()
	var position = Vector2()
	var after = Vector2()
	var normal = Vector2()
	var angle = 0
	var is_inset = false
	
	func _init(_position, _before=Vector2(), _after=Vector2()):
		position = _position
		before = _before
		after = _after
		recalculate_normal()
	
	func recalculate_normal(): # FIXME: clockwise vs anticlockwise polygons
		var pre_normal_1 = (position - before).normalized()
		var pre_normal_2 = (position - after).normalized()
		normal = (pre_normal_1.normalized() + pre_normal_2.normalized()).normalized()
		is_inset = Vector3(pre_normal_1.x, pre_normal_1.y, 0).cross(Vector3(pre_normal_2.x, pre_normal_2.y, 0)).z > 0
		
		if is_inset:
			normal = -normal
		
		# Couldn't make normal, try something else
		if normal.length_squared() < 0.9:
			normal = (before - after).rotated(-PI/2).normalized()
		
		angle = (position - before).angle_to(position - after)
		printt(is_inset,rad2deg(angle))
	
	func debug_draw(canvasitem):
		canvasitem.draw_circle(position, 5, Color(0, 0, 1))
		canvasitem.draw_line(position, position + normal*50, Color(0, 1, 0), 2)

static func cut_uvs(uvs, ratio, offset = Vector2()):
	uvs = Vector2Array(uvs)
	for i in range(uvs.size()):
		uvs[i] = uvs[i] * ratio + offset
	return uvs
