extends Node2D

var rd: RenderingDevice
var shader: RID
var pipeline: RID

var data_buffer_A: RID
var data_uniform_A: RDUniform

var data_buffer_B: RID
var data_uniform_B: RDUniform

var texture: RID
var texture_uniform: RDUniform

var uniform_set_data: RID
var uniform_set_texture: RID

var points: Array[PointMass]
var points_array := PackedFloat32Array()
var springs: Array[Spring]
var springs_array := PackedFloat32Array()
var data_array := PackedFloat32Array()

var rd_texture_spring_positions: Texture2DRD

@onready var spring_texture: ColorRect = %SpringTexture


class PointMass:
	var id: int
	var position: Vector2
	var velocity: Vector2
	var acceleration: Vector2
	var inverse_mass: float
	var damping := 1.00
	var parent: Node2D
	
	func _init(_id: int, _position: Vector2, _inverse_mass: float) -> void:
		id = _id
		position = _position
		inverse_mass = _inverse_mass
	
	func apply_force(force: Vector2) -> void:
		acceleration = acceleration + force * inverse_mass
	
	func get_as_array() -> PackedFloat32Array:
		var data := PackedFloat32Array()
		data.push_back(id)
		data.push_back(position.x)
		data.push_back(position.y)
		data.push_back(velocity.x)
		data.push_back(velocity.y)
		data.push_back(acceleration.x)
		data.push_back(acceleration.y)
		data.push_back(inverse_mass)
		data.push_back(damping)
		
		return data
	
	# Translates positions from 0-1 range to screen size pixels
	# TODO: This has to be moved to the GPU
	#func get_screen_position() -> Vector2:
		#return Vector2(
			#parent.get_viewport_rect().size.x * position.x,
			#parent.get_viewport_rect().size.y * position.y,
		#)
	
	# TODO: Move to GPU
	#func update() -> void:
		#acceleration += Vector2(0, 0.005) * inverse_mass
		#velocity = velocity + acceleration
		#position = position + velocity
		#acceleration = Vector2.ZERO
		#
		#if is_zero_approx(velocity.length_squared()):
			#velocity = Vector2.ZERO
		#
		#velocity = velocity * damping
		#damping = 1.00


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
	
	func get_as_array() -> PackedFloat32Array:
		var data := PackedFloat32Array()
		data.push_back(end_1.id)
		data.push_back(end_2.id)
		data.push_back(target_length)
		data.push_back(stiffness)
		data.push_back(damping)
		
		return data
	
	# TODO: Move to GPU
	#func update() -> void:
		#var x := end_1.position - end_2.position
		#var length := x.length()
		#var dv := Vector2.ZERO
		#var force := Vector2.ZERO
		#
		## Springs can only pull, not push
		#if length <= target_length:
			#return
		#
		#x = (x / length) * (length - target_length)
		#dv = end_2.velocity - end_1.velocity
		#force = stiffness * x - dv * damping
		#
		#end_1.apply_force(-force)
		#end_2.apply_force(force)


func _ready() -> void:
	points = [
		PointMass.new(0, Vector2(0.1, 0.5), 1.0),
		PointMass.new(1, Vector2(0.5, 0.3), 1.0),
		PointMass.new(2, Vector2(0.9, 0.5), 1.0),
		PointMass.new(3, Vector2(0.9, 0.1), 0.0),
		PointMass.new(4, Vector2(0.1, 0.1), 0.0),
	]
	springs = [
		Spring.new(points[0], points[1], 0.6, 0.02),
		Spring.new(points[1], points[2], 0.6, 0.02),
		Spring.new(points[2], points[3], 0.6, 0.02),
		Spring.new(points[3], points[4], 0.6, 0.02),
		Spring.new(points[4], points[0], 0.6, 0.02),
	]
	
	for point in points:
		points_array.append_array(point.get_as_array())
		
	for spring in springs:
		springs_array.append_array(spring.get_as_array())
		
	data_array.append_array(points_array)
	data_array.append_array(springs_array)
	
	
	if %SpringTexture.material:
		rd_texture_spring_positions = %SpringTexture.material.get_shader_parameter("point_positions_texture")
	
	RenderingServer.call_on_render_thread(_init_shader.bind())


func _process(_delta: float) -> void:
	if rd_texture_spring_positions:
		rd_texture_spring_positions.texture_rd_rid = texture
	
	if %SpringTexture.material:
		%SpringTexture.material.set_shader_parameter("aspect_ratio", get_viewport_rect().size.x / get_viewport_rect().size.y)
	
	RenderingServer.call_on_render_thread(_render_process.bind())


func _init_shader() -> void:
	rd = RenderingServer.get_rendering_device()
	
	# Setup Shader
	var shader_file: RDShaderFile = load("res://springs_gpu.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)
	
	# Setup Buffers
	# Data Buffer A
	var data_input_A := data_array.to_byte_array()
	data_buffer_A = rd.storage_buffer_create(data_input_A.size(), data_input_A)
	data_uniform_A = RDUniform.new()
	data_uniform_A.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	data_uniform_A.binding = 0
	data_uniform_A.add_id(data_buffer_A)
	
	# Data Buffer B
	var data_input_B := data_array.to_byte_array()
	data_buffer_B = rd.storage_buffer_create(data_input_B.size(), data_input_B)
	data_uniform_B = RDUniform.new()
	data_uniform_B.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	data_uniform_B.binding = 1
	data_uniform_B.add_id(data_buffer_B)
	
	# Create Texture
	var texture_format := RDTextureFormat.new()
	texture_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texture_format.width = 5
	texture_format.height = 1
	texture_format.depth = 1
	texture_format.array_layers = 1
	texture_format.mipmaps = 1
	texture_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	
	texture = rd.texture_create(texture_format, RDTextureView.new(), [])
	rd.texture_clear(texture, Color(0, 0, 0, 0), 0, 1, 0, 1)
	
	texture_uniform = RDUniform.new()
	texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	texture_uniform.binding = 0
	texture_uniform.add_id(texture)
	
	# Create Uniform Sets
	uniform_set_data = rd.uniform_set_create([data_uniform_A, data_uniform_B], shader, 0)
	uniform_set_texture = rd.uniform_set_create([texture_uniform], shader, 1)


func _render_process() -> void:
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	uniform_set_data = rd.uniform_set_create([data_uniform_A, data_uniform_B], shader, 0)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_data, 0)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_texture, 1)
	rd.compute_list_dispatch(compute_list, 1, 1, 1)
	rd.compute_list_end()
	
	data_uniform_A.binding = (data_uniform_A.binding + 1) % 2
	data_uniform_B.binding = (data_uniform_B.binding + 1) % 2
