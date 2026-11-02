shader_type canvas_item;
uniform vec2 old_hand;
uniform vec2 shoulder;
uniform float body_x = 80.0;
uniform float strength = 0.0;
uniform float clarity_amount : hint_range(0.0, 1.5) = 0.0;
varying vec4 tint;
void vertex(){tint=COLOR;}
float segment_distance(vec2 p,vec2 a,vec2 b){vec2 ab=b-a;return length(p-a-ab*clamp(dot(p-a,ab)/max(dot(ab,ab),0.01),0.0,1.0));}
vec4 sharpen(vec4 c,vec4 l,vec4 r,vec4 t,vec4 b){
    vec3 neighbours=(mix(c.rgb,l.rgb,l.a)+mix(c.rgb,r.rgb,r.a)+mix(c.rgb,t.rgb,t.a)+mix(c.rgb,b.rgb,b.a))*0.25;
    return vec4(clamp(c.rgb+(c.rgb-neighbours)*clarity_amount,vec3(0.0),vec3(1.0)),c.a);
}
void fragment(){
    vec2 dimensions=vec2(textureSize(TEXTURE,0));
    vec2 p=UV*dimensions;
    vec2 cell=mod(p,vec2(160.0,256.0));
    vec2 cell_min=floor(p/vec2(160.0,256.0))*vec2(160.0,256.0)+vec2(0.5);
    vec2 cell_max=cell_min+vec2(159.0,255.0);
    vec4 original=sharpen(texture(TEXTURE,UV),
        texture(TEXTURE,clamp(p+vec2(-1.0,0.0),cell_min,cell_max)/dimensions),
        texture(TEXTURE,clamp(p+vec2(1.0,0.0),cell_min,cell_max)/dimensions),
        texture(TEXTURE,clamp(p+vec2(0.0,-1.0),cell_min,cell_max)/dimensions),
        texture(TEXTURE,clamp(p+vec2(0.0,1.0),cell_min,cell_max)/dimensions));
    vec2 elbow=mix(shoulder,old_hand,0.48);
    float mask=1.0-smoothstep(5.5,8.0,segment_distance(cell,elbow,old_hand));
    mask*=smoothstep(shoulder.y+7.0,shoulder.y+12.0,cell.y);
    float inward=sign(body_x-old_hand.x)*12.0;
    vec2 repaired=clamp(cell+vec2(inward,0.0),vec2(0.5),vec2(159.5,255.5));
    vec2 cloth_p=p+(repaired-cell);
    vec4 cloth=sharpen(texture(TEXTURE,cloth_p/dimensions),
        texture(TEXTURE,clamp(cloth_p+vec2(-1.0,0.0),cell_min,cell_max)/dimensions),
        texture(TEXTURE,clamp(cloth_p+vec2(1.0,0.0),cell_min,cell_max)/dimensions),
        texture(TEXTURE,clamp(cloth_p+vec2(0.0,-1.0),cell_min,cell_max)/dimensions),
        texture(TEXTURE,clamp(cloth_p+vec2(0.0,1.0),cell_min,cell_max)/dimensions));
    COLOR=mix(original,cloth,mask*strength)*tint;
}
