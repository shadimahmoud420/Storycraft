"""Font library: downloads the fonts (Regular only, plus Cairo UI weights)
from Google Fonts into assets/fonts/, registers them in pubspec.yaml and
generates lib/data/font_catalog.g.dart. All fonts are SIL OFL.
Run: python3 tool/fonts_catalog.py"""
import os, re, subprocess, urllib.parse

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
OUT = os.path.join(ROOT, 'assets', 'fonts')

# (family, arabic label or None, category)
ARABIC = [
    ('Cairo', 'القاهرة', 'modern'), ('Tajawal', 'تجوال', 'modern'),
    ('Almarai', 'المراعي', 'modern'), ('Changa', 'تشانغا', 'modern'),
    ('IBM Plex Sans Arabic', 'بلكس', 'modern'), ('Readex Pro', 'ريدكس', 'modern'),
    ('Alexandria', 'الإسكندرية', 'modern'), ('Vazirmatn', 'وزير', 'modern'),
    ('Noto Sans Arabic', 'نوتو', 'modern'), ('Mada', 'مدى', 'modern'),
    ('Zain', 'زين', 'modern'), ('Beiruti', 'بيروتي', 'modern'),
    ('Rubik', 'روبيك', 'modern'), ('Baloo Bhaijaan 2', 'بالو', 'modern'),
    ('Lemonada', 'ليمونادة', 'modern'), ('Playpen Sans Arabic', 'بلاي بن', 'modern'),
    ('Reem Kufi', 'ريم كوفي', 'kufi'), ('Kufam', 'كوفام', 'kufi'),
    ('Noto Kufi Arabic', 'نوتو كوفي', 'kufi'), ('Handjet', 'هاندجت', 'kufi'),
    ('Reem Kufi Fun', 'ريم كوفي فن', 'kufi'), ('Qahiri', 'قاهري', 'kufi'),
    ('Blaka', 'بلاكا', 'kufi'),
    ('Amiri', 'أميري', 'naskh'), ('Amiri Quran', 'أميري قرآن', 'naskh'),
    ('Scheherazade New', 'شهرزاد', 'naskh'), ('Noto Naskh Arabic', 'نوتو نسخ', 'naskh'),
    ('Lateef', 'لطيف', 'naskh'), ('Markazi Text', 'مركزي', 'naskh'),
    ('Harmattan', 'هرمتان', 'naskh'), ('Mirza', 'ميرزا', 'naskh'),
    ('Ruwudu', 'رؤدو', 'naskh'),
    ('Aref Ruqaa', 'رقعة', 'calligraphy'), ('Rakkas', 'رقّاص', 'calligraphy'),
    ('Gulzar', 'گلزار', 'calligraphy'), ('Noto Nastaliq Urdu', 'نستعليق', 'calligraphy'),
    ('Alkalami', 'القلمي', 'calligraphy'), ('Katibeh', 'كاتبة', 'calligraphy'),
    ('Lalezar', 'لاله‌زار', 'display'), ('El Messiri', 'المسيري', 'display'),
    ('Jomhuria', 'جمهورية', 'display'), ('Marhey', 'مرحى', 'display'),
    ('Badeen Display', 'بديع', 'display'),
]
ENGLISH = [
    ('Montserrat', None, 'sans'), ('Poppins', None, 'sans'), ('Raleway', None, 'sans'),
    ('Lato', None, 'sans'), ('Josefin Sans', None, 'sans'), ('Quicksand', None, 'sans'),
    ('Nunito', None, 'sans'), ('Space Grotesk', None, 'sans'), ('Comfortaa', None, 'sans'),
    ('Playfair Display', None, 'serif'), ('Merriweather', None, 'serif'),
    ('Cinzel', None, 'serif'), ('Cormorant Garamond', None, 'serif'),
    ('Abril Fatface', None, 'serif'), ('Alfa Slab One', None, 'serif'),
    ('Pacifico', None, 'script'), ('Lobster', None, 'script'),
    ('Dancing Script', None, 'script'), ('Great Vibes', None, 'script'),
    ('Satisfy', None, 'script'), ('Sacramento', None, 'script'),
    ('Kaushan Script', None, 'script'), ('Yellowtail', None, 'script'),
    ('Parisienne', None, 'script'), ('Allura', None, 'script'),
    ('Bebas Neue', None, 'display'), ('Oswald', None, 'display'), ('Anton', None, 'display'),
    ('Righteous', None, 'display'), ('Archivo Black', None, 'display'),
    ('Bangers', None, 'display'), ('Fredoka', None, 'display'),
    ('Caveat', None, 'hand'), ('Permanent Marker', None, 'hand'),
    ('Amatic SC', None, 'hand'), ('Shadows Into Light', None, 'hand'),
    ('Indie Flower', None, 'hand'),
]
UI_WEIGHTS = {'Cairo': [400, 500, 600, 700, 800]}


def fetch(family, weight):
    css = subprocess.run(
        ['curl', '-sS', '-A', 'Mozilla/4.0',
         f'https://fonts.googleapis.com/css2?family={urllib.parse.quote(family)}:wght@{weight}'],
        capture_output=True, text=True).stdout
    m = re.search(r'url\((https://[^)]+\.ttf)\)', css)
    if not m:
        return None
    path = os.path.join(OUT, f"{family.replace(' ', '')}-{weight}.ttf")
    if not os.path.exists(path):
        subprocess.run(['curl', '-sS', '-o', path, m.group(1)], check=True)
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    ok_ar, ok_en, pub = [], [], []
    for lst, ok in ((ARABIC, ok_ar), (ENGLISH, ok_en)):
        for fam, label, cat in lst:
            weights = UI_WEIGHTS.get(fam, [400])
            files = [(w, fetch(fam, w)) for w in weights]
            files = [(w, p) for w, p in files if p]
            if not files:
                print('MISSING', fam)
                continue
            ok.append((fam, label, cat))
            entry = f'    - family: {fam}\n      fonts:\n'
            for w, p in files:
                entry += f'        - asset: assets/fonts/{os.path.basename(p)}\n'
                if w != 400:
                    entry += f'          weight: {w}\n'
            pub.append(entry)

    # pubspec: replace the generated fonts block
    ps = os.path.join(ROOT, 'pubspec.yaml')
    s = open(ps).read()
    block = '  # BEGIN GENERATED FONTS (tool/fonts_catalog.py)\n  fonts:\n' + ''.join(pub) + '  # END GENERATED FONTS\n'
    if '# BEGIN GENERATED FONTS' in s:
        s = re.sub(r'  # BEGIN GENERATED FONTS.*?# END GENERATED FONTS\n', block, s, flags=re.S)
    else:
        s = s.replace('  uses-material-design: true\n', '  uses-material-design: true\n' + block)
    open(ps, 'w').write(s)

    def dart(lst, arabic):
        out = ''
        for fam, label, cat in lst:
            lab = f", label: '{label}'" if label else ''
            out += f"  StoryFont('{fam}', arabic: {str(arabic).lower()}, category: FontCategory.{cat}{lab}),\n"
        return out
    g = ('// GENERATED by tool/fonts_catalog.py – do not edit by hand.\n'
         "part of 'fonts.dart';\n\n"
         'const _arabicFonts = <StoryFont>[\n' + dart(ok_ar, True) + '];\n\n'
         'const _englishFonts = <StoryFont>[\n' + dart(ok_en, False) + '];\n')
    open(os.path.join(ROOT, 'lib', 'data', 'font_catalog.g.dart'), 'w').write(g)
    print(f'arabic {len(ok_ar)}, english {len(ok_en)}')


main()
