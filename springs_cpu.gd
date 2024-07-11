extends Node2D


var points: Array[PointMass]
var springs: Array[Spring]

@onready var node_points: Node2D = %Points
@onready var line_2d: Line2D = $Line2D


class PointMass:
	var id: int
	var position: Vector2
	var velocity: Vector2
	var acceleration: Vector2
	var inverse_mass: float
	var damping := 1.00
	var point_vis := preload("res://point.tscn")
	var point_vis_instance: Sprite2D
	
	func _init(_id: int, _position: Vector2, _inverse_mass: float, _parent: Node) -> void:
		id = _id
		position = _position
		inverse_mass = _inverse_mass
		
		point_vis_instance = point_vis.instantiate()
		_parent.add_child(point_vis_instance)
	
	func apply_force(force: Vector2) -> void:
		acceleration = acceleration + force * inverse_mass
	
	# Translates positions from 0-1 range to screen size pixels
	func get_screen_position() -> Vector2:
		return Vector2(
			point_vis_instance.get_viewport_rect().size.x * position.x,
			point_vis_instance.get_viewport_rect().size.y * position.y,
		)
		
	
	func update() -> void:
		acceleration += Vector2(0, 0.005) * inverse_mass
		velocity = velocity + acceleration
		position = position + velocity
		acceleration = Vector2.ZERO
		
		if is_zero_approx(velocity.length_squared()):
			velocity = Vector2.ZERO
		
		velocity = velocity * damping
		damping = 1.00
		
		point_vis_instance.position = Vector2(
			get_screen_position().x,
			get_screen_position().y,
		)


class Spring:
	var end_1: PointMass
	var end_2: PointMass
	var target_length: float
	var stiffness: float
	var damping: float
	
	func _init(_end_1: PointMass, _end_2: PointMass, _stiffness: float, _damping: float) -> void:
		end_1 = _end_1
		end_2 = _end_2
		stiffness = _stiffness
		damping = _damping
		# When we create a spring, we set the natural length of the spring 
		# to be just slightly less than the distance between the two end points. 
		# This keeps the grid taut even when at rest and improves the appearance somewhat.
		target_length = _end_1.position.distance_to(end_2.position) * 0.95
	
	func update() -> void:
		var x := end_1.position - end_2.position
		var length := x.length()
		var dv := Vector2.ZERO
		var force := Vector2.ZERO
		
		# Springs can only pull, not push
		if length <= target_length:
			return
		
		x = (x / length) * (length - target_length)
		dv = end_2.velocity - end_1.velocity
		force = stiffness * x - dv * damping
		
		end_1.apply_force(-force)
		end_2.apply_force(force)


func _ready() -> void:
	points = [
		PointMass.new(0, Vector2(0.1, 0.5), 1.0, node_points),
		PointMass.new(1, Vector2(0.5, 0.3), 1.0, node_points),
		PointMass.new(2, Vector2(0.9, 0.5), 1.0, node_points),
		PointMass.new(3, Vector2(0.9, 0.1), 0.0, node_points),
		PointMass.new(4, Vector2(0.1, 0.1), 0.0, node_points),
	]
	springs = [
		Spring.new(points[0], points[1], 0.6, 0.02),
		Spring.new(points[1], points[2], 0.6, 0.02),
		Spring.new(points[2], points[3], 0.6, 0.02),
		Spring.new(points[3], points[4], 0.6, 0.02),
		Spring.new(points[4], points[0], 0.6, 0.02),
	]
	
	for point in points:
		line_2d.add_point(point.get_screen_position())


func _process(delta: float) -> void:
	if Input.is_action_pressed("force"):
		points[0].apply_force(Vector2(0.01, 0.0))
	
	for spring in springs:
		spring.update()
	
	for i in points.size():
		var point := points[i]
		point.update()
		line_2d.set_point_position(i, point.get_screen_position())


#func _on_timer_timeout() -> void:
	#points[0].apply_force(Vector2(0.1, 0.0))
	#points[0].apply_force(Vector2(0.0, 0.5))
