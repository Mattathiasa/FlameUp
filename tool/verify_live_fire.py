#!/usr/bin/env python3
"""Live-fire the community verification loop against PRODUCTION.

Exactly the writes the app makes, under the deployed rules:
  1. Sign in as demo.liya  -> submit a pending family recipe (the payload
     shape the app's form writes).
  2. Sign in as dawit/meron/yonas -> vouch, one per person, the same write
     the verify() repository method sends.
  3. Dawit (already vouched) tries again -> must be DENIED by the rules.
  4. Liya (the author) tries to vouch for her own -> must be DENIED.
  5. After the third vouch, the recipe must have published ITSELF.

Everything is keyed to this run and cleaned up at the end.
"""

import json
import sys
import urllib.request

PROJECT = 'flameup-78d15'
FIRESTORE = f'https://firestore.googleapis.com/v1/projects/{PROJECT}/databases/(default)/documents'
IDENTITY = f'https://identitytoolkit.googleapis.com/v1/projects/{PROJECT}'
PASSWORD = 'flameup-demo'

RUN_TAG = 'lifefire-verify'


def get_api_key():
    for line in open('lib/firebase_options.dart'):
        if 'apiKey' in line and 'AIza' in line:
            return line.split("'")[1]
    raise RuntimeError('no API key in lib/firebase_options.dart')


API_KEY = get_api_key()


def rest(url, method, payload, token=None):
    headers = {'Content-Type': 'application/json'}
    if token:
        headers['Authorization'] = f'Bearer {token}'
    body = None if method == 'GET' else json.dumps(payload).encode()
    req = urllib.request.Request(
        url,
        data=body,
        headers=headers,
        method=method,
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        raise RuntimeError(f'{e.code}: {body[:400]}')


def sign_in(email):
    resp = rest(
        f'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key={API_KEY}',
        'POST',
        {'email': email, 'password': PASSWORD, 'returnSecureToken': True},
    )
    return resp['idToken'], resp['localId']


def doc_path(path):
    return f'{FIRESTORE}/{path}'


def get_doc(path, token):
    return rest(doc_path(path), 'GET', {}, token)


def create_doc(path, fields, token):
    return rest(doc_path(path), 'POST', {'fields': fields}, token)


def patch_doc(path, fields, token):
    # Field-masked update, exactly what the Flutter SDK's update() sends:
    # only the masked fields change, the rest of the document stays — so
    # incoming() in the rules still carries authorId/status/etc.
    mask = '&'.join(
        f'updateMask.fieldPaths={name}' for name in fields
    )
    return rest(doc_path(path) + f'?{mask}', 'PATCH',
                {'fields': fields}, token)


def to_value(v):
    if isinstance(v, bool):
        return {'booleanValue': v}
    if isinstance(v, int):
        return {'integerValue': str(v)}
    if isinstance(v, str):
        return {'stringValue': v}
    if isinstance(v, list):
        return {'arrayValue': {'values': [to_value(x) for x in v]}}
    raise TypeError(f'unsupported {type(v)}')


def from_value(value):
    if 'stringValue' in value:
        return value['stringValue']
    if 'integerValue' in value:
        return int(value['integerValue'])
    if 'booleanValue' in value:
        return value['booleanValue']
    if 'arrayValue' in value:
        return [from_value(v) for v in value['arrayValue'].get('values', [])]
    return None


def expect(condition, label):
    print(f'  {"PASS" if condition else "FAIL"}  {label}')
    if not condition:
        sys.exit(1)


def main():
    # 1. Author signs in and submits a pending recipe.
    liya_token, liya_uid = sign_in('demo.liya@demo.flameup.app')
    print(f'author uid: {liya_uid}')

    recipe_id = f'{RUN_TAG}-{abs(hash(RUN_TAG)) % 100000}'
    payload = {
        'authorId': liya_uid,
        'status': 'pending',
        'title': 'Live-fire berbere',
        'titleAm': '',
        'teacherName': 'Emahoy Tsehay',
        'story': 'Created by the automated live-fire test; deleted at the end.',
        'stepsText': 'Toast the spices.\nGrind.',
        'ingredientsText': 'chili\ngarlic',
        'regionId': 'amhara',
        'teacherNote': '',
        'verifiedBy': [],
    }
    create_doc(f'family_recipes?documentId={recipe_id}',
               {k: to_value(v) for k, v in payload.items()}, liya_token)
    print(f'submitted pending recipe: {recipe_id}')

    # 2. Three cooks vouch, one write each — the same write verify() sends.
    # On the threshold vouch the write also flips status to published: the
    # rules verify (never mutate) the transition, so the client must send it.
    vouched = []
    for email in ('demo.dawit@demo.flameup.app',
                  'demo.meron@demo.flameup.app',
                  'demo.yonas@demo.flameup.app'):
        token, uid = sign_in(email)
        vouched.append(uid)
        fields = {
            'verifiedBy':
                {'arrayValue': {'values': [to_value(u) for u in vouched]}},
        }
        if len(vouched) >= 3:
            fields['status'] = to_value('published')
        patch_doc(f'family_recipes/{recipe_id}', fields, token)
        print(f'  vouch {len(vouched)}/3 by {email.split("@")[0]} ({uid[:8]}…)')

        # Double-vouch must be denied.
        if len(vouched) == 1:
            try:
                patch_doc(
                    f'family_recipes/{recipe_id}',
                    {'verifiedBy': {'arrayValue': {'values': [to_value(uid), to_value(uid)]}}},
                    token,
                )
                expect(False, 'double vouch must be denied')
            except RuntimeError:
                expect(True, 'double vouch denied by rules')

    # 3. The author cannot vouch for their own.
    try:
        patch_doc(
            f'family_recipes/{recipe_id}',
            {'verifiedBy': {'arrayValue': {'values': [to_value(u) for u in vouched + [liya_uid]]}}},
            liya_token,
        )
        expect(False, 'author self-vouch must be denied')
    except RuntimeError:
        expect(True, 'author self-vouch denied by rules')

    # 4. The third vouch must have published it — no server involved.
    doc = get_doc(f'family_recipes/{recipe_id}', liya_token)['fields']
    status = from_value(doc['status'])
    verified = from_value(doc['verifiedBy'])
    expect(status == 'published', f'auto-published on 3rd vouch (status={status})')
    expect(verified == vouched, f'vouches preserved exactly: {verified}')

    # 5. Cleanup: author deletes the proof document.
    rest(doc_path(f'family_recipes/{recipe_id}'), 'DELETE', {}, liya_token)
    print(f'cleaned up {recipe_id}')
    print('LIVE FIRE: ALL GREEN')


if __name__ == '__main__':
    main()
