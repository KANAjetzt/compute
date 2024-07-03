#[compute]
#version 450

struct PointMass {
	float id;
	vec2 position;
	vec2 velocity;
	vec2 acceleration;
	float inverse_mass;
	float damping;
};

struct Spring {
	int end_1;
	int end_2;
	float target_length;
	float stiffness;
	float damping;
};

layout(local_size_x = 5) in;

layout(set = 0, binding = 0, std430) buffer restrict Data {
	PointMass point_masses[5];
	Spring springs[5];
}
data;

layout(push_constant, std430) uniform Params {
	vec2 applied_force;
	float res0;
	float res1;
}
params;

layout(r32f, set = 1, binding = 0) uniform restrict writeonly image2D output_image;

void main() {
	uint index = gl_GlobalInvocationID.x;

	// Apply spring forces
	if (index < 5) {  // Assuming you have 5 springs; adjust accordingly
		Spring spring = data.springs[index];

		PointMass end_1 = data.point_masses[spring.end_1];
		PointMass end_2 = data.point_masses[spring.end_2];

		vec2 x = end_1.position - end_2.position;
		float leng = length(x);
		vec2 dv = vec2(0.0, 0.0);
		vec2 force = vec2(0.0, 0.0);

		if (leng > spring.target_length) {
			x = (x / leng) * (leng - spring.target_length);
			dv = end_2.velocity - end_1.velocity;
			force = spring.stiffness * x - dv * spring.damping;

			data.point_masses[spring.end_1].acceleration += -force * end_1.inverse_mass;
			data.point_masses[spring.end_2].acceleration += force * end_2.inverse_mass;
		}
	}

	// Synchronize to ensure all forces are applied before updating positions
	barrier();

	// Update point masses
	if (index < 5) {  // Assuming you have 5 point masses; adjust accordingly
		PointMass point = data.point_masses[index];

		// Apply external force if needed
		if (index == 0) {
				point.acceleration += params.applied_force * point.inverse_mass;
		}

		// Apply gravity
		point.acceleration += vec2(0, 0.05) * point.inverse_mass;

		// Symplectic Euler integration
		point.velocity += point.acceleration;
		point.position += point.velocity;
		point.acceleration = vec2(0.0, 0.0);

		// Apply damping
		point.velocity *= point.damping;

		// Update point mass data
		data.point_masses[index] = point;

		// Update position in texture for rendering
		imageStore(output_image, ivec2(int(point.id), 0), vec4(point.position, 0.0, 1.0));
	}
}
