"""Assemble the real-renderer draw/stow capture into a review GIF."""
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[2]
files=sorted((root/'.godot/held-flashlight-frames').glob('*.png'))
assert len(files)==48
frames=[Image.open(path).convert('RGB') for path in files]
out=root/'AI/review/images/held-flashlight/draw-stow.gif'
frames[0].save(out,save_all=True,append_images=frames[1:],duration=[30,30,40]*16,loop=0,disposal=2)
print(out)
