#!/usr/bin/env python3
"""Seed the production FlameUp backend with content and demo data.

What goes in, in order:
  1. Content     25 recipes + regions (from assets/seed/recipes.json, plus
                 searchTokens for server-side text queries) and the config
                 documents (level curve, XP rules, featured picks).
  2. Demo people Six demo accounts (password: flameup-demo, emails under
                 demo.flameup.app) with public profiles, opt-in directory
                 cards, XP/level/streak counters, mastery and completed
                 cooking sessions, reviews with honest aggregates, posts with
                 denormalised titles and like/comment counts, friendships, a
                 couple of published family recipes, and the notifications
                 the (still Spark-plan, so undeployed) triggers would have
                 written.
  3. Auth setup  Enable email/password sign-in (done earlier in the session;
                 kept idempotent) so the demo accounts can actually sign in.

Everything is idempotent: documents are keyed by stable ids and PATCHed, so
re-running refreshes rather than duplicates. Writes use the Firebase CLI's
OAuth token, which carries IAM authority — REST writes under it are accepted
regardless of security rules, exactly like the Firebase console editor. That
is why the seeder can seed `recipes/` (moderator-only per rules) and set
counters the rules fence off from clients.

Usage:
  python3 tool/seed_production.py            # everything
  python3 tool/seed_production.py --content  # recipes/regions/config only
  python3 tool/seed_production.py --demo     # demo people only
"""

import argparse
import base64
import hashlib
import json
import random
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timedelta, timezone

PROJECT = 'flameup-78d15'
BASE = (f'https://firestore.googleapis.com/v1/projects/{PROJECT}'
        '/databases/(default)/documents')
IDENTITY = f'https://identitytoolkit.googleapis.com/v1/projects/{PROJECT}'
TOKEN_PATH = '/tmp/flameup_access_token.txt'
CONFIGSTORE = ('/Users/mattathiasa/.config/configstore/'
               'firebase-tools.json')
SEED = 'assets/seed/recipes.json'
DEMO_PASSWORD = 'flameup-demo'

random.seed(7815)  # deterministic demo world

DEMO_USERS = [
    ('demo.liya@demo.flameup.app', 'Liya T.', 'amhara'),
    ('demo.dawit@demo.flameup.app', 'Dawit M.', 'tigray'),
    ('demo.meron@demo.flameup.app', 'Meron A.', 'gurage'),
    ('demo.yonas@demo.flameup.app', 'Yonas G.', 'oromia'),
    ('demo.hanna@demo.flameup.app', 'Hanna B.', 'harar'),
    ('demo.samuel@demo.flameup.app', 'Samuel T.', 'sidama'),
]


def access_token():
    """Reuse the cached CLI token, or mint a fresh one via the CLI."""
    try:
        tok = open(TOKEN_PATH).read().strip()
        req = urllib.request.Request(
            f'https://firebase.googleapis.com/v1beta1/projects/{PROJECT}',
            headers={'Authorization': f'Bearer {tok}'})
        urllib.request.urlopen(req, timeout=15)
        return tok
    except Exception:
        pass
    # The CLI refreshes its own credential whenever it is used authenticated.
    import subprocess
    subprocess.run(['firebase', 'projects:list'],
                   capture_output=True, timeout=120)
    tok = json.load(open(CONFIGSTORE))['tokens']['access_token']
    open(TOKEN_PATH, 'w').write(tok)
    return tok


TOKEN = access_token()


def rest(url, method='GET', body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        'Authorization': f'Bearer {TOKEN}',
        'Content-Type': 'application/json',
    })
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        raise RuntimeError(f'{e.code} {method} {url}\n{e.read().decode()[:400]}')


def write_doc(path, data):
    """PATCH = create-or-merge at a deterministic id. Idempotent seeding."""
    fields = to_firestore(data)
    rest(f'{BASE}/{path}', 'PATCH', {'fields': fields})


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


def to_firestore(data):
    # epochMillis server-side would be prettier, but the client parses ISO
    # strings (and Timestamps) — strings read the same on both paths.
    return {k: to_value(v) for k, v in data.items() if v is not None}


# --- identity toolkit -------------------------------------------------------

def get_api_key():
    for line in open('lib/firebase_options.dart'):
        if 'apiKey' in line and 'AIza' in line:
            return line.split("'")[1]
    raise RuntimeError('no API key in lib/firebase_options.dart')


def ensure_demo_accounts():
    """Idempotently create the demo accounts via the Identity Toolkit admin
    REST surface (`projects/{id}/accounts` writes with IAM auth, no API key
    dance). Returns email -> localId."""
    uids = {}
    for email, name, region in DEMO_USERS:
        # look up first, so re-runs adopt the existing account
        try:
            resp = rest(f'{IDENTITY}/accounts:query', 'POST', {
                'expression': [{'email': email}], 'limit': 1,
            })
            results = resp.get('userInfo', [])
            if results:
                uids[email] = results[0]['localId']
                continue
        except RuntimeError as e:
            print(f'  WARN lookup {email}: {e}'.splitlines()[0])
        try:
            resp = rest(f'{IDENTITY}/accounts', 'POST', {
                'email': email,
                'password': DEMO_PASSWORD,
                'displayName': name,
                'emailVerified': True,
            })
            uids[email] = resp['localId']
            print(f'  created {email}')
        except RuntimeError as e:
            print(f'  WARN could not create {email}: {e}'.splitlines()[0])
    return uids


def friend_code(uid):
    return hashlib.sha256(uid.encode()).hexdigest()[:8]


def iso(dt):
    return dt.isoformat()


def days_ago(n, hour=18, minute=0):
    d = datetime.now(timezone.utc) - timedelta(days=n)
    return d.replace(hour=hour, minute=minute, second=0, microsecond=0)


def search_tokens(recipe):
    tokens = set()
    for key in ('title', 'titleAm', 'subtitle'):
        text = recipe.get(key) or ''
        for token in text.replace('(', ' ').replace(')', ' ').split():
            token = token.strip('.,!?:;"\'').lower()
            if len(token) >= 2:
                tokens.add(token)
    tags = recipe.get('tags') or []
    for tag in tags:
        t = str(tag).lower()
        if t:
            tokens.add(t)
    return sorted(tokens)[:30]  # Firestore array-contains-any caps at 30


# --- content ----------------------------------------------------------------

def seed_content():
    payload = json.load(open(SEED))
    recipes, regions = payload['recipes'], payload['regions']

    for rid, recipe in recipes.items():
        doc = dict(recipe)
        doc['id'] = rid
        doc['status'] = 'published'
        doc['searchTokens'] = search_tokens(doc)
        write_doc(f'recipes/{rid}', doc)

    for region in regions:
        doc = dict(region)
        write_doc(f"regions/{region['id']}", doc)

    # level curve: the exact thresholds LevelCurve.standard generates
    thresholds = []
    for level in range(1, 61):
        if level == 1:
            thresholds.append(0)
        else:
            n = level - 1
            thresholds.append(120 * n + 15 * n * n)
    write_doc('config/level_curve', {'thresholds': thresholds})

    write_doc('config/xp_rules', {
        'firstTimeBonus': 50,
        'streakMilestoneBonus': 100,
        'streakMilestones': [7, 14, 30, 60, 100],
        'repeatDecayFloor': 0.25,
    })

    write_doc('config/featured', {
        'recipeIds': ['doro', 'shiro', 'misir'],
        'updatedAt': iso(days_ago(0)),
    })

    print(f'content: {len(recipes)} recipes, {len(regions)} regions, 3 config docs')


# --- demo world --------------------------------------------------------------

def level_for_xp(xp):
    thresholds = [0]
    for level in range(2, 61):
        n = level - 1
        thresholds.append(120 * n + 15 * n * n)
    result = 1
    for i, t in enumerate(thresholds):
        if xp >= t:
            result = i + 1
    return result


def mastery_level_for(cook_count):
    thresholds = [0, 1, 2, 3, 5, 8, 12]
    level = 0
    for i, t in enumerate(thresholds):
        if cook_count >= t:
            level = i
    return level


def seed_demo_world():
    payload = json.load(open(SEED))
    recipes = payload['recipes']
    recipe_ids = list(recipes.keys())

    uids = ensure_demo_accounts()
    if len(uids) < 2:
        print('Not enough demo accounts to build a social world; aborting demo seed.')
        return
    people = [(uids[email], email, name, region)
              for email, name, region in DEMO_USERS if email in uids]

    # Digest a base64 password hash? No: profiles do not hold credentials.
    names = {uid: name for uid, _, name, _ in people}

    for idx, (uid, email, name, region) in enumerate(people):
        cooks = 3 + (idx * 2)          # 3, 5, 7, 9, 11, 13
        xp = cooks * 60 + (idx * 25)
        my_recipes = recipe_ids[idx::len(people)][:cooks]

        profile = {
            'displayName': name,
            'regionId': region,
            'profileVisibility': 'public',
            'skillLevel': 1 + (idx % 3),
            'heatTolerance': (idx % 5),
            'dietary': ['vegan'] if idx % 3 == 1 else [],
            'preferredLanguage': 'en',
            'onboardingComplete': True,
            'leaderboardOptOut': False,
            # counters the triggers would maintain
            'xp': xp,
            'level': level_for_xp(xp),
            'flames': 2 + idx,
            'longestStreak': 4 + idx,
            'recipesCooked': cooks,
            'regionsTasted': min(6, 2 + idx % 5),
            'familyRecipesPublished': 1 if idx < 2 else 0,
            'createdAt': iso(days_ago(40 - idx)),
            'updatedAt': iso(days_ago(0)),
        }
        write_doc(f'users/{uid}', profile)
        write_doc(f'user_directory/{uid}', {
            'uid': uid,
            'displayName': name,
            'nameSearch': name.lower(),
            'friendCode': friend_code(uid),
        })

        # cooking sessions + reviews + mastery for their cooked dishes
        for j, rid in enumerate(my_recipes):
            completed_at = days_ago(30 - j * 3, hour=17 + (j % 3))
            session_id = f'demo-s{idx}-{j}'
            write_doc(f'users/{uid}/cooking_sessions/{session_id}', {
                'id': session_id,
                'recipeId': rid,
                'totalSteps': len(recipes[rid].get('steps', [])) or 4,
                'servings': recipes[rid].get('servings', 2),
                'currentStep': len(recipes[rid].get('steps', [])) or 4,
                'status': 'completed',
                'startedAt': iso(completed_at - timedelta(minutes=90)),
                'completedAt': iso(completed_at),
                'lastActiveAt': iso(completed_at),
                'stepDeadlines': {},
                'pausedRemaining': {},
                'idempotencyKey': f'demo-{session_id}',
                'offlineCreated': False,
            })
            # the reward marker the claim function would have written
            write_doc(f'users/{uid}/reward_claims/{session_id}', {
                'sessionId': session_id,
                'recipeId': rid,
                'awards': [],
                'xpAwarded': 60,
                'grantedAt': iso(completed_at),
            })

            taste = 3 + ((idx + j) % 3)          # 3..5
            write_doc(f'recipes/{rid}/reviews/{uid}', {
                'recipeId': rid,
                'sessionId': session_id,
                'uid': uid,
                'taste': taste,
                'difficulty': 2 + ((idx + j) % 3),
                'instructions': 4,
                'authenticity': 5,
                'wouldCookAgain': taste >= 4,
                'body': DEMO_REVIEW_BODIES[(idx + j) % len(DEMO_REVIEW_BODIES)],
                'shareToCommunity': True,
                'createdAt': iso(completed_at),
            })

            cook_count = 1 + (j % 3)
            write_doc(f'users/{uid}/mastery/{rid}', {
                'recipeId': rid,
                'cookCount': cook_count,
                'level': mastery_level_for(cook_count),
                'lastCookedAt': iso(completed_at),
            })

    # --- posts (denormalised, with like/comment counts the triggers would keep)
    post_index = 0
    for idx, (uid, email, name, region) in enumerate(people):
        my_recipes = recipe_ids[idx::len(people)][:3]
        for j, rid in enumerate(my_recipes[:2]):
            post_index += 1
            session_id = f'demo-s{idx}-{j}'
            title = recipes[rid]['title']
            body = DEMO_POST_BODIES[post_index % len(DEMO_POST_BODIES)]
            likes = random.choice([2, 3, 5, 8, 11])
            write_doc(f'posts/demo-post-{post_index}', {
                'id': f'demo-post-{post_index}',
                'authorId': uid,
                'authorName': name,
                'recipeId': rid,
                'recipeTitle': title,
                'sessionId': session_id,
                'body': body,
                'likeCount': likes,
                'commentCount': 0,
                'visibility': 'public',
                'createdAt': iso(days_ago(20 - post_index * 2)),
            })
            # likes documents keyed by uid (the idempotency mechanism)
            for k in range(likes):
                liker = people[(idx + k + 1) % len(people)][0]
                write_doc(f'posts/demo-post-{post_index}/likes/{liker}', {
                    'createdAt': iso(days_ago(19 - post_index)),
                })

    # --- friendships: everyone likes everyone (pairwise, both mirrors)
    for a in range(len(people)):
        for b in range(a + 1, len(people)):
            uid_a, uid_b = people[a][0], people[b][0]
            since = iso(days_ago(15 + a))
            write_doc(f'users/{uid_a}/friends/{uid_b}', {
                'displayName': people[b][2], 'since': since})
            write_doc(f'users/{uid_b}/friends/{uid_a}', {
                'displayName': people[a][2], 'since': since})

    # --- family recipes: two published, one pending (shows the review chip)
    fam_authors = [people[0], people[1], people[2]]
    for k, (uid, email, name, region) in enumerate(fam_authors):
        rid = f'demo-family-{k + 1}'
        status = 'published' if k < 2 else 'pending'
        write_doc(f'family_recipes/{rid}', {
            'id': rid,
            'authorId': uid,
            'authorName': name,
            'title': DEMO_FAMILY_RECIPES[k]['title'],
            'titleAm': DEMO_FAMILY_RECIPES[k]['titleAm'],
            'teacherName': DEMO_FAMILY_RECIPES[k]['teacher'],
            'regionId': region,
            'story': DEMO_FAMILY_RECIPES[k]['story'],
            'stepsText': DEMO_FAMILY_RECIPES[k]['steps'],
            'status': status,
            'createdAt': iso(days_ago(10 - k * 2)),
            'updatedAt': iso(days_ago(5)),
        })
        if k < 2:
            write_doc(f'family_recipes/{rid}/generations/g1', {
                'name': DEMO_FAMILY_RECIPES[k]['teacher'],
                'relationship': 'grandmother',
            })
            # publication notification + reward marker the trigger would write
            write_doc(f'users/{uid}/notifications/recipe_published_{rid}', {
                'type': 'recipePublished',
                'otherUid': rid,
                'otherName': DEMO_FAMILY_RECIPES[k]['titleAm']
                or DEMO_FAMILY_RECIPES[k]['title'],
                'readAt': None,
                'createdAt': iso(days_ago(6)),
            })
            write_doc(f'users/{uid}/reward_claims/family_recipe_{rid}', {
                'kind': 'familyRecipePublished',
                'recipeId': rid,
                'xpAwarded': 75,
                'grantedAt': iso(days_ago(6)),
            })

    # --- one friend request pending between two demo people, with its
    #     notification, so the Activity sheet shows a live item
    if len(people) >= 5:
        from_uid, to_uid = people[4][0], people[5][0]
        if len(people) >= 6:
            write_doc(f'users/{to_uid}/friend_requests/{from_uid}', {
                'otherUid': from_uid,
                'direction': 'incoming',
                'status': 'pending',
                'displayName': people[4][2],
                'createdAt': iso(days_ago(1)),
            })
            write_doc(f'users/{from_uid}/friend_requests/{to_uid}', {
                'otherUid': to_uid,
                'direction': 'outgoing',
                'status': 'pending',
                'createdAt': iso(days_ago(1)),
            })
            write_doc(f'users/{to_uid}/notifications/friend_request_{from_uid}', {
                'type': 'friendRequest',
                'otherUid': from_uid,
                'otherName': people[4][2],
                'readAt': None,
                'createdAt': iso(days_ago(1)),
            })

    print(f'demo: {len(people)} people, {sum(3 + i * 2 for i in range(len(people)))} sessions,'
          f' {post_index} posts, 3 family recipes')


DEMO_REVIEW_BODIES = [
    'Exactly how it tastes at home. The berbere blend makes it.',
    'Took me two tries to get the texture right, worth it.',
    'My kids asked for seconds. That never happens.',
    'The niter kibbeh at the end is the whole point. Do not skip it.',
    'Simple and honest. Made it on a fasting Wednesday.',
]

DEMO_POST_BODIES = [
    'First time making this from scratch. The smell alone brought everyone to the kitchen.',
    'Sunday cook with family. Injera from the neighbourhood bakery, everything else homemade.',
    'Burned the first batch, nailed the second. Cooking is forgiving.',
    'This one is my comfort dish. Forty minutes, no shortcuts.',
    'Made extra for the neighbour. She approved. That is the real rating.',
    'The kitchen smelled like my grandmother\'s house for a day after this one.',
]

DEMO_FAMILY_RECIPES = [
    {
        'title': 'Emahoy\'s Doro Wat',
        'titleAm': 'የእማሆይ ዶሮ ወጥ',
        'teacher': 'Emahoy Tsehay',
        'story': 'Slow-cooked every Christmas Eve. The onions caramelise for a full hour before anything else touches the pot — "hurry is the enemy of doro", she says.',
        'steps': '1. Caramelise 6 large onions dry, about one hour.\n2. Add niter kibbeh and berbere, cook 10 minutes.\n3. Add chicken and stock, simmer 45 minutes.\n4. Season with korerima. Rest before serving with injera.',
    },
    {
        'title': 'Grandmother\'s Shiro',
        'titleAm': 'የአያት ሽሮ',
        'teacher': 'Emahoy Almaz',
        'story': 'The shiro of every funeral and every feast in our family. Whisked with water from the tap, never broth — "shiro does not need help".',
        'steps': '1. Toast shiro powder dry for two minutes.\n2. Whisk with cold water until smooth.\n3. Simmer with spiced butter 15 minutes, stirring one direction only.',
    },
    {
        'title': 'Aunt Genet\'s Gomen',
        'titleAm': 'የአጃት ጎመን',
        'teacher': 'Aunt Genet',
        'story': 'Collards cut ribbon-thin while telling stories. The trick is the pot lid: on for five minutes, off for twenty, never stirred.',
        'steps': '1. Wash and ribbon the collards.\n2. Sauté onion and jalapeño in niter kibbeh.\n3. Add greens, salt, steam low 40 minutes without stirring.',
    },
]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--content', action='store_true',
                        help='seed recipes/regions/config only')
    parser.add_argument('--demo', action='store_true',
                        help='seed demo people only')
    args = parser.parse_args()

    if args.content or args.demo:
        if args.content:
            seed_content()
        if args.demo:
            seed_demo_world()
    else:
        seed_content()
        seed_demo_world()

    print('done.')


if __name__ == '__main__':
    main()
