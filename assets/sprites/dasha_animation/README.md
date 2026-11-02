# Dasha redraw — revision 2, 1 November 2026

## Detailed motion experiment — 2 November 2026

Current runtime uses `detailed_motion_proportions_source.png`, `detailed_crouch_proportions_source.png`, and `detailed_idle_source.png`. The first two are imagegen edits of the preserved motion/crouch sources, reducing only the heads to match the original `../dasha_pixel_detailed.png` proportions. At the registered scale, the front head contour at top+15 is 34–39 px through movement, compared with 36 px in the original model (previous run drawings reached 46 px). The body retains its original packing scale and foot pivot.

`tools/art/repack_dasha_detailed.ps1` rebuilds both runtime atlases. Standing and crouched idle repeat one drawing with foot-anchored breathing; the crouch endpoint matches the final transition frame. Walk/run and crouch-walk use eight generated drawings per direction. The generated cycles do not reliably alternate left and right steps; this previously discussed art limitation remains. The held flashlight uses separately registered sockets for the detailed atlas. Nearest filtering and a bounded local-contrast shader improve motion clarity; the same shader correction is applied while the arm mask is active. The shader preserves alpha and clamps neighbour samples inside each atlas cell.

## Previous runtime

The previous runtime used `redraw_source.png`, `redraw_crouch_source.png`, and `redraw_stand_idle_source.png`, made with built-in imagegen using the ORIGINAL `../dasha.png` and a neutral crop as identity/proportion references. Brief: preserve the elongated slender character, compact head, long legs, long dark coat, silver hair, yellow laces and handbag; no chibi proportions. Match camera and anatomy through locomotion, crouch and idle. `neutral_reference.png` is the accepted neutral reference.

`dasha_atlas.png`: 8×8 cells, each160×256, baseline244. Rows: walk/run/crouch-walk/posture transition front, then same back. Main standing height200. Crouch lowers the hips; no runtime scale increase. Run flight frames2/6 have an explicit7px lift.

`dasha_idle_atlas.png`: 8×4 cells. Front standing row contains separately drawn breathing/blink frames, but runtime holds frame0: differences in the face, hair and coat made switching these drawings visibly jerky. All resting views now use the same continuous foot-anchored breathing, up to0.6% below base height. Back standing and both crouched rest rows reuse the registered corresponding posture endpoint: the independent `redraw_idle_source.png` family was rejected for incompatible anatomy. Thus not all32 idle cells are independent drawings, and the front blink sequence is retained as source art rather than played in game.

The first back-facing crouch source frame incorrectly showed a face; it is excluded. Replacement source order is recorded in atlas.json. Cropping, removal of alpha<16 specks, uniform nearest-neighbour resampling and registration are reproducible with `tools/art/repack_dasha.py`; no new articulated poses are synthesized by that script. Sources stay in the project, but only runtime atlases are shipped.

Preview: `AI/review/images/animation/proportions.png`, `locomotion.gif`, `states.png`. Runtime directions and transitions: `scripts/dasha_animation.gd`. The original base is preserved unchanged.

---

## Previous revision and its historical prompts

The following describes the earlier discarded body proportions, not the current runtime.

# Dasha — registered frame animation

Created 1 November 2026 with the built-in image generation tool, using `../dasha.png` as an identity/style reference. Original reference remains unchanged. No external image service/API key or third-party character asset was used.

## Files

- `source.png`: generated 64-pose source sheet, front/back walk, run, crouch and transition.
- `crouch_source.png`: generated separate 16-pose crouch-walk loop with consistent low posture.
- `dasha_atlas.png`: runtime atlas, 1280×2048, 8 columns × 8 rows, 160×256 cells. Foot baseline y=244, standing height approximately 200 px. Frames 2 and 6 in the run rows are raised 7 px for flight.
- `atlas.json`: original crop rectangles and final pose registration.
- `contact_sheet.png`: opaque QA sheet.
- `../../../tools/art/repack_dasha.py`: reproducible crop/nearest-neighbour repack. It extracts separately drawn poses, preserves aspect ratio and registers the ground contact; it does not synthesize body deformation.

Rows: walk front, run front, crouch walk front, standing-to-crouch front, walk back, run back, crouch walk back, standing-to-crouch back. Transition frame 0 supplies standing idle, frame 7 supplies crouched idle. Standing-up uses the transition poses in reverse.

`scripts/dasha_animation.gd` selects frames on the existing `DashaSprite` node. The old `character_gait.gdshader` is no longer bound to the character. Front/back camera directions and horizontal mirroring supply four facing quadrants; these are not eight independently drawn angles.

## Prompt 1 (built-in imagegen)

Create a production 2D pixel art animation spritesheet using the attached Dasha character as the identity/style reference. Preserve her silver long hair, pale face, long dark purple double breasted coat, black trousers and black boots with small yellow trim. Remove the briefcase during locomotion so arms can swing; empty hands. Full body. Camera is fixed 3/4 slightly elevated view for an isometric game, not extreme overhead. EXACTLY 8 columns and 8 rows = 64 distinct sprite frames on a genuinely transparent background. Canvas 1280 x 2048; every cell is 160 x 256. Every sprite is centered horizontally in its cell, at an identical foot baseline 244px within its cell; standing height about224px, crouched height160px. Generous transparent gutters; absolutely no grid lines, no labels, no text, no shadows below feet, no ground. Top FOUR rows face down-left (visible face), bottom FOUR rows face up-left (back of head, NO face). ROW1 eight-frame normal walking loop with alternating planted feet, knee bends, shoulder counter rotation, subtle coat follow-through. ROW2 eight-frame energetic running loop with strong knee lifts, forward lean, both feet airborne in flight poses, bent arms counter swinging, coat tails trailing. ROW3 eight-frame low crouch walking loop, hips lowered, knees deeply bent and feet planting while torso stays low. ROW4 eight successive poses lowering from fully standing at column1 to fully crouched at column8; knees bend genuinely, hips lower and torso leans, do not just shrink the image. ROW5 same walk cycle viewed from behind up-left. ROW6 same run cycle viewed from behind up-left. ROW7 same crouch walk cycle viewed from behind up-left. ROW8 same stand-to-crouch transition viewed from behind up-left. Use consistent character proportions, pixel density, palette, coat details and camera across all64 frames. Strong clean silhouettes, anatomically readable joint articulation and consistent foot registration. No motion blur, no smear, no photorealism, no repeated idle poses in locomotion rows. This must be usable as a frame atlas.

## Prompt 2 (built-in imagegen)

Asset type: 2D pixel art crouch-walk animation atlas. Identity reference: attached Dasha, same silver hair, pale face, dark purple long coat, black trousers and yellow-trim black boots. No briefcase. EXACTLY TWO ROWS and EIGHT COLUMNS, 16 full body sprites on transparent background. Grid is1024x512, each cell128x256. Row1 character faces down-left, face visible. Row2 character faces up-left, back of head only. Each row is a complete seamless 8-frame CYCLE of walking slowly while staying in a deep squat. Keep her pelvis at the SAME LOW HEIGHT and head the SAME HEIGHT across all8 frames in each row. All sprites crouched from first to last, knees deeply bent, torso leaning forward for balance, upper legs near horizontal, boots remain firmly on floor in contact poses, alternating left/right legs. Frames1 and5 are opposite stride contact poses with opposite feet forward, frames3 and7 are opposite passing poses. Do NOT show a progressive descent into crouch: she is already crouched in every frame. Standing character would be220px tall; crouched silhouette must be about145px high, at the SAME SCALE as reference rather than smaller body. Baseline at y244 within each cell and centers at x64. Keep same head size, limb proportions, coat details, camera and pixel density. Subtle arm counter swing and coat movement. No shadows on floor, no ground, no frame borders, no labels, no text. Clean transparent gutters between complete isolated silhouettes. All16 sprites fully inside canvas. Same restrained game pixel art style as reference.
