import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { deleteDoc, doc, getDoc, setDoc } from 'firebase/firestore';

import {
  asUser,
  assertFails,
  assertSucceeds,
  createTestEnv,
  seed,
} from './helpers.js';

describe('friendships are writable by both parties', () => {
  let env;

  beforeAll(async () => {
    env = await createTestEnv();
  });

  afterAll(async () => {
    await env.cleanup();
  });

  beforeEach(() => env.clearFirestore());

  it('accepting a request writes the mirror into the other side (rules regression)', async () => {
    // The pre-fix rules allowed only isOwner(uid) on friends/{otherUid}, so
    // the client's acceptFriendRequest -- which writes both mirrors in one
    // batch -- was denied in production before it ever ran.
    await assertSucceeds(
      setDoc(doc(asUser(env, 'liya'), 'users/dawit/friends/liya'), {
        displayName: 'Liya',
        since: '2026-09-14T00:00:00.000',
      }),
    );
  });

  it('removing a friend deletes the other side too', async () => {
    await seed(env, async (db) => {
      await setDoc(doc(db, 'users/dawit/friends/liya'), {
        displayName: 'Liya',
      });
    });
    await assertSucceeds(
      deleteDoc(doc(asUser(env, 'liya'), 'users/dawit/friends/liya')),
    );
  });

  it('neither party can write a document keyed as someone else', async () => {
    // The grant is "you may manage the document that represents YOU inside
    // the other person's list" -- not blanket access to their list.
    await assertFails(
      setDoc(doc(asUser(env, 'liya'), 'users/dawit/friends/meron'), {
        displayName: 'Meron',
      }),
    );
  });

  it('a stranger cannot key a document as a third party in anyone\'s list', async () => {
    // meron may manage "meron" inside dawit's list (the mirror grant) and
    // everything inside meron's own list -- but a document keyed as liya is
    // neither, and must be denied.
    await assertFails(
      setDoc(doc(asUser(env, 'meron'), 'users/dawit/friends/liya'), {
        displayName: 'Liya',
      }),
    );
  });

  it('friend lists stay private to their owner for reads', async () => {
    await seed(env, async (db) => {
      await setDoc(doc(db, 'users/dawit/friends/liya'), {
        displayName: 'Liya',
      });
    });
    // Even the friend named in the document cannot read the other side's list.
    await assertFails(
      getDoc(doc(asUser(env, 'liya'), 'users/dawit/friends/liya')),
    );
  });
});

describe('notifications are server-written, client-read', () => {
  let env;

  beforeAll(async () => {
    env = await createTestEnv();
  });

  afterAll(async () => {
    await env.cleanup();
  });

  beforeEach(() => env.clearFirestore());

  it('the owner can read their notifications', async () => {
    await seed(env, async (db) => {
      await setDoc(doc(db, 'users/liya/notifications/n1'), {
        type: 'friendRequest',
        otherUid: 'dawit',
      });
    });
    await assertSucceeds(
      getDoc(doc(asUser(env, 'liya'), 'users/liya/notifications/n1')),
    );
  });

  it('nobody else can read them', async () => {
    await seed(env, async (db) => {
      await setDoc(doc(db, 'users/liya/notifications/n1'), {
        type: 'friendRequest',
      });
    });
    await assertFails(
      getDoc(doc(asUser(env, 'dawit'), 'users/liya/notifications/n1')),
    );
  });

  it('a signed-in client cannot forge a notification', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'dawit'), 'users/liya/notifications/forged'), {
        type: 'friendRequest',
        otherUid: 'dawit',
        otherName: 'Dawit',
      }),
    );
  });

  it('the owner cannot forge one either, including into their own list', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'liya'), 'users/liya/notifications/self'), {
        type: 'friendAdded',
        otherUid: 'dawit',
      }),
    );
  });

  it('marking read is the only client write', async () => {
    await seed(env, async (db) => {
      await setDoc(doc(db, 'users/liya/notifications/n1'), {
        type: 'friendRequest',
        readAt: null,
      });
    });
    await assertSucceeds(
      setDoc(
        doc(asUser(env, 'liya'), 'users/liya/notifications/n1'),
        { readAt: '2026-09-14T10:00:00.000' },
        { merge: true },
      ),
    );
  });
});
