shader_type canvas_item;
uniform vec2 old_hand;
uniform vec2 shoulder;
uniform float body_x = 80.0;
uniform float strength = 0.0;
varying vec4 tint;
void vertex(){tint=COLOR;}
float segment_distance(vec2 p,vec2 a,vec2 b){vec2 ab=b-a;return length(p-a-ab*clamp(dot(p-a,ab)/max(dot(ab,ab),0.01),0.0,1.0));}
void fragment(){
    vec2 dimensions=vec2(textureSize(TEXTURE,0));
    vec2 cell=mod(UV*dimensions,vec2(160.0,256.0));
    vec4 original=texture(TEXTURE,UV);
    vec2 elbow=mix(shoulder,old_hand,0.48);
    float mask=1.0-smoothstep(5.5,8.0,segment_distance(cell,elbow,old_hand));
    mask*=smoothstep(shoulder.y+7.0,shoulder.y+12.0,cell.y);
    float inward=sign(body_x-old_hand.x)*12.0;
    vec2 repaired=clamp(cell+vec2(inward,0.0),vec2(0.5),vec2(159.5,255.5));
    vec4 cloth=texture(TEXTURE,UV+(repaired-cell)/dimensions);
    COLOR=mix(original,cloth,mask*strength)*tint;
}
