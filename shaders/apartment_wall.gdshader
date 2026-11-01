shader_type canvas_item;
render_mode unshaded;
uniform vec2 torch_position;
uniform vec2 player_position;
uniform vec2 torch_emission_position;
uniform float torch_height = 58.0;
uniform vec2 torch_direction = vec2(1.0, 0.0);
uniform bool torch_on = false;
uniform bool power_on = false;
uniform vec4 barriers[256];
uniform float barrier_heights[256];
uniform int barrier_count = 0;
uniform int own_barrier = -1;
uniform float fade = 1.0;
uniform vec2 wall_start;
uniform vec2 wall_end;
varying vec2 floor_position;
varying float surface_height;
varying vec2 wall_position;
uniform bool bathroom_tiles = false;

void vertex() {
    vec2 position_in_world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
    wall_position = position_in_world;
    float along = (position_in_world.x-wall_start.x)/(wall_end.x-wall_start.x);
    floor_position = mix(wall_start, wall_end, along);
    surface_height = floor_position.y-position_in_world.y;
}

float cross2(vec2 a, vec2 b) { return a.x*b.y-a.y*b.x; }
void fragment() {
    vec2 ray = floor_position - torch_position;
    vec2 projected_ray = wall_position - torch_emission_position;
    float height_difference = surface_height - torch_height;
    float distance_to_light = length(vec3(ray, height_difference));
    float facing = dot(normalize(projected_ray + vec2(0.001)), torch_direction);
    // A near wall receives the spot at hand height, not a vertical stripe from
    // the floor. The spot expands naturally as the wall gets farther away.
    float vertical_spread = 1.0-smoothstep(0.12, 0.80, abs(height_difference)/max(35.0,length(ray)));
    float beam = smoothstep(0.72, 0.96, facing) * vertical_spread * pow(clamp(1.0-distance_to_light/540.0, 0.0, 1.0), 0.65);
    float aura = pow(clamp(1.0-distance_to_light/150.0, 0.0, 1.0), 1.5)*0.45;
    float visible = 1.0;
    if (torch_on && beam+aura > 0.001) {
        for (int i=0; i<256; i++) {
            if (i>=barrier_count) { break; }
            if (i==own_barrier) { continue; }
            vec2 edge = barriers[i].zw-barriers[i].xy;
            float denom = cross2(ray, edge);
            if (abs(denom)>0.001) {
                vec2 offset = barriers[i].xy-torch_position;
                float t = cross2(offset, edge)/denom;
                float u = cross2(offset, ray)/denom;
                if (t>0.015 && t<0.99 && u>=0.0 && u<=1.0) {
                    float height_at_crossing=mix(torch_height,surface_height,t);
                    if (barrier_heights[i]>0.0 && height_at_crossing>barrier_heights[i]+0.5) { continue; }
                    visible=0.0; break;
                }
            }
        }
    }
    float light = power_on ? 0.95 : 0.37;
    if (torch_on) { light += (beam*0.85+aura*0.6)*visible; }
    float grain=fract(sin(dot(vec2(floor_position.x*0.5,surface_height*2.0),vec2(12.9898,78.233)))*43758.5453);
    vec3 paint = COLOR.rgb*vec3(1.06,1.01,0.9)*(0.94+grain*0.09);
    float dado=1.0-smoothstep(20.0,24.0,surface_height);
    paint=mix(paint,paint*vec3(0.69,0.70,0.65),dado*0.65);
    if (bathroom_tiles) {
        vec2 tile = vec2(length(floor_position-wall_start),surface_height) / vec2(42.0,22.0);
        // Horizontal world coordinate keeps joints continuous across wall segments.
        tile.x = floor_position.x / 38.0;
        vec2 edge = min(fract(tile),1.0-fract(tile));
        float grout = 1.0-smoothstep(0.02,0.06,min(edge.x,edge.y));
        paint = mix(vec3(0.48,0.58,0.51)*(0.96+grain*0.05),vec3(0.20,0.26,0.22),grout);
    }
    float circle = smoothstep(45.0,110.0,length(wall_position-(player_position-vec2(0.0,58.0))));
    float foreground = smoothstep(-12.0,8.0,floor_position.y-player_position.y);
    float visibility_alpha = mix(1.0,mix(0.08,1.0,circle),foreground);
    COLOR = vec4(paint*light, COLOR.a*visibility_alpha);
}
