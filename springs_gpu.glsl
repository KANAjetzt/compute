#[compute]
#version 450

struct PointMass {
	vec2 position;
	vec2 velocity;
	vec2 acceleration;
	float inverse_mass;
	float damping;
	int id;
	float res0;
};

struct Spring {
	int end_1;
	int end_2;
	float target_length;
	float stiffness;
	float damping;
};

layout(local_size_x = 5) in;

layout(set = 0, binding = 0, std430) buffer restrict Springs {
	Spring[] spring_values;
}
springs;

layout(set = 0, binding = 1, std430) buffer restrict PointMasses {
	PointMass[] point_mass_values;
}
point_masses;

layout(push_constant, std430) uniform Params {
	vec2 applied_force;
	float res0;
	float res1;
} params;

layout(r32f, set = 1, binding = 0)  uniform restrict writeonly image2D output_image;

void main() {
	uint index = gl_GlobalInvocationID.x;

	if(index > 5) return;

	Spring spring = springs.spring_values[index];

	PointMass end_1 = point_masses.point_mass_values[spring.end_1];
	PointMass end_2 = point_masses.point_mass_values[spring.end_2];

	vec2 x = end_1.position - end_2.position;
	float leng = length(x);
	vec2 dv = vec2(0.0, 0.0);
	vec2 force = vec2(0.0, 0.0);

	if (leng > spring.target_length){
		x = (x / leng) * (leng - spring.target_length);
		dv = end_2.velocity - end_1.velocity;
		force = spring.stiffness * x - dv * spring.damping;

		point_masses.point_mass_values[spring.end_1].acceleration += -force * end_1.inverse_mass;
		point_masses.point_mass_values[spring.end_2].acceleration += force * end_2.inverse_mass;
	}

	barrier();

	PointMass point = point_masses.point_mass_values[index];

	if (index == 2){
		point.acceleration += params.applied_force * point.inverse_mass;
	}

	point.acceleration += vec2(0, 0.00) * point.inverse_mass;
	point.velocity += point.acceleration;
	point.position += point.velocity;
	point.acceleration = vec2(0.0, 0.0);

	point.velocity *= point.damping;

	point_masses.point_mass_values[index] = point;

	imageStore(output_image, ivec2(index, 0), vec4(point.position, point.id, 1.0));
}