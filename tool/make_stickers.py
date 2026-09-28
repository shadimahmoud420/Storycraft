"""Generates the cartoon sticker SVGs in assets/stickers/.
Flat colors + dark outline, compatible with flutter_svg (no masks/filters).
Run: python3 tool/make_stickers.py"""
import math, os

OUT = os.path.join(os.path.dirname(__file__), '..', 'assets', 'stickers')
os.makedirs(OUT, exist_ok=True)

INK = '#2D2240'
GOLD, GOLD_D = '#FFC93C', '#E8A317'
ORANGE, PINK, PURPLE, TEAL = '#FF8C42', '#FF6B9A', '#7B4DFF', '#2EC4B6'
CREAM, BROWN, BROWN_D, GREEN = '#FFF4D6', '#B5651D', '#7A3E12', '#3CB371'
SKIN, BLUSH, WHITE, SKY = '#F5C9A0', '#FF9EAA', '#FFFFFF', '#6EC6FF'
S = f'stroke="{INK}" stroke-width="5" stroke-linejoin="round" stroke-linecap="round"'
T = f'stroke="{INK}" stroke-width="3.5" stroke-linejoin="round" stroke-linecap="round"'


def save(name, body, w=200, h=200):
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" '
           f'width="{w}" height="{h}">{body}</svg>')
    with open(os.path.join(OUT, name + '.svg'), 'w') as f:
        f.write(svg)


def pt(c, r, deg):
    a = math.radians(deg)
    return c[0] + r * math.cos(a), c[1] + r * math.sin(a)


def star(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        x, y = pt((cx, cy), r, rot + i * 180 / n)
        pts.append(f'{x:.1f},{y:.1f}')
    return 'M' + ' L'.join(pts) + ' Z'


def crescent_path(cx, cy, r, ox, oy, r2):
    """Outer circle (cx,cy,r) minus inner circle (ox,oy,r2)."""
    d = math.hypot(ox - cx, oy - cy)
    a = (r * r - r2 * r2 + d * d) / (2 * d)
    h = math.sqrt(r * r - a * a)
    mx, my = cx + a * (ox - cx) / d, cy + a * (oy - cy) / d
    p1 = (mx + h * (oy - cy) / d, my - h * (ox - cx) / d)
    p2 = (mx - h * (oy - cy) / d, my + h * (ox - cx) / d)
    return (f'M{p1[0]:.1f},{p1[1]:.1f} A{r},{r} 0 1 0 {p2[0]:.1f},{p2[1]:.1f} '
            f'A{r2},{r2} 0 0 1 {p1[0]:.1f},{p1[1]:.1f} Z')


def face(cx, cy, s=1.0, happy=True):
    """Closed happy eyes, smile and blush."""
    e = 9 * s
    out = (f'<path d="M{cx-18*s},{cy} q{e/1.2},{-e} {e*1.6},0" fill="none" {T}/>'
           f'<path d="M{cx+18*s-e*1.6},{cy} q{e/1.2},{-e} {e*1.6},0" fill="none" {T}/>')
    if happy:
        out += f'<path d="M{cx-7*s},{cy+10*s} q{7*s},{8*s} {14*s},0" fill="none" {T}/>'
    out += (f'<ellipse cx="{cx-24*s}" cy="{cy+9*s}" rx="{6*s}" ry="{4*s}" fill="{BLUSH}" opacity="0.8"/>'
            f'<ellipse cx="{cx+24*s}" cy="{cy+9*s}" rx="{6*s}" ry="{4*s}" fill="{BLUSH}" opacity="0.8"/>')
    return out


def lantern(x, y, s=1.0, glass=TEAL, cap=PURPLE):
    """Fanous centered at x, top at y, ~ 70*s wide, 120*s tall."""
    def P(dx, dy):
        return f'{x+dx*s:.1f},{y+dy*s:.1f}'
    return (
        f'<circle cx="{x}" cy="{y+6*s}" r="{6*s}" fill="none" {S}/>'
        f'<path d="M{P(-18,26)} Q{P(0,2)} {P(18,26)} Z" fill="{cap}" {S}/>'
        f'<path d="M{P(-26,26)} L{P(26,26)} L{P(20,36)} L{P(-20,36)} Z" fill="{GOLD}" {S}/>'
        f'<path d="M{P(-20,36)} L{P(20,36)} L{P(28,82)} L{P(-28,82)} Z" fill="{GOLD}" {S}/>'
        f'<path d="M{P(-13,42)} L{P(13,42)} L{P(18,76)} L{P(-18,76)} Z" fill="{glass}" stroke="{INK}" stroke-width="3"/>'
        f'<ellipse cx="{x}" cy="{y+62*s}" rx="{7*s}" ry="{11*s}" fill="#FFF3A6"/>'
        f'<path d="M{P(0,42)} L{P(0,76)}" stroke="{INK}" stroke-width="3"/>'
        f'<path d="M{P(-28,82)} L{P(28,82)} L{P(18,96)} L{P(-18,96)} Z" fill="{cap}" {S}/>'
        f'<path d="M{P(-8,96)} L{P(8,96)} L{P(0,110)} Z" fill="{GOLD}" {S}/>'
    )


# ---------------------------------------------------------------- Ramadan
save('crescent',
     f'<path d="{crescent_path(95,105,72,130,82,60)}" fill="{GOLD}" {S}/>'
     f'<path d="M52,122 q8,-7 16,0" fill="none" {T}/>'
     f'<path d="M58,140 q9,8 18,-2" fill="none" {T}/>'
     f'<ellipse cx="50" cy="135" rx="6" ry="4" fill="{BLUSH}" opacity="0.8"/>'
     f'<path d="{star(160,58,22,10)}" fill="{GOLD}" {S}/>'
     f'<path d="{star(150,150,10,4.5)}" fill="{WHITE}" {T}/>')

save('lantern', lantern(100, 30, 1.45))

save('cannon',
     f'<ellipse cx="100" cy="176" rx="80" ry="10" fill="#000" opacity="0.12"/>'
     f'<path d="M40,150 L120,150 L128,168 L32,168 Z" fill="{BROWN}" {S}/>'
     f'<g transform="rotate(-22 95 125)">'
     f'<rect x="45" y="106" width="110" height="40" rx="20" fill="#4A4A5A" {S}/>'
     f'<rect x="146" y="100" width="18" height="52" rx="7" fill="#5C5C70" {S}/>'
     f'<path d="M62,114 L62,138 M84,112 L84,140" stroke="#8E8EA6" stroke-width="5"/>'
     f'</g>'
     f'<circle cx="62" cy="150" r="24" fill="{BROWN_D}" {S}/>'
     f'<circle cx="62" cy="150" r="7" fill="{GOLD}" {T}/>'
     f'<path d="M62,126 L62,174 M38,150 L86,150" stroke="{INK}" stroke-width="3"/>'
     f'<circle cx="170" cy="48" r="16" fill="{WHITE}" {T}/>'
     f'<circle cx="150" cy="38" r="13" fill="{WHITE}" {T}/>'
     f'<circle cx="186" cy="30" r="11" fill="{WHITE}" {T}/>'
     f'<path d="{star(162,74,13,6,8)}" fill="{ORANGE}" {T}/>')

save('kaaba',
     f'<ellipse cx="100" cy="172" rx="86" ry="14" fill="#F1ECE2" {T}/>'
     f'<path d="M38,62 L112,50 L112,168 L38,160 Z" fill="#1E1E24" {S}/>'
     f'<path d="M112,50 L166,60 L166,158 L112,168 Z" fill="#34343E" {S}/>'
     f'<path d="M38,80 L112,70 L112,86 L38,95 Z" fill="{GOLD}" {T}/>'
     f'<path d="M112,70 L166,79 L166,94 L112,86 Z" fill="{GOLD_D}" {T}/>'
     + ''.join(f'<circle cx="{46+i*13}" cy="{86-i*1.6:.1f}" r="2.2" fill="{INK}"/>' for i in range(5))
     + f'<path d="M58,118 L80,115 L80,160 L58,158 Z" fill="{GOLD}" {T}/>'
     f'<path d="M69,122 L69,154" stroke="{GOLD_D}" stroke-width="3"/>')

save('mosque',
     f'<rect x="20" y="70" width="22" height="100" rx="4" fill="{CREAM}" {S}/>'
     f'<path d="M16,70 L31,40 L46,70 Z" fill="{TEAL}" {S}/>'
     f'<rect x="158" y="70" width="22" height="100" rx="4" fill="{CREAM}" {S}/>'
     f'<path d="M154,70 L169,40 L184,70 Z" fill="{TEAL}" {S}/>'
     f'<path d="M50,110 Q50,48 100,40 Q150,48 150,110 Z" fill="{TEAL}" {S}/>'
     f'<path d="{crescent_path(100,24,11,106,20,9)}" fill="{GOLD}" {T}/>'
     f'<path d="M100,40 L100,34" {S}/>'
     f'<rect x="44" y="108" width="112" height="62" rx="4" fill="{CREAM}" {S}/>'
     f'<path d="M86,170 L86,140 Q100,122 114,140 L114,170 Z" fill="{PURPLE}" {S}/>'
     f'<path d="M58,132 Q64,122 70,132 L70,146 L58,146 Z M130,132 Q136,122 142,132 L142,146 L130,146 Z" fill="{GOLD}" {T}/>'
     f'<path d="M14,172 L186,172" {S}/>')

save('fasting_kid',
     f'<path d="M52,196 Q52,128 100,124 Q148,128 148,196 Z" fill="{WHITE}" {S}/>'
     f'<path d="M100,128 L100,196" stroke="#D9D9E3" stroke-width="4"/>'
     f'<circle cx="100" cy="86" r="44" fill="{SKIN}" {S}/>'
     f'<path d="M58,78 Q60,38 100,38 Q140,38 142,78 Q100,62 58,78 Z" fill="{WHITE}" {S}/>'
     f'<path d="M70,60 L70,54 M86,52 L86,46 M100,50 L100,44 M114,52 L114,46 M130,60 L130,54" stroke="#D9D9E3" stroke-width="3"/>'
     + face(100, 92, 1.0)
     + f'<path d="M60,156 Q100,184 140,156 L132,176 Q100,194 68,176 Z" fill="{BROWN}" {S}/>'
     f'<ellipse cx="84" cy="158" rx="9" ry="6" fill="{BROWN_D}" {T}/>'
     f'<ellipse cx="102" cy="162" rx="9" ry="6" fill="{BROWN_D}" {T}/>'
     f'<ellipse cx="119" cy="157" rx="9" ry="6" fill="{BROWN_D}" {T}/>'
     f'<circle cx="60" cy="162" r="12" fill="{SKIN}" {S}/>'
     f'<circle cx="140" cy="162" r="12" fill="{SKIN}" {S}/>')

save('dates',
     f'<rect x="132" y="70" width="44" height="90" rx="8" fill="#DDF3FF" {S}/>'
     f'<rect x="138" y="100" width="32" height="54" rx="5" fill="{SKY}" opacity="0.7"/>'
     f'<path d="M36,122 Q34,92 60,98 Q70,80 88,94 Q104,78 116,98 Q134,96 128,122 Z" fill="{BROWN_D}" {S}/>'
     f'<path d="M56,112 q6,-8 14,-2 M92,104 q6,-8 12,0" fill="none" stroke="#C58A5A" stroke-width="3" stroke-linecap="round"/>'
     f'<path d="M20,120 L144,120 Q136,170 82,172 Q28,170 20,120 Z" fill="{ORANGE}" {S}/>'
     f'<path d="M34,138 Q82,152 130,138" fill="none" stroke="{GOLD}" stroke-width="5" stroke-linecap="round"/>')

garland = f'<path d="M0,14 Q200,70 400,14" fill="none" stroke="{GOLD_D}" stroke-width="5" stroke-linecap="round"/>'
for i, (x, glass, cap) in enumerate([(50, TEAL, PURPLE), (125, PINK, TEAL), (200, GOLD_D, PURPLE),
                                     (275, PINK, TEAL), (350, TEAL, PURPLE)]):
    y = 14 + 56 * (1 - ((x - 200) / 200) ** 2) * 0.98 - 2
    garland += f'<path d="M{x},{y:.1f} L{x},{y+14:.1f}" {T}/>' + lantern(x, y + 10, 1.0, glass, cap)
for x, y in [(88, 110), (162, 128), (238, 128), (312, 110)]:
    garland += f'<path d="{star(x, y, 9, 4)}" fill="{GOLD}" {T}/>'
save('lantern_garland', garland, 400, 190)

# ---------------------------------------------------------------- Eid
save('balloons',
     f'<path d="M100,190 Q90,150 64,118 M100,190 Q104,150 106,98 M100,190 Q118,150 140,120" fill="none" {T}/>'
     f'<ellipse cx="62" cy="80" rx="34" ry="42" fill="{PINK}" {S}/>'
     f'<ellipse cx="140" cy="84" rx="34" ry="42" fill="{TEAL}" {S}/>'
     f'<ellipse cx="104" cy="56" rx="36" ry="44" fill="{GOLD}" {S}/>'
     f'<path d="M60,122 l-6,8 h12 z M140,126 l-6,8 h12 z M104,100 l-6,8 h12 z" fill="{INK}"/>'
     f'<ellipse cx="50" cy="64" rx="7" ry="12" fill="#fff" opacity="0.55"/>'
     f'<ellipse cx="92" cy="38" rx="7" ry="12" fill="#fff" opacity="0.55"/>'
     f'<ellipse cx="128" cy="68" rx="7" ry="12" fill="#fff" opacity="0.55"/>')

save('gift',
     f'<rect x="36" y="86" width="128" height="94" rx="8" fill="{PURPLE}" {S}/>'
     f'<rect x="26" y="64" width="148" height="30" rx="8" fill="#9B7BFF" {S}/>'
     f'<rect x="88" y="64" width="24" height="116" fill="{GOLD}" {S}/>'
     f'<path d="M100,64 Q64,20 52,44 Q44,64 100,64 Z" fill="{PINK}" {S}/>'
     f'<path d="M100,64 Q136,20 148,44 Q156,64 100,64 Z" fill="{PINK}" {S}/>'
     f'<circle cx="100" cy="62" r="9" fill="{GOLD}" {S}/>')

save('sweets',
     f'<ellipse cx="100" cy="150" rx="88" ry="28" fill="{CREAM}" {S}/>'
     f'<ellipse cx="100" cy="146" rx="70" ry="18" fill="#FFE9B8"/>'
     + ''.join(
         f'<circle cx="{x}" cy="{y}" r="24" fill="#E9B872" {S}/>'
         f'<path d="{star(x, y, 13, 6, 8)}" fill="none" stroke="{BROWN}" stroke-width="3"/>'
         f'<circle cx="{x-8}" cy="{y-9}" r="3" fill="#fff"/><circle cx="{x+9}" cy="{y-5}" r="2.5" fill="#fff"/>'
         for x, y in [(70, 130), (130, 130), (100, 104)]))

save('fireworks',
     ''.join(
         f'<path d="M{cx},{cy} L{pt((cx,cy),r,a)[0]:.1f},{pt((cx,cy),r,a)[1]:.1f}" stroke="{col}" stroke-width="6" stroke-linecap="round"/>'
         f'<circle cx="{pt((cx,cy),r+8,a)[0]:.1f}" cy="{pt((cx,cy),r+8,a)[1]:.1f}" r="4" fill="{col}"/>'
         for cx, cy, r, col in [(80, 80, 42, PINK), (140, 120, 34, GOLD), (60, 150, 26, TEAL)]
         for a in range(0, 360, 30))
     + f'<path d="{star(160,44,14,6)}" fill="{GOLD}" {T}/>')

bunting = f'<path d="M0,10 Q200,60 400,10" fill="none" stroke="{GOLD_D}" stroke-width="5" stroke-linecap="round"/>'
cols = [PINK, GOLD, TEAL, PURPLE, ORANGE, GREEN, PINK, GOLD]
for i in range(8):
    x = 25 + i * 50
    y = 10 + 50 * (1 - ((x - 200) / 200) ** 2) * 0.98
    bunting += f'<path d="M{x-20},{y-3:.1f} L{x+20},{y+3:.1f} L{x},{y+46:.1f} Z" fill="{cols[i]}" {T}/>'
save('bunting', bunting, 400, 110)

# ---------------------------------------------------------------- Friday
beads = ''
for i in range(24):
    a = -90 + i * 360 / 24
    x, y = 100 + 62 * math.cos(math.radians(a)), 88 + 62 * math.sin(math.radians(a))
    beads += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="9" fill="{GOLD if i % 6 == 0 else GREEN}" {T}/>'
save('misbaha',
     beads + f'<path d="M100,152 L100,172" {S}/>'
     f'<circle cx="100" cy="150" r="10" fill="{GOLD}" {T}/>'
     f'<path d="M86,172 L114,172 L120,196 L80,196 Z" fill="{GOLD}" {S}/>'
     f'<path d="M90,178 L88,194 M100,178 L100,194 M110,178 L112,194" stroke="{GOLD_D}" stroke-width="3"/>')

def hand(mirror):
    g = (f'<path d="M100,178 L60,178 Q40,150 42,110 L44,58 Q46,46 56,48 Q64,50 64,62 L66,100 '
         f'L68,40 Q70,28 80,30 Q88,32 88,44 L88,96 L92,34 Q94,22 104,24 Q112,26 110,40 L108,98 '
         f'L112,52 Q116,42 124,46 Q130,50 128,62 L124,120 Q122,160 100,178 Z" fill="{SKIN}" {S}/>'
         f'<path d="M64,150 Q84,160 104,150" fill="none" stroke="#E0A87C" stroke-width="3"/>')
    return (f'<g transform="translate(222,0) scale(-1,1) translate(-10,0)">{g}</g>' if mirror
            else f'<g transform="translate(-22,0)">{g}</g>')
save('dua_hands', f'<g transform="translate(10,10) scale(0.9)">{hand(False)}{hand(True)}</g>')

# ---------------------------------------------------------------- Morning
save('coffee',
     f'<path d="M78,50 q-10,-14 0,-28 M100,46 q-10,-14 0,-28 M122,50 q-10,-14 0,-28" fill="none" stroke="#B9B2C8" stroke-width="5" stroke-linecap="round"/>'
     f'<ellipse cx="100" cy="170" rx="84" ry="16" fill="{CREAM}" {S}/>'
     f'<path d="M150,96 Q184,96 180,122 Q176,144 146,140" fill="none" {S}/>'
     f'<path d="M36,70 L164,70 L154,150 Q150,166 132,166 L68,166 Q50,166 46,150 Z" fill="{PINK}" {S}/>'
     f'<ellipse cx="100" cy="70" rx="64" ry="12" fill="{BROWN}" {S}/>'
     f'<path d="M100,78 q-10,-10 -16,-4 q-6,6 16,16 q22,-10 16,-16 q-6,-6 -16,4 z" fill="{CREAM}"/>'
     + face(100, 116, 0.9))

save('sun',
     ''.join(f'<path d="M{pt((100,100),62,a)[0]:.1f},{pt((100,100),62,a)[1]:.1f} L{pt((100,100),88,a)[0]:.1f},{pt((100,100),88,a)[1]:.1f}" stroke="{ORANGE}" stroke-width="10" stroke-linecap="round"/>'
             for a in range(0, 360, 30))
     + f'<circle cx="100" cy="100" r="52" fill="{GOLD}" {S}/>' + face(100, 100, 1.1))

def daisy(cx, cy, col):
    petals = ''.join(f'<ellipse cx="{pt((cx,cy),18,a)[0]:.1f}" cy="{pt((cx,cy),18,a)[1]:.1f}" rx="12" ry="8" '
                     f'transform="rotate({a} {pt((cx,cy),18,a)[0]:.1f} {pt((cx,cy),18,a)[1]:.1f})" fill="{col}" {T}/>'
                     for a in range(0, 360, 45))
    return petals + f'<circle cx="{cx}" cy="{cy}" r="11" fill="{GOLD}" {T}/>'
save('flowers',
     f'<path d="M100,190 L100,100 M100,190 Q80,140 56,90 M100,190 Q120,140 146,92" fill="none" stroke="{GREEN}" stroke-width="7" stroke-linecap="round"/>'
     f'<path d="M100,150 Q70,140 70,120 Q96,124 100,150 Z" fill="{GREEN}" {T}/>'
     + daisy(56, 78, WHITE) + daisy(146, 80, PINK) + daisy(100, 60, '#C9B6FF'))

# ---------------------------------------------------------------- Congrats
save('popper',
     ''.join(f'<rect x="{x}" y="{y}" width="12" height="7" rx="2" transform="rotate({r} {x} {y})" fill="{c}"/>'
             for x, y, r, c in [(120, 40, 30, PINK), (150, 60, -20, TEAL), (96, 26, 60, GOLD), (160, 30, 10, PURPLE),
                                (136, 18, -40, ORANGE), (176, 78, 45, GOLD), (110, 64, -10, GREEN)])
     + f'<path d="{star(150,100,12,5)}" fill="{GOLD}" {T}/>'
     f'<path d="M30,176 L104,82 L124,102 Z" fill="{PURPLE}" {S}/>'
     f'<path d="M58,140 L80,162 M78,116 L100,138" stroke="{GOLD}" stroke-width="7" stroke-linecap="round"/>'
     f'<ellipse cx="114" cy="92" rx="16" ry="8" transform="rotate(45 114 92)" fill="{PINK}" {S}/>')

save('trophy',
     f'<path d="M58,50 Q20,50 26,82 Q32,106 64,104" fill="none" {S}/>'
     f'<path d="M142,50 Q180,50 174,82 Q168,106 136,104" fill="none" {S}/>'
     f'<path d="M52,36 L148,36 L144,86 Q138,124 100,126 Q62,124 56,86 Z" fill="{GOLD}" {S}/>'
     f'<path d="M88,126 L112,126 L116,150 L84,150 Z" fill="{GOLD_D}" {S}/>'
     f'<rect x="62" y="150" width="76" height="30" rx="6" fill="{PURPLE}" {S}/>'
     f'<path d="{star(100,78,22,10)}" fill="#FFF3A6" {T}/>'
     f'<ellipse cx="70" cy="60" rx="5" ry="14" fill="#fff" opacity="0.5"/>')

save('cake',
     ''.join(f'<rect x="{x-4}" y="30" width="8" height="30" rx="3" fill="{c}" {T}/>'
             f'<path d="M{x},18 q-7,8 0,12 q7,-4 0,-12 z" fill="{ORANGE}" {T}/>'
             for x, c in [(76, TEAL), (100, PINK), (124, GOLD)])
     + f'<ellipse cx="100" cy="182" rx="86" ry="10" fill="{CREAM}" {S}/>'
     f'<rect x="34" y="112" width="132" height="66" rx="10" fill="{PINK}" {S}/>'
     f'<rect x="52" y="60" width="96" height="56" rx="10" fill="{CREAM}" {S}/>'
     f'<path d="M52,76 Q64,90 76,76 Q88,90 100,76 Q112,90 124,76 Q136,90 148,76" fill="none" stroke="{PINK}" stroke-width="6" stroke-linecap="round"/>'
     f'<path d="M34,130 Q50,146 66,130 Q82,146 100,130 Q118,146 134,130 Q150,146 166,130" fill="none" stroke="{WHITE}" stroke-width="6" stroke-linecap="round"/>')

# ---------------------------------------------------------------- Graduation
save('grad_cap',
     f'<path d="M58,96 L58,136 Q100,162 142,136 L142,96 Z" fill="#3A3A4A" {S}/>'
     f'<path d="M100,40 L186,80 L100,120 L14,80 Z" fill="#4A4A5E" {S}/>'
     f'<path d="M100,80 L160,96 L160,150" fill="none" stroke="{GOLD}" stroke-width="5" stroke-linecap="round"/>'
     f'<path d="M152,150 L168,150 L172,176 L148,176 Z" fill="{GOLD}" {T}/>'
     f'<circle cx="100" cy="80" r="7" fill="{GOLD}" {T}/>')

save('diploma',
     f'<rect x="22" y="70" width="156" height="60" rx="30" fill="{CREAM}" {S}/>'
     f'<ellipse cx="164" cy="100" rx="14" ry="30" fill="#F3E3B8" {S}/>'
     f'<path d="M40,88 L140,88 M40,100 L130,100 M40,112 L120,112" stroke="#D8C9A0" stroke-width="4" stroke-linecap="round"/>'
     f'<rect x="84" y="68" width="18" height="64" fill="{PINK}" {T}/>'
     f'<path d="M93,130 L80,172 L92,164 L98,176 Z M93,130 L108,170" fill="{PINK}" {T}/>')

save('graduate',
     f'<path d="M46,198 Q46,130 100,124 Q154,130 154,198 Z" fill="{PURPLE}" {S}/>'
     f'<path d="M84,128 L100,150 L116,128" fill="{WHITE}" {T}/>'
     f'<circle cx="100" cy="88" r="42" fill="{SKIN}" {S}/>'
     f'<path d="M60,74 Q70,50 100,48 Q130,50 140,74 Q120,62 100,64 Q80,62 60,74 Z" fill="#4A2E1F" {T}/>'
     + face(100, 94, 0.95)
     + f'<path d="M100,20 L168,46 L100,72 L32,46 Z" fill="#3A3A4A" {S}/>'
     f'<path d="M100,46 L150,56 L150,92" fill="none" stroke="{GOLD}" stroke-width="4" stroke-linecap="round"/>'
     f'<circle cx="150" cy="96" r="6" fill="{GOLD}" {T}/>'
     f'<rect x="120" y="150" width="56" height="22" rx="11" transform="rotate(-20 148 161)" fill="{CREAM}" {S}/>'
     f'<circle cx="126" cy="170" r="11" fill="{SKIN}" {S}/>')

# ---------------------------------------------------------------- Extras
save('sparkles',
     f'<path d="M100,20 Q108,92 180,100 Q108,108 100,180 Q92,108 20,100 Q92,92 100,20 Z" fill="{GOLD}" {S}/>'
     f'<path d="M160,24 Q163,44 182,47 Q163,50 160,70 Q157,50 138,47 Q157,44 160,24 Z" fill="{WHITE}" {T}/>'
     f'<path d="M40,140 Q42,154 56,156 Q42,158 40,172 Q38,158 24,156 Q38,154 40,140 Z" fill="{PINK}" {T}/>')

save('heart',
     f'<path d="M100,176 Q24,126 26,76 Q30,34 70,34 Q92,36 100,62 Q108,36 130,34 Q170,34 174,76 Q176,126 100,176 Z" fill="{PINK}" {S}/>'
     f'<ellipse cx="62" cy="70" rx="10" ry="16" transform="rotate(30 62 70)" fill="#fff" opacity="0.5"/>')

print('stickers:', len(os.listdir(OUT)))
