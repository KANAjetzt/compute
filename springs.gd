extends Node


var rd: RenderingDevice
var input_mass_points: PackedFloat32Array
var buffer_mass_points_previous := RID()
var buffer_mass_points_current := RID()
var uniform_set := RID()
var pipeline := RID()
var output_texture_rd := RID()
var uniform_springs := RDUniform.new()
var uniform_output_texture := RDUniform.new()
var shader := RID()

var tick_speed := 0.15
var tick := 0.0

var render_texture: Texture2DRD

var next_buffer: int = 0
var mass_points_buffer := [RID(), RID()]
var mass_points_sets := [RID(), RID()]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if %Texture.material:
		render_texture = %Texture.material.get_shader_parameter("point_positions_texture")

	RenderingServer.call_on_render_thread(init_shader.bind())


func init_shader() -> void:
	rd = RenderingServer.get_rendering_device()
	
	# Load GLSL shader
	var shader_file := load("res://springs.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	
	# Prepare our data. We use floats in the shader, so we need 32 bit.
	input_mass_points = PackedFloat32Array([
		0.1, 0.5, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0,
		0.5, 0.5, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0,
		0.9, 0.5, 0.0, 0.1, 0.0, 0.0, 0.0, 0.0,
	])
	var input_springs = PackedFloat32Array([
		0, 1, 0.1, 100.0,
		1, 2, 0.002, 100.0,
	])
	
	var input_mass_points_bytes := input_mass_points.to_byte_array()
	var input_springs_bytes := input_springs.to_byte_array()

	# Create a storage buffer that can hold our float values.
	# Each float has 4 bytes (32 bit) so 10 x 4 = 40 bytes
	mass_points_buffer[0] = rd.storage_buffer_create(input_mass_points_bytes.size(), input_mass_points_bytes)
	mass_points_buffer[1] = rd.storage_buffer_create(input_mass_points_bytes.size(), input_mass_points_bytes)
	var buffer_input_springs := rd.storage_buffer_create(input_springs_bytes.size(), input_springs_bytes)
	
	var uniform_mass_points_previous := RDUniform.new()
	uniform_mass_points_previous.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_mass_points_previous.binding = 0 # this needs to match the "binding" in our shader file
	uniform_mass_points_previous.add_id(mass_points_buffer[0])
	
	mass_points_sets[0] = rd.uniform_set_create([uniform_mass_points_previous], shader, 0)
	
	var uniform_mass_points_current := RDUniform.new()
	uniform_mass_points_current.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_mass_points_current.binding = 0 # this needs to match the "binding" in our shader file
	uniform_mass_points_current.add_id(mass_points_buffer[1])
	
	mass_points_sets[1] = rd.uniform_set_create([uniform_mass_points_current], shader, 1)
	
	# Create textures
	var texture_format: RDTextureFormat = RDTextureFormat.new()
	texture_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	texture_format.texture_type = RenderingDevice.TEXTURE_TYPE_2D
	texture_format.width = 3
	texture_format.height = 1
	texture_format.depth = 1
	texture_format.array_layers = 1
	texture_format.mipmaps = 1
	texture_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT + RenderingDevice.TEXTURE_USAGE_COLOR_ATTACHMENT_BIT + RenderingDevice.TEXTURE_USAGE_STORAGE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT + RenderingDevice.TEXTURE_USAGE_CAN_COPY_TO_BIT
	output_texture_rd = rd.texture_create(texture_format, RDTextureView.new(), [])
	# Make sure our texture is cleared.
	# rd.texture_clear(output_texture_rd, Color(0, 0, 0, 0), 0, 1, 0, 1)
	
	# Create a uniform to assign the buffer to the rendering device	
	uniform_springs.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	uniform_springs.binding = 0 # this needs to match the "binding" in our shader file
	uniform_springs.add_id(buffer_input_springs)
	
	uniform_output_texture.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform_output_texture.binding = 1
	uniform_output_texture.add_id(output_texture_rd)
	
	uniform_set = rd.uniform_set_create([uniform_springs, uniform_output_texture], shader, 2) # the last parameter (the 0) needs to match the "set" in our shader file
	
	# Create a compute pipeline
	pipeline = rd.compute_pipeline_create(shader)


func _process(delta: float) -> void:
	next_buffer = (next_buffer + 1) % 2
	
	# Update our texture to show our next result (we are about to create).
	# Note that `_initialize_compute_code` may not have run yet so the first
	# frame this my be an empty RID.
	if render_texture:
		render_texture.texture_rd_rid = output_texture_rd
	
	# While our render_process may run on the render thread it will run before our texture
	# is used and thus our next_rd will be populated with our next result.
	# It's probably overkill to sent texture_size and damp as parameters as these are static
	# but we sent add_wave_point as it may be modified while process runs in parallel.
	RenderingServer.call_on_render_thread(_render_process.bind(delta, next_buffer))
	
	# Read back the data from the buffer
	#var output_bytes := rd.buffer_get_data(buffer_mass_points)
	#var output := output_bytes.to_float32_array()
	#print("Input:  ", input_mass_points)
	#print("point_0: position: x:%s y:%s z:%s mass:%s velocity: x:%s y:%s z:%s" % [
		#str(output[0]),
		#str(output[1]),
		#str(output[2]),
		#str(output[3]),
		#str(output[4]),
		#str(output[5]),
		#str(output[6]),
	#])
	#print("point_1: position: x:%s y:%s z:%s mass:%s velocity: x:%s y:%s z:%s" % [
		#str(output[8]),
		#str(output[9]),
		#str(output[10]),
		#str(output[11]),
		#str(output[12]),
		#str(output[13]),
		#str(output[14]),
	#])
	#print("point_2: position: x:%s y:%s z:%s mass:%s velocity: x:%s y:%s z:%s" % [
		#str(output[16]),
		#str(output[17]),
		#str(output[18]),
		#str(output[19]),
		#str(output[20]),
		#str(output[21]),
		#str(output[22]),
	#])


func _render_process(delta_time: float, _next_buffer: int) -> void:
	# Create push constant
	var push_constant := PackedFloat32Array([delta_time, 0.0, 0.0, 0.0])
	var push_constant_bytes := push_constant.to_byte_array()
	
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, mass_points_sets[_next_buffer], 0)
	rd.compute_list_bind_uniform_set(compute_list, mass_points_sets[_next_buffer - 1], 1)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 2)
	rd.compute_list_set_push_constant(compute_list, push_constant_bytes, push_constant_bytes.size())
	rd.compute_list_dispatch(compute_list, 1, 1, 1)
	rd.compute_list_end()
