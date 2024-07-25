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

struct Spring {
	float end_1;
	float end_2;
	float target_length;
	float stiffness;
	float damping;
};

layout(local_size_x = 32) in;

layout(set = 0, binding = 0, std430) buffer restrict PointMasses {
	PointMass[] point_mass_values;
}
point_masses;

layout(set = 0, binding = 1, std430) buffer restrict Springs {
	Spring[] spring_values;
}
springs;

layout(push_constant, std430) uniform Params {
	vec2 applied_force;
	float res0;
	float res1;
}
params;

void main() {
	uint index = gl_GlobalInvocationID.x;

	// if(index > 180) return;

	Spring spring = springs.spring_values[index];

	PointMass end_1 = point_masses.point_mass_values[int(spring.end_1)];
	PointMass end_2 = point_masses.point_mass_values[int(spring.end_2)];

	vec2 end_1_position = vec2(end_1.position_x, end_1.position_y);
	vec2 end_2_position = vec2(end_2.position_x, end_2.position_y);
	vec2 end_1_velocity = vec2(end_1.velocity_x, end_1.velocity_y);
	vec2 end_2_velocity = vec2(end_2.velocity_x, end_2.velocity_y);

	vec2 x = end_1_position - end_2_position;
	float leng = length(x);
	vec2 dv = vec2(0.0, 0.0);
	vec2 force = vec2(0.0, 0.0);

	if (leng > spring.target_length) {
		x = (x / leng) * (leng - spring.target_length);
		dv = end_2_velocity - end_1_velocity;
		force = spring.stiffness * x - dv * spring.damping;

		vec2 end_1_acceleration = -force * end_1.inverse_mass;
		vec2 end_2_acceleration = force * end_2.inverse_mass;

		point_masses.point_mass_values[int(spring.end_1)].acceleration_x += end_1_acceleration.x;
		point_masses.point_mass_values[int(spring.end_1)].acceleration_y += end_1_acceleration.y;
		point_masses.point_mass_values[int(spring.end_2)].acceleration_x += end_2_acceleration.x;
		point_masses.point_mass_values[int(spring.end_2)].acceleration_y += end_2_acceleration.y;
	}
}
