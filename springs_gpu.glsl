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

layout(local_size_x = 5, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) buffer restrict Data_A {
	PointMass point_masses[5];
	Spring springs[5];
}
data_A;

layout(set = 0, binding = 1, std430) buffer restrict Data_B {
	PointMass point_masses[5];
	Spring springs[5];
}
data_B;

layout(r32f, set = 1, binding = 0)  uniform restrict writeonly image2D output_image;

void main() {
	uint index = gl_GlobalInvocationID.x;

	Spring spring_a = data_A.springs[index];
	Spring spring_b = data_B.springs[index];

	PointMass end_1_a = data_A.point_masses[spring_a.end_1];
	PointMass end_2_a = data_A.point_masses[spring_a.end_2];

	PointMass end_1_b = data_B.point_masses[spring_b.end_1];
	PointMass end_2_b = data_B.point_masses[spring_b.end_2];

	vec2 x = end_1_a.position - end_2_a.position;
	float leng = length(x);
	vec2 dv = vec2(0.0, 0.0);
	vec2 force = vec2(0.0, 0.0);

	if (leng > spring_a.target_length){
		x = (x / leng) * (leng - spring_a.target_length);
		dv = end_2_a.velocity - end_1_a.velocity;
		force = spring_a.stiffness * x - dv * spring_a.damping;

		end_1_b.acceleration += -force * end_1_a.inverse_mass;
		end_2_b.acceleration += force * end_2_a.inverse_mass;
	}

	PointMass point_a = data_A.point_masses[index];
	PointMass point_b = data_B.point_masses[index];


	point_b.acceleration += vec2(0, 0.05) * point_a.inverse_mass;
	point_b.velocity += point_a.acceleration;
	point_b.position += point_a.velocity;
	point_b.acceleration = vec2(0.0, 0.0);


	point_b.velocity *= point_a.damping;

	imageStore(output_image, ivec2(index, 0), vec4(point_b.position, 0.0, 1.0));
}