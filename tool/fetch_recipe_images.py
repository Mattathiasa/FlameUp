#!/usr/bin/env python3
"""Attach a verified photo to every catalogue recipe.

For each dish the script tries a list of known Commons filenames first (via
Special:FilePath, which redirects to the file itself), then falls back to a
 Commons full-text search restricted to the File namespace. A URL is only
written when the response is HTTP 200 with an image content-type, so no dead
link can reach the seed file. Wikimedia hotlinking is allowed and free; the
family-recipe upload path uses Cloudinary instead (see .env.example).

Run:  python3 tool/fetch_recipe_images.py [--dry]
"""
import json
import re
import sys
import time
import urllib.parse
import urllib.request
from typing import Optional

SEED = 'assets/seed/recipes.json'
UA = {'User-Agent': 'FlameUpSeeder/1.0 (recipe image fetch; contact: demo@flameup.app)'}

# Known-good candidates per dish, best guess first.
CANDIDATES = {
    'doro': ['Doro wat.jpg', 'Doro Wat - Ethiopian cuisine.jpg', 'Ethiopian doro wat.jpg'],
    'shiro': ['Shiro (Ethiopian food).jpg', 'Shiro wat.jpg', 'Shiro.jpg'],
    'tibs': ['Tibs.jpg', 'Ethiopian Tibs.jpg', 'Zilzil tibs.jpg'],
    'misir': ['Misir wot.jpg', 'Misir Wat.jpg', 'Mesir wat.jpg'],
    'injera': ['Injera.jpg', 'Injera with various wats.jpg', 'Injera and Wat.jpg'],
    'kitfo': ['Kitfo.jpg', 'Kitfo dish.jpg', 'Ethiopian kitfo.jpg'],
    'gomen': ['Gomen (food).jpg', 'Gomen.jpg', 'Ethiopian collard greens.jpg'],
    'buna': ['Ethiopian coffee ceremony.jpg', 'Coffee ceremony Ethiopia.jpg', 'Buna qalad.jpg'],
    'beyay': ['Beyaynetu.jpg', 'Beyainatu.jpg', 'Fasting platter.jpg'],
    'firfir': ['Firfir.jpg', 'Fir-fir.jpg', 'Fatira.jpg'],
    'kik': ['Kik alicha.jpg', 'Alicha.jpg', 'Misir wot.jpg'],
    'dulet': ['Dulet.jpg', 'Dullet.jpg', 'Quanta firfir.jpg'],
    'chechebsa': ['Chechebsa.jpg', 'Chechebsa with honey and kibbeh.jpg'],
    'genfo': ['Genfo.jpg', 'Genfo with berbere.jpg'],
    'atakilt': ['Atkilt wat.jpg', 'Atakilt wat.jpg', 'Ethiopian cabbage dish.jpg'],
    'bozena': ['Bozena shiro.jpg', 'Shiro (Ethiopian food).jpg'],
    'fosolia': ['Fosolia.jpg', 'Fasolia.jpg', 'Ethiopian green beans.jpg'],
    'alicha': ['Alicha.jpg', 'Atkilt alicha.jpg', 'Kik alicha.jpg'],
    'ayib': ['Ayib.jpg', 'Ayib cheese.jpg', 'Ethiopian cottage cheese.jpg'],
    'awaze': ['Awaze tibs.jpg', 'Awaze.jpg', 'Tibs.jpg'],
    'tihlo': ['Tihlo.jpg', 'Tihlo - Ethiopian dish.jpg'],
    'shorba': ['Shorba.jpg', 'Ethiopian soup.jpg'],
    'kinche': ['Kinche.jpg', 'Ethiopian cracked wheat.jpg'],
    'ful': ['Ful medames.jpg', 'Ful Medames - dish.jpg'],
    'dabo': ['Dabo kolo.jpg', 'Dabo Kolo - Ethiopian snack.jpg'],
}

SEARCH = ('https://commons.wikimedia.org/w/api.php'
          '?action=query&list=search&srnamespace=6&srlimit=5&format=json&srsearch=')


def head_ok(url: str) -> bool:
    """True when the URL resolves to a downloadable image."""
    try:
        req = urllib.request.Request(url, method='GET', headers=UA)
        with urllib.request.urlopen(req, timeout=30) as resp:
            ctype = resp.headers.get('Content-Type', '')
            return resp.status == 200 and ctype.startswith('image/')
    except Exception:
        return False


def file_url(filename: str, width: int = 800) -> str:
    name = urllib.parse.quote(filename)
    return f'https://commons.wikimedia.org/wiki/Special:FilePath/{name}?width={width}'


def search_commons(dish: str):
    query = urllib.parse.quote(f'{dish} ethiopian food')
    try:
        req = urllib.request.Request(SEARCH + query, headers=UA)
        with urllib.request.urlopen(req, timeout=30) as resp:
            hits = json.load(resp).get('query', {}).get('search', [])
        return [hit['title'].removeprefix('File:') for hit in hits]
    except Exception:
        return []


# The search fallback is greedy: "beso ethiopian food" once matched a
# 19th-century Italian painting, "kinche" a Bible PDF. These checks keep the
# honesty rule: only a plausibly dish-specific IMAGE may be written.
IMAGE_EXT = re.compile(r'\.(jpe?g|png|webp)$', re.IGNORECASE)
DENY_WORDS = ('bible', 'testament', 'crops', 'market', 'el beso', 'kiss',
              'painting', 'statue', 'pinacoteca', 'menu', 'logo', 'map',
              'resto', 'restaurant', 'paris', 'hotel', 'sign', 'cover',
              'poster', 'flag')
SYNONYMS = {
    'firfir': ('firfir', 'fir-fir', 'fir fir'),
    'kik': ('kik',),
    'kinche': ('kinche', 'kinch'),
    'awaze': ('awaze',),
    'beso': ('beso',),
    'beyay': ('beyay', 'beyainatu', 'beyaynetu'),
    'dulet': ('dulet',),
    'chechebsa': ('chechebsa', 'chechebs'),
    'atakilt': ('atakilt',),
    'bozena': ('bozena',),
    'fosolia': ('fosolia', 'fossolia'),
    'alicha': ('alicha',),
    'shorba': ('shorba',),
    'dabo': ('dabo',),
    'dabo-kolo': ('dabo kolo', 'dabo-kolo', 'dabokolo'),
}


def relevant(dish: str, filename: str) -> bool:
    """Filename must be an image, name the dish, and not be a false friend."""
    low = filename.lower()
    if not IMAGE_EXT.search(low):
        return False
    if any(w in low for w in DENY_WORDS):
        return False
    words = SYNONYMS.get(dish, (dish,))
    return any(re.search(rf'\b{re.escape(w)}\b', low) for w in words)


def resolve(dish: str, taken: set[str]) -> Optional[str]:
    tried = list(CANDIDATES.get(dish, []))
    tried += [f'{dish} ethiopian.jpg']
    for name in tried:
        url = file_url(name)
        if head_ok(url):
            return url
    for name in search_commons(dish):
        if not relevant(dish, name):
            continue
        url = file_url(name)
        if url in taken:
            continue  # two dishes never share one photo
        if head_ok(url):
            return url
    return None


def main() -> None:
    dry = '--dry' in sys.argv
    data = json.load(open(SEED))
    taken = {r.get('imageUrl') for r in data['recipes'].values()
             if r.get('imageUrl')}
    missing = []
    for rid, recipe in data['recipes'].items():
        if recipe.get('imageUrl'):
            print(f'{rid:10} already has an image, skipping')
            continue
        url = resolve(rid, taken)
        if url is None:
            missing.append(rid)
            print(f'{rid:10} NO IMAGE FOUND')
        else:
            taken.add(url)
            print(f'{rid:10} {url}')
            if not dry:
                recipe['imageUrl'] = url
        time.sleep(0.4)  # be polite to the Commons API

    if not dry:
        json.dump(data, open(SEED, 'w'), ensure_ascii=False, indent=2)
        print(f'wrote {SEED}')
    if missing:
        print('missing (kept on gradient):', ', '.join(missing))


if __name__ == '__main__':
    main()
