shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, depth_test_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform int filter_type : hint_range(0, 3) = 0;
uniform float severity : hint_range(0.0, 1.0) = 1.0;

const mat3 protanopia_1_0 = mat3(
    vec3(0.152, 1.053, -0.205),
    vec3(0.115, 0.786, 0.099),
    vec3(-0.004, -0.048, 1.052)
);

const mat3 deuteranopia_1_0 = mat3(
    vec3(0.367, 0.861, -0.228),
    vec3(0.280, 0.673, 0.047),
    vec3(-0.012, 0.043, 0.969)
);

const mat3 tritanopia_1_0 = mat3(
    vec3(1.256, -0.077, -0.179),
    vec3(-0.078, 0.931, 0.148),
    vec3(0.005, 0.691, 0.304)
);

const mat3 identity = mat3(
    vec3(1.0, 0.0, 0.0),
    vec3(0.0, 1.0, 0.0),
    vec3(0.0, 0.0, 1.0)
);

void fragment() {
    // Sample screen texture
    vec4 screen_color = texture(screen_texture, SCREEN_UV);
    vec3 color = screen_color.rgb;
    vec3 result = color;
    
    // Apply colorblind filter
    if (filter_type > 0) {
        mat3 cvd_matrix = identity;
        
        if (filter_type == 1) {
            cvd_matrix = protanopia_1_0;
        } else if (filter_type == 2) {
            cvd_matrix = deuteranopia_1_0;
        } else if (filter_type == 3) {
            cvd_matrix = tritanopia_1_0;
        }
        
        mat3 interpolated = mat3(
            mix(identity[0], cvd_matrix[0], severity),
            mix(identity[1], cvd_matrix[1], severity),
            mix(identity[2], cvd_matrix[2], severity)
        );
        
        result = interpolated * color;
    }
    
    // Output with full opacity
    ALBEDO = result;
    ALPHA = 1.0;
}