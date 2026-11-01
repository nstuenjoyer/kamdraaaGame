"""Register generated Dasha drawings. Cropping, alpha cleanup and uniform nearest
resampling only: all articulated poses come from imagegen, never deformation.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import json
import math
ROOT=Path(__file__).resolve().parents[2]
DEST=ROOT/'assets/sprites/dasha_animation'
PREVIEW=ROOT/'AI/review/images/animation'
PREVIEW.mkdir(parents=True,exist_ok=True)

def clean(im):
    arr=np.array(im.convert('RGBA'));arr[arr[:,:,3]<16]=0
    return Image.fromarray(arr)

def components(im):
    mask=np.asarray(im)[:,:,3]>128
    h,w=mask.shape;seen=np.zeros_like(mask);boxes=[]
    for y,x in zip(*np.where(mask)):
        if seen[y,x]:continue
        stack=[(y,x)];seen[y,x]=1;xs=[];ys=[]
        while stack:
            yy,xx=stack.pop();xs.append(xx);ys.append(yy)
            for dy,dx in ((-1,0),(1,0),(0,-1),(0,1)):
                ny,nx=yy+dy,xx+dx
                if 0<=ny<h and 0<=nx<w and mask[ny,nx] and not seen[ny,nx]:
                    seen[ny,nx]=1;stack.append((ny,nx))
        if len(xs)>500:boxes.append(tuple(map(int,(min(xs),min(ys),max(xs)+1,max(ys)+1))))
    return sorted(boxes,key=lambda b:b[1])

def rows(im,n):
    bs=components(im);assert len(bs)==n*8,(len(bs),n*8)
    return [sorted(bs[i:i+8],key=lambda b:b[0]) for i in range(0,len(bs),8)]

def put(atlas,row,col,source,box,scale,lift=0):
    crop=source.crop(box)
    size=(round(crop.width*scale),round(crop.height*scale))
    crop=crop.resize(size,Image.Resampling.NEAREST)
    alpha=np.asarray(crop)[:,:,3]>128
    ys,xs=np.where(alpha)
    contact=xs[ys>=ys.max()-max(2,round(size[1]*.025))]
    anchor=(int(contact.min())+int(contact.max()))*.5
    x=col*160+80-round(anchor); x=max(col*160,min(x,(col+1)*160-size[0])); y=row*256+244-size[1]-lift
    assert x>=col*160 and x+size[0]<=(col+1)*160,(row,col,size,x)
    atlas.alpha_composite(crop,(x,y))
    return {'row':row,'frame':col,'source_box':box,'scale':scale,'bounds':[x-col*160,y-row*256,*size],'foot_lift':lift,'foot_anchor':anchor}

main=clean(Image.open(DEST/'redraw_source.png'))
crouch=clean(Image.open(DEST/'redraw_crouch_source.png'))
idle=clean(Image.open(DEST/'redraw_idle_source.png'))
stand_idle=clean(Image.open(DEST/'redraw_stand_idle_source.png'))
mr=rows(main,8);cr=rows(crouch,2);ir=rows(idle,4);sr=rows(stand_idle,2)
atlas=Image.new('RGBA',(1280,2048));records=[]
for row in range(8):
    if row in [2,6]:
        image=crouch;selected=cr[0 if row==2 else 1]
        # A front-looking generated back-frame is deliberately rejected.
        order=list(range(8)) if row==2 else [4,1,2,3,7,5,6,7]
        selected=[selected[i] for i in order]
        scale=126/max(b[3]-b[1] for b in selected)
    else:
        image=main;selected=mr[row]
        scale=200/max(b[3]-b[1] for b in selected)
    for col,b in enumerate(selected):
        lift=7 if row in [1,5] and col in [2,6] else 0
        records.append(put(atlas,row,col,image,b,scale,lift))
atlas.save(DEST/'dasha_atlas.png')
idle_atlas=Image.new('RGBA',(1280,1024));idle_records=[]
for row in range(4):
    if row == 1 or row >= 2:
        # The independently generated crouch-idle family has an enlarged skull
        # and cannot match both anatomy and height with a uniform resample.
        # Reuse the actual last posture drawing: all transitions now meet the
        # same silhouette. Runtime adds sub-pixel breathing about the foot pivot.
        source_row = 3 if row == 2 else 7
        source_col = 0 if row == 1 else 7
        pose = atlas.crop((source_col*160,source_row*256,(source_col+1)*160,(source_row+1)*256))
        for col in range(8):
            idle_atlas.alpha_composite(pose,(col*160,row*256))
            idle_records.append({'row':row,'frame':col,'reuse_main':[source_row,source_col]})
        continue
    image=stand_idle if row<2 else idle
    selected=sr[row] if row<2 else ir[row]
    target=200 if row<2 else 122
    scale=target/max(b[3]-b[1] for b in selected)
    for col,b in enumerate(selected):idle_records.append(put(idle_atlas,row,col,image,b,scale))
idle_atlas.save(DEST/'dasha_idle_atlas.png')
(DEST/'atlas.json').write_text(json.dumps({'revision':2,'cell':[160,256],'baseline':244,'standing_height':200,'columns':8,'rows':['walk_front','run_front','crouch_walk_front','crouch_transition_front','walk_back','run_back','crouch_walk_back','crouch_transition_back'],'frames':records,'idle_rows':['stand_front','stand_back','crouch_front','crouch_back'],'idle_frames':idle_records,'rejected_generated_frame':'redraw_crouch_source row1 col0 shows face, excluded from back loop','back_crouch_source_order':[4,1,2,3,7,5,6,7]},indent=2),encoding='utf-8')
for name,im in [('contact_sheet.png',atlas),('idle_contact_sheet.png',idle_atlas)]:
    preview=Image.new('RGB',im.size,(28,31,30));preview.paste(im,mask=im.getchannel('A'))
    d=ImageDraw.Draw(preview)
    for row in range(im.height//256):d.line((0,row*256+244,1280,row*256+244),fill=(74,78,65))
    preview.save(DEST/name)
try:font=ImageFont.truetype('C:/Windows/Fonts/segoeui.ttf',18)
except OSError:font=ImageFont.load_default()
# Direct comparison at the same standing height, without changing aspect ratios.
comparison=Image.new('RGB',(600,320),(25,30,29));d=ImageDraw.Draw(comparison)
old=clean(Image.open(ROOT/'assets/sprites/dasha.png'));old=old.crop(old.getbbox());old=old.resize((round(old.width*200/old.height),200),Image.Resampling.NEAREST)
new=idle_atlas.crop((0,0,160,256))
comparison.paste(old,(130-old.width//2,260-old.height),old);comparison.paste(new,(350-80,260-244),new)
d.text((80,280),'Исходная Даша',font=font,fill='#dedbd2');d.text((300,280),'Новая Даша',font=font,fill='#dedbd2')
comparison.save(PREVIEW/'proportions.png')
# Runtime-like contact preview and animated panel, including both breath cycles.
labels=['Покой','Ходьба','Бег','Красться','В приседе','Спина / бег','Спина / покой','Спина / присед']
frames=[]
for t in range(64):
    out=Image.new('RGB',(1280,340),(25,30,29));d=ImageDraw.Draw(out)
    for i in range(8):
        if i in [0,4,6,7]:
            row={0:0,4:2,6:1,7:3}[i];col=0 if i==0 else int(((t*.08/3.2)%1)*8);sheet=idle_atlas
        else:
            row={1:0,2:1,3:2,5:5}[i];col=(t//(2 if i in [2,5] else 3))%8;sheet=atlas
        pose=sheet.crop((col*160,row*256,(col+1)*160,(row+1)*256))
        if i in [0,4,6,7]:
            breath=1-math.sin(t*.08/3.2*math.tau)**2*.006
            pose=pose.transform(pose.size,Image.Transform.AFFINE,(1,0,0,0,1/breath,244-244/breath),resample=Image.Resampling.NEAREST)
        out.paste(pose,(i*160,10),pose)
        d.text((i*160+8,290),labels[i],font=font,fill='#dedbd2')
    frames.append(out)
frames[0].save(PREVIEW/'locomotion.gif',save_all=True,append_images=frames[1:],duration=80,loop=0,optimize=False,disposal=2)
frames[0].save(PREVIEW/'states.png')
print('Registered main64 + idle32 poses. Feet244; standing200. Cropped, uniformly resampled, not warped.')
