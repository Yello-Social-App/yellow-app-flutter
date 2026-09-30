"""Draw matching transparent notification assets. Run with Python + Pillow.

Geometry is authored on a 24-unit grid and rasterized at 96px for the 22dp
toolbar slot. GIF uses only transparent + exact black/white, with no matte.
"""

import math
from pathlib import Path

from PIL import GifImagePlugin, Image, ImageDraw


SIZE = 96
SCALE = SIZE / 24
DEST = Path(__file__).resolve().parents[1] / 'assets' / 'icons'


def curve(a, b, c, d):
    return [
        tuple((1-t)**3*a[k] + 3*(1-t)**2*t*b[k] + 3*(1-t)*t*t*c[k] + t**3*d[k] for k in (0, 1))
        for t in (i / 32 for i in range(33))
    ]


def frame(angle, white):
    image = Image.new('P', (SIZE, SIZE), 0)
    ink = 255 if white else 0
    image.putpalette([255, 0, 255, ink, ink, ink] + [v for i in range(2, 256) for v in (i, 0, 1)])
    image.info['transparency'] = 0
    draw = ImageDraw.Draw(image)
    radians = math.radians(angle)

    def point(p):
        x, y = p[0] - 12, p[1] - 5
        return ((12 + x*math.cos(radians) - y*math.sin(radians))*SCALE,
                (5 + x*math.sin(radians) + y*math.cos(radians))*SCALE)

    def stroke(points, width=1.65):
        points = [point(p) for p in points]
        draw.line(points, fill=1, width=round(width*SCALE), joint='curve')
        radius = width*SCALE/2
        for x, y in (points[0], points[-1]):
            draw.ellipse((x-radius, y-radius, x+radius, y+radius), fill=1)

    # Crown, domed body with flared rim, and a separate rounded clapper.
    stroke([(12, 3.4), (12, 4.8)])
    body = curve((12, 4.8), (8.6, 4.8), (6.8, 7.1), (6.8, 10.4))
    body += curve((6.8, 10.4), (6.8, 14.1), (6.2, 15.1), (4.9, 16.5))
    body += curve((4.9, 16.5), (4.6, 17), (5, 17.4), (5.7, 17.4))
    body += [(18.3, 17.4)]
    body += curve((18.3, 17.4), (19, 17.4), (19.4, 17), (19.1, 16.5))
    body += curve((19.1, 16.5), (17.8, 15.1), (17.2, 14.1), (17.2, 10.4))
    body += curve((17.2, 10.4), (17.2, 7.1), (15.4, 4.8), (12, 4.8))
    stroke(body)
    stroke(curve((10.3, 20), (10.8, 21.5), (13.2, 21.5), (13.7, 20)))
    return image


def main():
    for name, white in [('black', False), ('white', True)]:
        rest = frame(0, white)
        frame(0, white).convert('RGBA').save(DEST / f'notification_bell_{name}.png')
        frames = [rest]
        for i in range(1, 30):
            t = i / 30
            angle = 16 * math.sin(t * 6 * math.pi) * (1-t)**1.3
            frames.append(frame(angle, white))
        frames.append(rest.copy())
        # Full frames with restore-to-background disposal prevent trails.
        # Explicit encoding also keeps the exact two-color palette intact.
        with (DEST / f'notification_bell_{name}.gif').open('wb') as output:
            header, _ = GifImagePlugin.getheader(rest, info={'loop': 0, 'transparency': 0, 'optimize': False})
            for chunk in header:
                output.write(chunk)
            for image, duration in zip(frames, [40]*30 + [1600]):
                for chunk in GifImagePlugin.getdata(image, duration=duration, transparency=0, disposal=2):
                    output.write(chunk)
            output.write(b';')


if __name__ == '__main__':
    main()
