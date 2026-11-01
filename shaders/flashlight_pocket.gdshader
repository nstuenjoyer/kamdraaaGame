shader_type canvas_item;
uniform bool clipping = false;
uniform float pocket_y = 0.0;
varying float world_y;
varying vec4 tint;
void vertex() {
    world_y = (MODEL_MATRIX*vec4(VERTEX,0.0,1.0)).y;
    tint = COLOR;
}
void fragment() {
    if (clipping && world_y > pocket_y) { discard; }
    COLOR = texture(TEXTURE,UV)*tint;
}
