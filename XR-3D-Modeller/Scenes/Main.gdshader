shader_type spatial;
render_mode unshaded, cull_disabled;

uniform vec4 base_color : source_color = vec4(0.902, 0.902, 0.922, 1.0);
uniform vec4 major_line_color : source_color = vec4(0.4, 0.4, 0.45, 1.0);
uniform float major_grid_size : hint_range(0.1, 10.0) = 1.0;
uniform float major_line_width : hint_range(0.001, 0.05) = 0.01;

void vertex() {
}

void fragment() {
	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 world_pos = vec2(world.x, world.z);

	// Major grid lines only
	vec2 major_coord = fract(world_pos / major_grid_size);
	float major_line_x = step(1.0 - (major_line_width / major_grid_size), major_coord.x) + step(major_coord.x, major_line_width / major_grid_size);
	float major_line_z = step(1.0 - (major_line_width / major_grid_size), major_coord.y) + step(major_coord.y, major_line_width / major_grid_size);
	float major_line = clamp(major_line_x + major_line_z, 0.0, 1.0);

	// Combine
	vec4 color = base_color;
	color = mix(color, major_line_color, major_line);

	ALBEDO = color.rgb;
	ALPHA = 1.0;
}