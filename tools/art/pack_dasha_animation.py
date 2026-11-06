"""Lossless animated PNG previews from Blender frames, standard library only."""
import struct
import zlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT/'assets/models/characters/dasha_meshy/locomotion_v2/previews'


def chunks(data):
    pos = 8
    while pos < len(data):
        length = struct.unpack_from('>I', data, pos)[0]
        yield data[pos+4:pos+8], data[pos+8:pos+8+length]
        pos += length+12


def chunk(tag, data):
    return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data))


def pack_sequence(name, frame_count, delay_numerator, delay_denominator):
    files = sorted((OUT/name).glob('*.png'))
    assert len(files) == frame_count, (name, len(files), frame_count)
    frames = [list(chunks(f.read_bytes())) for f in files]
    header = frames[0][0][1]
    width, height = struct.unpack_from('>II',header)
    assert all(frame[0][1] == header for frame in frames)
    output = b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',header)
    for tag, data in frames[0][1:]:
        if tag == b'IDAT': break
        output += chunk(tag,data)
    output += chunk(b'acTL',struct.pack('>II',frame_count,0))
    sequence = 0
    for index, frame in enumerate(frames):
        control = struct.pack('>IIIIIHHBB',sequence,width,height,0,0,delay_numerator,delay_denominator,0,0)
        output += chunk(b'fcTL',control)
        sequence += 1
        compressed = b''.join(data for tag,data in frame if tag == b'IDAT')
        if index == 0:
            output += chunk(b'IDAT',compressed)
        else:
            output += chunk(b'fdAT',struct.pack('>I',sequence)+compressed)
            sequence += 1
    output += chunk(b'IEND',b'')
    (OUT/f'{name}_loop.png').write_bytes(output)
    print(name, len(output), 'bytes;', frame_count, 'frames, infinite loop')


specs = {'walk':(24,30,720), 'run':(24,24,720), 'sneak':(24,42,720)}
if (OUT/'ankle_walk_side').is_dir(): specs['ankle_walk_side'] = (48,1,48)
if (OUT/'walk_side_full').is_dir(): specs['walk_side_full'] = (48,1,48)
if (OUT/'run_side_full').is_dir(): specs['run_side_full'] = (48,1,60)
if (OUT/'run_calf_side').is_dir(): specs['run_calf_side'] = (48,1,60)
for name in sys.argv[1:] or specs:
    pack_sequence(name, *specs[name])
