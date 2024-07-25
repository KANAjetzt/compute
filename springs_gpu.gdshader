shader_type canvas_item;


uniform sampler2D point_positions_texture: filter_nearest;
uniform float point_current: hint_range(0, 5, 1) = 0;
uniform float point_count: hint_range(1, 50000, 1) = 5;
uniform float point_size: hint_range(0.001, 0.1, 0.001);
uniform float scale: hint_range(0.01, 10.0, 0.01);
uniform float aspect_ratio;
uniform bool is_debug = false;
uniform bool is_draw_all = false;
uniform bool draw_background = true;

void fragment() {
	vec4 output_color = vec4(0.0, 0.0, 0.0, 0.1);
	
	if(draw_background){
		output_color = vec4(0.0, 0.0, 0.0, 1.0);
	}
	
	vec4 data_texture = texture(point_positions_texture, vec2( point_current / point_count, 0.5));
	vec2 point_position = data_texture.rg;
	float fixed_point = data_texture.b;
	
	if (is_debug){
		output_color = texture(point_positions_texture, UV);
	}
	
	if(is_draw_all){
		for(float i = point_current; i <= point_count; i++){
			vec4 data_texture = texture(point_positions_texture, vec2( i / point_count, 0.1));
			vec2 point_position = data_texture.rg;
			float fixed_point = data_texture.b;
		
			if(distance(vec2(UV.x * aspect_ratio, UV.y) * scale, point_position) < point_size){
				if(fixed_point == 1.0) {
					output_color.b = 1.0;
				} else {
					output_color.r = 1.0;
				}
				output_color.a = 1.0;
			}
		}
	}
	
	COLOR = output_color;
}
