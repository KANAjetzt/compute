#[compute]
#version 460

struct PointMass {
	float id;
	float position_x;
	float position_y;
	float velocity_x;
	float velocity_y;
	float acceleration_x;
	float acceleration_y;
	float inverse_mass;
	float damping;
};

layout(local_size_x = 32) in;

layout(set = 0, binding = 0, std430) buffer restrict PointMasses {
	PointMass[] point_mass_values;
}
point_masses;

layout(push_constant, std430) uniform Params {
	vec2 applied_force;
	float res0;
	float res1;
}
params;

layout(r32f, set = 1, binding = 0) uniform restrict writeonly image2D output_image;

void main() {
	uint index = gl_GlobalInvocationID.x;

	// if(index > 180) return;

	PointMass point = point_masses.point_mass_values[index];

	if (index % 2 == 1 && index > 25 && index < 50){
		vec2 applied_acceleration = vec2(point.acceleration_x, point.acceleration_y) + params.applied_force * point.inverse_mass;
		point.acceleration_x += applied_acceleration.x;
		point.acceleration_y += applied_acceleration.y;
	}

	vec2 applied_gravity = vec2(0, 0.001) * point.inverse_mass; 
	point.acceleration_x += applied_gravity.x;
	point.acceleration_y += applied_gravity.y;
	point.velocity_x += point.acceleration_x;
	point.velocity_y += point.acceleration_y;
	point.position_x += point.velocity_x;
	point.position_y += point.velocity_y;

	point.acceleration_x = 0.0;
	point.acceleration_y = 0.0;

	vec2 applied_damping = vec2(point.velocity_x, point.velocity_y) * point.damping;

	point.velocity_x *= applied_damping.x;
	point.velocity_y *= applied_damping.y;

	point_masses.point_mass_values[index] = point;

	float fixed_point = 1.0;

	if(index % 2 == 1) {
		fixed_point = 0.0;
	}

	imageStore(output_image, ivec2(point.id, 0), vec4(point.position_x, point.position_y, fixed_point, 1.0));
}
