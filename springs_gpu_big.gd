extends Node2D

@export var grid_size := Vector2(6, 6)

var rd: RenderingDevice
var shader: RID
var pipeline: RID

var data_springs_buffer: RID
var data_springs_uniform: RDUniform

var data_point_masses_buffer: RID
var data_point_masses_uniform: RDUniform

var texture: RID
var texture_uniform: RDUniform

var uniform_set_data: RID
var uniform_set_texture: RID

var applied_force: Vector2

var points: Array[PointMass]
var points_array := PackedFloat32Array()
var springs: Array[Spring]
var springs_array := PackedFloat32Array()
var data_array := PackedFloat32Array()

var rd_texture_spring_positions: Texture2DRD

@onready var spring_texture: ColorRect = %SpringTexture


class PointMass:
	var id: float
	var position: Vector2
	var velocity: Vector2
	var acceleration: Vector2
	var inverse_mass: float
	var damping := 1.00
	var parent: Node2D
	
	func _init(_id: float, _position: Vector2, _inverse_mass: float) -> void:
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


func _ready() -> void:
	
	# Create grid
	# - fixed Points (inverse mass 1.0) on the edge of the grid
	
	var point_count := 0
	var grid_spacing := Vector2(1 / grid_size.x, 1 / grid_size.y)
	
	for y in grid_size.y:
		for x in grid_size.x:
			# If on the edge of the grid, set a fixed point
			if x == 0 or y == 0 or x == grid_size.x - 1 or y == grid_size.y - 1:
				points.push_back(
					PointMass.new(float(point_count), Vector2(grid_spacing.x * x, grid_spacing.y * y), 0.0)
				)
			elif int(x) % 3 == 0 && int(y) % 3 == 0:
				points.push_back(
					PointMass.new(float(point_count), Vector2(grid_spacing.x * x, grid_spacing.y * y), 0.0)
				)
			else:
				points.push_back(
					PointMass.new(float(point_count), Vector2(grid_spacing.x * x, grid_spacing.y * y), 1.0)
				)
				
			point_count = point_count + 1
	
	for y in grid_size.y:
		for x in grid_size.x:
			# if it is not the first entry and not the last one connect the curent point with the last one
			if x > 0:
				# connect x axe
				var current_row_index := (y * grid_size.x) + x
				springs.push_back(
					Spring.new(points[current_row_index - 1], points[current_row_index], 0.6, 0.02),
				)
			if y > 0:
				var top_row_index := (y - 1) * grid_size.x + x
				# connect y axe
				springs.push_back(
					Spring.new(points[x], points[top_row_index], 0.6, 0.02),
				)
	
	print("Point size: %s" % points.size())
	
	for point in points:
		points_array.append_array(point.get_as_array())
		
	for spring in springs:
		springs_array.append_array(spring.get_as_array())
	
	print("Spring Size: %s" % springs.size())
	
	if %SpringTexture.material:
		rd_texture_spring_positions = %SpringTexture.material.get_shader_parameter("point_positions_texture")
	
	RenderingServer.call_on_render_thread(_init_shader.bind())


func _process(_delta: float) -> void:
	if Input.is_action_pressed("force"):
		applied_force = Vector2(0.0, -0.005)
	else:
		applied_force = Vector2(0.0, 0.0)
	
	if rd_texture_spring_positions:
		rd_texture_spring_positions.texture_rd_rid = texture
	
	if %SpringTexture.material:
		%SpringTexture.material.set_shader_parameter("aspect_ratio", get_viewport_rect().size.x / get_viewport_rect().size.y)
	
	RenderingServer.call_on_render_thread(_render_process.bind(applied_force))


func _init_shader() -> void:
	rd = RenderingServer.get_rendering_device()
	
	# Setup Shader
	var shader_file: RDShaderFile = load("res://springs_gpu_big.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)
	
	# Setup Buffers
	# Data Buffer Springs
	var data_springs_input := springs_array.to_byte_array()
	data_springs_buffer = rd.storage_buffer_create(data_springs_input.size(), data_springs_input)
	data_springs_uniform = RDUniform.new()
	data_springs_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	data_springs_uniform.binding = 0
	data_springs_uniform.add_id(data_springs_buffer)
	
	# Data Buffer Point Masses
	var data_point_masses_input := points_array.to_byte_array()
	data_point_masses_buffer = rd.storage_buffer_create(data_point_masses_input.size(), data_point_masses_input)
	data_point_masses_uniform = RDUniform.new()
	data_point_masses_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	data_point_masses_uniform.binding = 1
	data_point_masses_uniform.add_id(data_point_masses_buffer)
	
	# Create Texture
	var texture_format := RDTextureFormat.new()
	texture_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	#texture_format.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
	texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texture_format.width = grid_size.x * grid_size.y
	texture_format.height = 1
	texture_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	
	texture = rd.texture_create(texture_format, RDTextureView.new(), [])
	rd.texture_clear(texture, Color(0, 0, 0, 0), 0, 1, 0, 1)
	
	texture_uniform = RDUniform.new()
	texture_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	texture_uniform.binding = 0
	texture_uniform.add_id(texture)
	
	# Create Uniform Sets
	uniform_set_data = rd.uniform_set_create([data_springs_uniform, data_point_masses_uniform], shader, 0)
	uniform_set_texture = rd.uniform_set_create([texture_uniform], shader, 1)


func _render_process(_applied_force: Vector2) -> void:
	var push_constant := PackedFloat32Array()
	push_constant.push_back(_applied_force.x)
	push_constant.push_back(_applied_force.y)
	# Mind the gap!
	push_constant.push_back(0.0)
	push_constant.push_back(0.0)
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_data, 0)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set_texture, 1)
	rd.compute_list_set_push_constant(compute_list, push_constant.to_byte_array(), push_constant.size() * 4)
	rd.compute_list_dispatch(compute_list, 1, 1, 1)
	rd.compute_list_end()
