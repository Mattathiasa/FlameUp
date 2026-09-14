import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { doc, getDoc, setDoc } from 'firebase/firestore';

import {
  asUser,
  asVisitor,
  assertFails,
  assertSucceeds,
  createTestEnv,
  seed,
} from './helpers.js';

describe('the user directory is findable but not writable by strangers', () => {
  let env;

  beforeAll(async () => {
    env = await createTestEnv();
  });

  afterAll(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await seed(env, async (db) => {
      // Liya has published a card; dawit's card is malformed so a reader must
      // tolerate it rather than have the rules care.
      await setDoc(doc(db, 'user_directory/liya'), {
        uid: 'liya',
        displayName: 'Liya Kebede',
        nameSearch: 'liya kebede',
        friendCode: 'deadbeef',
      });
      await setDoc(doc(db, 'user_directory/dawit'), {
        uid: 'dawit',
        friendCode: '12345678',
      });
    });
  });

  it('a signed-in user can read any card', async () => {
    await assertSucceeds(
      getDoc(doc(asUser(env, 'meron'), 'user_directory/liya')),
    );
  });

  it('a signed-out visitor cannot', async () => {
    await assertFails(getDoc(doc(asVisitor(env), 'user_directory/liya')));
  });

  it('an owner may publish their own card', async () => {
    await assertSucceeds(
      setDoc(doc(asUser(env, 'meron'), 'user_directory/meron'), {
        uid: 'meron',
        displayName: 'Meron Alemu',
        nameSearch: 'meron alemu',
        friendCode: 'cafe1234',
      }),
    );
  });

  it('a card must not claim another uid', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'meron'), 'user_directory/meron'), {
        uid: 'liya',
        displayName: 'Fake Liya',
        nameSearch: 'fake liya',
        friendCode: 'cafe1234',
      }),
    );
  });

  it('a stranger may never write someone else\'s card', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'meron'), 'user_directory/liya'), {
        uid: 'liya',
        displayName: 'Hacked Name',
        nameSearch: 'hacked name',
        friendCode: 'deadbeef',
      }),
    );
  });

  it('a card may not smuggle unexpected fields', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'meron'), 'user_directory/meron'), {
        uid: 'meron',
        displayName: 'Meron Alemu',
        nameSearch: 'meron alemu',
        friendCode: 'cafe1234',
        xp: 9999,
      }),
    );
  });

  it('the friend code must be eight characters', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'meron'), 'user_directory/meron'), {
        uid: 'meron',
        displayName: 'Meron Alemu',
        nameSearch: 'meron alemu',
        friendCode: 'nope',
      }),
    );
  });

  it('a card must carry a non-empty name within the size cap', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'meron'), 'user_directory/meron'), {
        uid: 'meron',
        displayName: '',
        nameSearch: '',
        friendCode: 'cafe1234',
      }),
    );
  });

  it('the owner may update their own card', async () => {
    await assertSucceeds(
      setDoc(doc(asUser(env, 'liya'), 'user_directory/liya'), {
        uid: 'liya',
        displayName: 'Liya K.',
        nameSearch: 'liya k.',
        friendCode: 'deadbeef',
      }),
    );
  });

  it('a malformed card still exists as a document for tolerant readers', async () => {
    // The rules do not judge shape on documents seeded outside them; the
    // client's fromJson filters these. The assertion is that reading one is
    // permitted, not that its contents pass validation.
    const snapshot = await getDoc(doc(asUser(env, 'meron'), 'user_directory/dawit'));
    await assertSucceeds(Promise.resolve(snapshot));
  });
});
