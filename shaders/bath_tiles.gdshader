shader_type canvas_item;
uniform bool wall = false;
varying vec2 world_position;
void vertex(){ world_position = (MODEL_MATRIX * vec4(VERTEX,0.0,1.0)).xy; }
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
    vec2 p = wall ? UV : vec2(world_position.x*0.5+world_position.y,world_position.y-world_position.x*0.5);
    vec2 cell = p / (wall ? vec2(48.0,24.0) : vec2(42.0));
    vec2 edge = min(fract(cell),1.0-fract(cell));
    float grout = 1.0-smoothstep(0.015,0.05,min(edge.x,edge.y));
    vec3 ceramic = mix(vec3(0.29,0.40,0.36),vec3(0.53,0.59,0.50),hash(floor(cell))*0.65);
    ceramic += (hash(floor(p*2.0))-0.5)*0.025;
    COLOR = vec4(mix(ceramic,vec3(0.14,0.18,0.15),grout),1.0);
}
