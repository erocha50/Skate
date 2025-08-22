shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.1;
uniform float fresnel_power : hint_range(0.0, 5.0) = 2.0;
uniform float color_shift_speed : hint_range(0.1, 3.0) = 1.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
    world_position = VERTEX;
    world_normal = NORMAL;
}

void fragment() {
    // Fresnel effect for bubble-like appearance
    vec3 view_dir = normalize(CAMERA_POSITION_WORLD - world_position);
    float fresnel = pow(1.0 - dot(world_normal, view_dir), fresnel_power);
    
    // RGB color cycling based on position and time
    float r = sin(world_position.x * 2.0 + TIME * color_shift_speed) * 0.5 + 0.5;
    float g = sin(world_position.z * 2.0 + TIME * color_shift_speed + 2.094) * 0.5 + 0.5;
    float b = sin(world_position.y * 2.0 + TIME * color_shift_speed + 4.188) * 0.5 + 0.5;
    
    vec3 bubble_color = vec3(r, g, b);
    
    ALBEDO = bubble_color;
    METALLIC = metallic;
    ROUGHNESS = roughness;
    ALPHA = fresnel * 0.7;
}