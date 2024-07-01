#[compute]
#version 450

layout(local_size_x = 2, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) buffer MassPointsPrevious {
    vec4 positions[3];  // positions.xyz = position, positions.w = mass
		vec4 velocities[3];  // velocities.xyz = velocity
}
massPointsPrevious;

layout(set = 1, binding = 0, std430) buffer MassPointsCurrent {
    vec4 positions[3];  // positions.xyz = position, positions.w = mass
		vec4 velocities[3];  // velocities.xyz = velocity
}
massPointsCurrent;

layout(set = 2, binding = 0, std430) buffer Springs {
    ivec2 connections[2]; // connections.x = pointA, connections.y = pointB
    float restLengths[2];
    float stiffnesses[2];
};

// Output texture for storing positions
layout(r32f, set = 2, binding = 1) uniform restrict writeonly image2D output_image;

// Push constants for grid size
layout(push_constant, std430) uniform Params {
		float deltaTime;
    float res1; // not used
    float res2; // not used
		float res3; // not used
};

void main() {
		vec3 gravity = vec3(0.0, -9.81, 0.0);
		// vec3 gravity = vec3(0.0, 0.0, 0.0);

    uint id = gl_GlobalInvocationID.x;

    // Get spring data
    int pointA = connections[id].x;
    int pointB = connections[id].y;
    float restLength = restLengths[id];
    float stiffness = stiffnesses[id];

    // Get positions and velocities
    vec3 posA = massPointsCurrent.positions[pointA].xyz;
    vec3 posB = massPointsCurrent.positions[pointB].xyz;
    vec3 velA = massPointsCurrent.velocities[pointA].xyz;
    vec3 velB = massPointsCurrent.velocities[pointB].xyz;
		float massA = massPointsCurrent.positions[pointA].w; // mass stored in positions.w
		float massB = massPointsCurrent.positions[pointB].w;

		float targetLength = distance(posA, posB) * 0.95;

    // Compute spring force
		vec3 x = posA - posB;
    float leng = length(x);

		// These springs can only pull, not push
		if(leng <= targetLength){
			// do nothing
			return;
		}

		x = (x / leng) * (leng / targetLength);
		vec3 dv = velB - velA;
		vec3 force = stiffness * x - dv * 0.99;

    // Apply forces to velocities
		vec3 accelA = vec3(0.0);
		vec3 accelB = vec3(0.0);
    accelA += (force * -1.0) * massA;  
    accelB += force * massB;

    // Update velocities with damping
		// massPointsCurrent.velocities[pointA].xyz = vec3(1.0, 1.0, 1.0);
		// massPointsCurrent.velocities[pointB].xyz = vec3(1.0, 1.0, 1.0);
    massPointsCurrent.velocities[pointA].xyz += accelA;
    massPointsCurrent.velocities[pointB].xyz += accelB;
    
		massPointsCurrent.velocities[pointA].xyz *= 0.99;
    massPointsCurrent.velocities[pointB].xyz *= 0.99;

    // Update positions
		// positions[pointA].xyz = vec3(100.0, 100.0, 100.0);
		// positions[pointB].xyz = vec3(100.0, 100.0, 100.0);
    massPointsCurrent.positions[pointA].xyz += massPointsCurrent.velocities[pointA].xyz;
    massPointsCurrent.positions[pointB].xyz += massPointsCurrent.velocities[pointA].xyz;

		// Store position data to texture
		// vec4 color = vec4(massPointsCurrent.positions[pointA].x, massPointsCurrent.positions[pointA].y, 0.0, 1.0);
		// ivec2 texel = ivec2(pointA, 0);
		// imageStore(output_image, texel, color);

		// color = vec4(massPointsCurrent.positions[pointB].x, massPointsCurrent.positions[pointB].y, 0.0, 1.0);
		// texel = ivec2(pointB, 0);
		// imageStore(output_image, texel, color);

		vec4 color = vec4(leng, 0.0, 0.0, 1.0);
		ivec2 texel = ivec2(id, 0);
		imageStore(output_image, texel, color);
}
