shader_type canvas_item;
uniform sampler2D grain_texture : repeat_enable, filter_linear;
varying vec2 world_point;
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy;}
void fragment(){
    vec3 grain=texture(grain_texture,world_point*0.006).rgb;
    float value=clamp(dot(grain,vec3(0.3,0.59,0.11))*2.4,0.42,1.3);
    COLOR.rgb*=mix(0.84,1.15,value);
}
