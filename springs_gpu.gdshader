shader_type canvas_item;


uniform sampler2D point_positions_texture;
uniform float point_current: hint_range(1, 5, 1) = 1;
uniform float point_count: hint_range(1, 5, 1) = 5;
uniform float point_size: hint_range(0.1, 10.0, 0.01);
uniform float scale: hint_range(0.01, 10.0, 0.01);
uniform float aspect_ratio;
uniform bool is_debug = false;
uniform bool is_draw_all = false;

void fragment() {
	//vec4 texture_color = texture(point_positions_texture, vec2(point_current / point_count, 1.0));
	
	vec4 output_color = vec4(0.0, 0.0, 0.0, 1.0);
	
	vec2 point_position = texture(point_positions_texture, vec2( point_current / point_count, 0.5)).xy;
	
	if(distance(vec2(UV.x * aspect_ratio, UV.y) * scale, point_position) < point_size){
		output_color.b = 1.0;
	}
	
	if (is_debug){
		//output_color += texture(point_positions_texture, vec2(point_current / point_count, 1.0));
		output_color.rg = point_position;
	}
	
	if(is_draw_all){
		for(float i = point_current; i <= point_count; i++){
			vec2 point_position = texture(point_positions_texture, vec2( i / point_count, 0.5)).xy;
		
			if(distance(vec2(UV.x * aspect_ratio, UV.y) * scale, point_position) < point_size){
				output_color.b = 1.0;
			}
		}
	}
	
	COLOR = output_color;
}
