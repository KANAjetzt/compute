shader_type canvas_item;

uniform sampler2D point_positions_texture;
uniform float circle_radius = 0.05; // Adjust the radius as needed
uniform float line_thickness = 0.02; // Adjust the line thickness as needed
uniform bool show_debug = false;

// Function to calculate the distance from a point to a line segment
float distance_to_line_segment(vec2 p, vec2 v, vec2 w) {
    float l2 = dot(v - w, v - w); // Squared length of the segment
    if (l2 == 0.0) return distance(p, v); // v == w case
    float t = max(0.0, min(1.0, dot(p - v, w - v) / l2));
    vec2 projection = v + t * (w - v);
    return distance(p, projection);
}

void fragment() {
    vec2 uv = UV;
    vec4 texture_color = texture(point_positions_texture, uv);

    // Initialize the color as the background color
    vec4 circle_color = vec4(0.0, 0.0, 0.0, 0.0); // Black color, fully transparent

    // Array to store point positions (assuming 3 points for simplicity)
    vec3 point_pos[3];
    for (int i = 0; i < 3; i++) {
        point_pos[i] = texture(point_positions_texture, vec2(float(i) / 3.0, 0.5)).rgb;
    }

    // Draw circles at each point mass position
    for (int i = 0; i < 3; i++) {
        float dist_to_point = distance(uv, point_pos[i].xy);
        if (dist_to_point < circle_radius) {
            circle_color = vec4(1.0, 1.0, 1.0, 1.0); // White color for the circle
        }
    }

    // Draw lines between each point mass position
    for (int i = 0; i < 2; i++) {
        float dist_to_line = distance_to_line_segment(uv, point_pos[i].xy, point_pos[i + 1].xy);
        if (dist_to_line < line_thickness) {
            circle_color = vec4(1.0, 1.0, 1.0, 1.0); // White color for the line
        }
    }

	if(show_debug){
		COLOR = texture_color;
	} else {
		COLOR = circle_color;
	}

}
