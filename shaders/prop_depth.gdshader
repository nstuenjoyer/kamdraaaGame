shader_type canvas_item;
uniform vec2 footprint[4];
uniform float lower_depth;
uniform float upper_depth;
uniform float prop_height = 40.0;
varying vec2 world_point;
void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).xy; }
void fragment() {
    COLOR.a *= smoothstep(0.12,0.65,COLOR.a);
    float first=100000.0;
    float last=-100000.0;
    for(int i=0;i<4;i++) {
        vec2 a=footprint[i]; vec2 b=footprint[(i+1)%4];
        if(abs(b.x-a.x)>0.001 && world_point.x>=min(a.x,b.x)-0.1 && world_point.x<=max(a.x,b.x)+0.1) {
            float h=mix(a.y,b.y,(world_point.x-a.x)/(b.x-a.x));
            first=min(first,h); last=max(last,h);
        }
    }
    float depth=clamp(world_point.y+prop_height,first,last);
    if(depth<lower_depth || depth>=upper_depth) { discard; }
}
