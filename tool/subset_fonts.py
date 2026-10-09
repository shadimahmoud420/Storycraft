"""Shrinks the bundled fonts: keeps Arabic and Latin (with the punctuation
and symbols the app uses), drops other scripts and hinting. Layout
features (ligatures, kashida, marks) are kept, so text renders the same.

Run from the project root after adding a font:
    python3 tool/subset_fonts.py
Fonts that can't be subset safely are left as they are.
"""
import glob
import os

from fontTools import subset
from fontTools.ttLib import TTFont

UNICODES = (
    'U+0000-00FF,U+0100-017F,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,'
    'U+0300-0308,U+0600-06FF,U+0750-077F,U+0870-08FF,U+2000-206F,U+20AC,'
    'U+2122,U+2190-2193,U+2212,U+2215,U+25CC,U+FB50-FDFF,U+FE70-FEFF,U+FFFD'
)


def shrink(path):
    opts = subset.Options()
    opts.layout_features = ['*']
    opts.name_IDs = ['*']
    opts.name_languages = ['*']
    opts.hinting = False
    opts.notdef_outline = True
    opts.glyph_names = False
    font = TTFont(path)
    sub = subset.Subsetter(opts)
    sub.populate(unicodes=subset.parse_unicodes(UNICODES))
    sub.subset(font)
    tmp = path + '.tmp'
    font.save(tmp)
    if os.path.getsize(tmp) < os.path.getsize(path):
        os.replace(tmp, path)
    else:
        os.remove(tmp)


if __name__ == '__main__':
    for f in sorted(glob.glob('assets/fonts/*.ttf')):
        try:
            shrink(f)
        except Exception as e:  # noqa: BLE001 - keep the original font
            print(f'skipped {f}: {e}')
