#!/usr/bin/env python3
"""Add catalogue recipes without editing Python.

Two ways to add a dish, both ending in one command:

  1. Drop a recipe into tool/recipes_extra.json (a template is written on
     first run) and run:

         python3 tool/push_recipes.py            # validate + build + push
         python3 tool/push_recipes.py --dry      # see what would happen
         python3 tool/push_recipes.py --no-push  # rebuild the local seed only

  2. For a dish the design already covers, add it to EXTRA in
     tool/build_seed.py instead; the pusher picks it up the same way.

What the pusher does, in order:

  validate   every dish in recipes_extra.json is checked against the
             catalogue's real vocabularies (region, category, aisle, level),
             required Amharic fields present, steps/ingredients non-empty,
             timers sane, images https — the same honesty rules the Dart
             tests enforce on the seed, applied before anything ships.
  build      runs tool/build_seed.py, which now merges recipes_extra.json
             after EXTRA, so the local seed (bundled with the app) matches.
  images     a dish may set 'imageUrl' to a local file path; the file is
             uploaded to Cloudinary (cloud/preset from .env) and the JSON is
             rewritten with the returned https delivery URL before build.
  push       PATCHes only the dishes that came from recipes_extra.json into
             production Firestore at recipes/<id>, with the searchTokens the
             seeder computes, so search finds them. Rules do not apply (the
             CLI token carries IAM authority, same as the console).
  verify     re-reads each pushed doc from production and reports the field
             delta; exits non-zero if anything came back different.

The seeder remains the tool for the whole catalogue and the demo people;
this one exists so adding a dish is a JSON edit and a command.
"""

import argparse
import json
import mimetypes
import os
import subprocess
import sys
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXTRAS_PATH = os.path.join(ROOT, 'tool', 'recipes_extra.json')
SEED_PATH = os.path.join(ROOT, 'assets', 'seed', 'recipes.json')

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

PROJECT = 'flameup-78d15'
BASE = (f'https://firestore.googleapis.com/v1/projects/{PROJECT}'
        '/databases/(default)/documents')

# The catalogue's real vocabularies, kept in sync by validation: a dish
# naming a region or aisle the app does not model would render wrong.
VALID_REGIONS = {'amhara', 'gurage', 'tigray', 'oromia', 'harar', 'sidama',
                 'afar', 'somali'}
VALID_CATEGORIES = {'wat', 'tibs', 'fasting', 'breakfast', 'bread', 'grain',
                    'ceremony', 'side', 'soup', 'raw', 'condiment'}
VALID_AISLES = {'spice', 'fresh', 'meatDairy', 'pantry'}
VALID_LEVELS = {0: 'Beginner', 1: 'Medium', 2: 'Advanced'}


def err(msg):
    print(f'  ✗ {msg}')
    raise SystemExit(1)


# --- extras file -------------------------------------------------------------

TEMPLATE = {
    'tir-shiro': {
        'en': 'Tir Shiro',
        'am': 'ጥር ሽሮ',
        'se': 'Silky spiced chickpea stew',
        'sa': 'ሽሮ በበርበሬ',
        'story': 'A one-pan everyday stew.',
        'storyAm': 'በአንድ መጥበሻ የሚሠራ የዕለት ተዕለት ወጥ።',
        'region': 'amhara',
        'category': 'fasting',
        'lv': 0,
        'min': 20,
        'xp': 60,
        'heat': 2,
        'fasting': True, 'vegan': True, 'gf': True, 'df': True,
        'a': '#8A4A16', 'b': '#D98F3C',
        'equipment': ['Wooden spatula'],
        'imageUrl': '',
        'ingredients': [
            {'name': 'Shiro powder', 'nameAm': 'የሽሮ ዱቄት', 'qty': 1,
             'unit': 'cup', 'unitAm': 'ኩባያ', 'aisle': 'pantry',
             'optional': False},
        ],
        'steps': [
            {'text': 'Toast the spices.', 'textAm': 'ቅመሙን ይቆርፉ።',
             'seconds': None, 'tip': '', 'tipAm': ''},
        ],
    },
}


def load_extras():
    if not os.path.exists(EXTRAS_PATH):
        with open(EXTRAS_PATH, 'w', encoding='utf-8') as fh:
            json.dump(TEMPLATE, fh, ensure_ascii=False, indent=2)
            fh.write('\n')
        print(f'No {os.path.relpath(EXTRAS_PATH, ROOT)} yet — wrote a '
              'template. Edit it, keep what you want, run again.')
        return None
    with open(EXTRAS_PATH, encoding='utf-8') as fh:
        return json.load(fh)


# --- validation --------------------------------------------------------------

def validate(dish, rid):
    problems = []

    def need(cond, msg):
        if not cond:
            problems.append(msg)

    for key in ('en', 'am', 'se', 'sa', 'story', 'storyAm', 'region',
                'category', 'min', 'xp', 'heat', 'a', 'b', 'ingredients',
                'steps'):
        need(key in dish, f'missing field: {key}')

    need(dish.get('region') in VALID_REGIONS,
         f"region '{dish.get('region')}' not one of {sorted(VALID_REGIONS)}")
    need(dish.get('category') in VALID_CATEGORIES,
         f"category '{dish.get('category')}' not one of "
         f'{sorted(VALID_CATEGORIES)}')
    need(dish.get('lv') in VALID_LEVELS,
         f"lv must be 0/1/2 (Beginner/Medium/Advanced), got {dish.get('lv')}")
    for k in ('min', 'xp', 'heat'):
        v = dish.get(k)
        need(isinstance(v, int) and v >= 0, f'{k} must be a non-negative int')
    need(1 <= dish.get('heat', 0) <= 5, 'heat should be 1..5')
    for k in ('en', 'am', 'se', 'sa', 'story', 'storyAm'):
        v = dish.get(k)
        need(isinstance(v, str) and v.strip(),
             f'{k} must be a non-empty string')
    for k in ('a', 'b'):
        v = dish.get(k, '')
        need(isinstance(v, str) and v.startswith('#') and len(v) == 7,
             f'{k} must be a #rrggbb hex color')
    need(6 <= dish.get('min', 0) <= 1440, 'min (total time) between 6 and 1440')
    need(20 <= dish.get('xp', 0) <= 400, 'xp between 20 and 400')

    ings = dish.get('ingredients') or []
    need(isinstance(ings, list) and ings, 'at least one ingredient')
    for n, i in enumerate(ings):
        for key in ('name', 'nameAm', 'qty', 'unit', 'unitAm', 'aisle'):
            need(key in i, f'ingredient {n}: missing {key}')
        need(i.get('aisle') in VALID_AISLES,
             f"ingredient {n}: aisle '{i.get('aisle')}' not one of "
             f'{sorted(VALID_AISLES)}')
        q = i.get('qty')
        need(isinstance(q, (int, float)) and q > 0,
             f'ingredient {n}: qty must be a positive number')

    steps = dish.get('steps') or []
    need(isinstance(steps, list) and steps, 'at least one step')
    for n, s in enumerate(steps):
        for key in ('text', 'textAm'):
            need(isinstance(s.get(key), str) and s[key].strip(),
                 f'step {n}: {key} must be a non-empty string')
        sec = s.get('seconds')
        need(sec is None or (isinstance(sec, int) and 10 <= sec <= 8 * 3600),
             f'step {n}: seconds must be 10..28800 (or null)')

    # the seed tests' honesty rules, applied before shipping
    img = dish.get('imageUrl') or ''
    if img:
        need(img.startswith('https://') or os.path.exists(img),
             'imageUrl must be https or an existing local file')
    return problems


def collect_problems(extras):
    bad = 0
    for rid, dish in extras.items():
        problems = validate(dish, rid)
        if problems:
            bad += 1
            print(f'✗ {rid}:')
            for p in problems:
                print(f'    - {p}')
    return bad


# --- images ------------------------------------------------------------------

def read_env_flags(env_path):
    flags = {}
    if os.path.exists(env_path):
        for line in open(env_path):
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                k, v = line.split('=', 1)
                flags[k.strip()] = v.strip().strip('\'"')
    return flags


def upload_image(local_path, uid_tag='pusher'):
    flags = read_env_flags(os.path.join(ROOT, '.env'))
    cloud = flags.get('CLOUDINARY_CLOUD_NAME', '')
    preset = flags.get('CLOUDINARY_UPLOAD_PRESET', '')
    if not cloud or not preset:
        err('Cloudinary flags not found in .env '
            '(CLOUDINARY_CLOUD_NAME / CLOUDINARY_UPLOAD_PRESET)')
    boundary = f'----flameup{os.getpid()}'
    mime = mimetypes.guess_type(local_path)[0] or 'application/octet-stream'
    with open(local_path, 'rb') as fh:
        data = fh.read()
    parts = []
    for name, value in (('upload_preset', preset),
                        ('folder', 'flameup'),
                        ('tags', f'flameup,user:{uid_tag}')):
        parts.append(
            f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"'
            f'\r\n\r\n{value}\r\n'.encode())
    parts.append(
        (f'--{boundary}\r\nContent-Disposition: form-data; name="file"; '
         f'filename="{os.path.basename(local_path)}"\r\n'
         f'Content-Type: {mime}\r\n\r\n').encode() + data + b'\r\n')
    parts.append(f'--{boundary}--\r\n'.encode())
    body = b''.join(parts)
    req = urllib.request.Request(
        f'https://api.cloudinary.com/v1_1/{cloud}/image/upload',
        data=body, method='POST',
        headers={'Content-Type': f'multipart/form-data; boundary={boundary}'})
    with urllib.request.urlopen(req, timeout=120) as resp:
        out = json.loads(resp.read().decode())
    return out['secure_url']


# --- build + push ------------------------------------------------------------

def run_build():
    subprocess.run([sys.executable, os.path.join(ROOT, 'tool',
                                                  'build_seed.py')],
                   check=True)


def search_tokens(recipe):
    """Same token set the seeder computes, so search finds the dish."""
    tokens = set()
    for key in ('title', 'titleAm', 'subtitle'):
        text = recipe.get(key) or ''
        for token in text.replace('(', ' ').replace(')', ' ').split():
            token = token.strip('.,!?:;\'"').lower()
            if len(token) >= 2:
                tokens.add(token)
    for tag in recipe.get('tags') or []:
        t = str(tag).lower()
        if t:
            tokens.add(t)
    return sorted(tokens)


def to_value(v):
    if v is None:
        return {'nullValue': None}
    if isinstance(v, bool):
        return {'booleanValue': v}
    if isinstance(v, int):
        return {'integerValue': str(v)}
    if isinstance(v, float):
        return {'doubleValue': v}
    if isinstance(v, str):
        return {'stringValue': v}
    if isinstance(v, list):
        return {'arrayValue': {'values': [to_value(x) for x in v]}}
    if isinstance(v, dict):
        return {'mapValue': {'fields': {k: to_value(x)
                                        for k, x in v.items()}}}
    raise TypeError(f'unseedable: {type(v)} {v!r}')


def get_doc(path):
    import urllib.error
    try:
        req = urllib.request.Request(
            f'{BASE}/{path}', headers={'Authorization': f'Bearer {TOKEN}'})
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def push(rid, doc):
    """MERGE the dish into Firestore via updateMask.

    A bare REST PATCH replaces the whole document — an earlier image-only
    push wiped ingredients/steps/servings from production. The mask makes
    this write touch exactly the fields the dish carries and nothing else.
    """
    fields = {k: to_value(v) for k, v in doc.items()}
    mask = '&'.join(f'updateMask.fieldPaths={name}' for name in fields)
    req = urllib.request.Request(
        f'{BASE}/recipes/{rid}?{mask}',
        data=json.dumps({'fields': fields}).encode(),
        method='PATCH', headers={
            'Authorization': f'Bearer {TOKEN}',
            'Content-Type': 'application/json',
        })
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode())


def verify_pushed(rid, doc):
    remote = get_doc(f'recipes/{rid}')
    if remote is None:
        return 'doc vanished after write'
    remote_fields = remote.get('fields', {})

    def unwrap(v):
        if 'mapValue' in v:
            return {k: unwrap(x)
                    for k, x in v['mapValue'].get('fields', {}).items()}
        if 'arrayValue' in v:
            return [unwrap(x)
                    for x in v['arrayValue'].get('values', [])]
        return next(iter(v.values()))

    def flat(fields, prefix=''):
        out = {}
        for k, v in fields.items():
            key = f'{prefix}.{k}' if prefix else k
            if 'mapValue' in v and 'fields' in v['mapValue']:
                out.update(flat(v['mapValue']['fields'], key))
            elif 'arrayValue' in v:
                out[key] = [unwrap(x)
                            for x in v['arrayValue'].get('values', [])]
            else:
                out[key] = next(iter(v.values()))
        return out

    def norm_eq(expected, got):
        """Content equality across Firestore's wire types: ints come back as
        strings in nested maps, and 2 == 2.0 is the same quantity."""
        if isinstance(expected, dict):
            if not isinstance(got, dict) or set(expected) - set(got):
                return False
            return all(norm_eq(v, got[k]) for k, v in expected.items())
        if isinstance(expected, list):
            return (isinstance(got, list) and len(expected) == len(got)
                    and all(norm_eq(e, g) for e, g in zip(expected, got)))
        if expected is None:
            return got is None
        if isinstance(expected, bool):
            return got is expected
        if isinstance(expected, (int, float)):
            try:
                return got is not None and float(got) == float(expected)
            except (TypeError, ValueError):
                return False
        return expected == got

    flat_remote = flat(remote_fields)
    for key, expected in doc.items():
        if not norm_eq(expected, flat_remote.get(key)):
            return (f"field '{key}' came back "
                    f"{flat_remote.get(key)!r}, expected {expected!r}")
    return None


# --- auth (mirrors seed_production.py) ---------------------------------------

TOKEN_PATH = '/tmp/flameup_access_token.txt'
CONFIGSTORE = ('/Users/mattathiasa/.config/configstore/'
               'firebase-tools.json')


def access_token():
    try:
        tok = open(TOKEN_PATH).read().strip()
        req = urllib.request.Request(
            f'https://firebase.googleapis.com/v1beta1/projects/{PROJECT}',
            headers={'Authorization': f'Bearer {tok}'})
        urllib.request.urlopen(req, timeout=15)
        return tok
    except Exception:
        pass
    import subprocess
    subprocess.run(['firebase', 'projects:list'],
                   capture_output=True, timeout=120)
    tok = json.load(open(CONFIGSTORE))['tokens']['access_token']
    open(TOKEN_PATH, 'w').write(tok)
    return tok


TOKEN = access_token()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--dry', action='store_true',
                    help='validate + build only; no push')
    ap.add_argument('--no-push', action='store_true',
                    help='validate + build + image upload, no push')
    args = ap.parse_args()

    extras = load_extras()
    if extras is None:
        return

    print('validating…')
    bad = collect_problems(extras)
    if bad:
        err(f'{bad} dish(es) failed validation')

    # Local image files become Cloudinary URLs before the build.
    for rid, dish in extras.items():
        img = dish.get('imageUrl') or ''
        if img and not img.startswith('https://'):
            if args.dry:
                print(f'  (dry) would upload {os.path.basename(img)} for '
                      f'{rid}')
                continue
            print(f'  uploading {os.path.basename(img)} → Cloudinary…')
            url = upload_image(img)
            dish['imageUrl'] = url
            with open(EXTRAS_PATH, 'w', encoding='utf-8') as fh:
                json.dump(extras, fh, ensure_ascii=False, indent=2)
                fh.write('\n')
            print(f'  ✓ {rid}: {url[:70]}…')

    print('building seed…')
    run_build()
    seed = json.load(open(SEED_PATH, encoding='utf-8'))
    recipes = seed['recipes']
    missing = [rid for rid in extras if rid not in recipes]
    if missing:
        err(f'build did not produce: {missing} — check build_seed merge')

    if args.dry or args.no_push:
        print('dry run: seed is valid and builds; nothing pushed')
        return

    print('pushing to production…')
    for rid in extras:
        doc = dict(recipes[rid])
        doc['id'] = rid
        doc['status'] = 'published'
        doc['searchTokens'] = search_tokens(doc)
        push(rid, doc)
        problem = verify_pushed(rid, doc)
        if problem:
            err(f'{rid}: {problem}')
        print(f'  ✓ {rid} pushed and verified')
    print('done.')


if __name__ == '__main__':
    main()
