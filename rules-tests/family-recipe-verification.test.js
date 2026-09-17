import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import {
  doc,
  getDoc,
  runTransaction,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

import {
  asModerator,
  asUser,
  assertFails,
  assertSucceeds,
  createTestEnv,
  seed,
} from './helpers.js';

// ---------------------------------------------------------------------------
// Community verification + recipe versions.
//
// The archive moderates itself: a pending recipe publishes when three
// DIFFERENT cooks — never the author — append their uid to verifiedBy. The
// rules prove the append (one element, own uid only, nothing else changes);
// these tests try to break that from every angle.
// ---------------------------------------------------------------------------

const BASE = {
  authorId: 'liya',
  status: 'pending',
  title: 'Berbere from scratch',
};

const PENDING_ID = 'pending-1';
const DRAFT_ID = 'draft-1';

describe('community verification', () => {
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
      await setDoc(doc(db, 'family_recipes', PENDING_ID), { ...BASE });
      await setDoc(doc(db, 'family_recipes', DRAFT_ID), {
        ...BASE,
        authorId: 'liya',
        status: 'draft',
      });
    });
  });

  it('a stranger can vouch by appending their uid', async () => {
    await assertSucceeds(
      updateDoc(doc(asUser(env, 'dawit'), 'family_recipes', PENDING_ID), {
        verifiedBy: ['dawit'],
      }),
    );
  });

  it('the vouch survives nothing else changing — the write is only verifiedBy', async () => {
    const db = asUser(env, 'dawit');
    const before = await getDoc(doc(db, 'family_recipes', PENDING_ID));

    await updateDoc(doc(db, 'family_recipes', PENDING_ID), {
      verifiedBy: ['dawit'],
    });

    const after = await getDoc(doc(db, 'family_recipes', PENDING_ID));
    const data = after.data();
    if (data.title !== before.data().title || data.status !== 'pending') {
      throw new Error('vouch must not alter content or status below threshold');
    }
  });

  it('the author cannot vouch for their own recipe', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'liya'), 'family_recipes', PENDING_ID), {
        verifiedBy: ['liya'],
      }),
    );
  });

  it('a user cannot vouch under someone else uid', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'dawit'), 'family_recipes', PENDING_ID), {
        verifiedBy: ['selam'],
      }),
    );
  });

  it('a user cannot vouch twice', async () => {
    const db = asUser(env, 'dawit');
    await assertSucceeds(
      updateDoc(doc(db, 'family_recipes', PENDING_ID), {
        verifiedBy: ['dawit'],
      }),
    );
    await assertFails(
      updateDoc(doc(db, 'family_recipes', PENDING_ID), {
        verifiedBy: ['dawit', 'dawit'],
      }),
    );
  });

  it('a user cannot vouch by replacing the array', async () => {
    const db = asUser(env, 'dawit');
    await assertSucceeds(
      updateDoc(doc(db, 'family_recipes', PENDING_ID), {
        verifiedBy: ['dawit'],
      }),
    );
    // Swap dawit for a friend: size unchanged, so not an append — must deny.
    await assertFails(
      updateDoc(doc(db, 'family_recipes', PENDING_ID), {
        verifiedBy: ['selam'],
      }),
    );
  });

  it('a user cannot shrink or clear the vouches', async () => {
    // Two independent vouches, each by its own uid — one write can only
    // ever append the writer's own element.
    await assertSucceeds(
      updateDoc(doc(asUser(env, 'dawit'), 'family_recipes', PENDING_ID), {
        verifiedBy: ['dawit'],
      }),
    );
    await assertSucceeds(
      updateDoc(doc(asUser(env, 'selam'), 'family_recipes', PENDING_ID), {
        verifiedBy: ['dawit', 'selam'],
      }),
    );
    // Shrink (dawit out) and clear: both are losses, both denied.
    await assertFails(
      updateDoc(doc(asUser(env, 'dawit'), 'family_recipes', PENDING_ID), {
        verifiedBy: ['selam'],
      }),
    );
    await assertFails(
      updateDoc(doc(asUser(env, 'selam'), 'family_recipes', PENDING_ID), {
        verifiedBy: [],
      }),
    );
  });

  it('a vouch cannot ride along with content edits', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'dawit'), 'family_recipes', PENDING_ID), {
        verifiedBy: ['dawit'],
        title: 'Not the recipe anymore',
      }),
    );
  });

  it('a draft cannot be vouched — only pending and published', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'dawit'), 'family_recipes', DRAFT_ID), {
        verifiedBy: ['dawit'],
      }),
    );
  });

  it('a signed-out visitor cannot vouch', async () => {
    await assertFails(
      updateDoc(doc(env.unauthenticatedContext().firestore(), 'family_recipes', PENDING_ID), {
        verifiedBy: ['anon'],
      }),
    );
  });

  it('three vouches publish the recipe — by the community, not a moderator', async () => {
    const id = 'publish-me';
    const db = (uid) => asUser(env, uid);
    await seed(env, async (sdb) => {
      await setDoc(doc(sdb, 'family_recipes', id), { ...BASE });
    });

    await assertSucceeds(
      updateDoc(doc(db('dawit'), 'family_recipes', id), {
        verifiedBy: ['dawit'],
      }),
    );
    await assertSucceeds(
      updateDoc(doc(db('selam'), 'family_recipes', id), {
        verifiedBy: ['dawit', 'selam'],
      }),
    );
    // The third vouch carries the auto-publish: verifiedBy grows AND the
    // status flips, in one write, exactly as the rules allow.
    await assertSucceeds(
      updateDoc(doc(db('abeni'), 'family_recipes', id), {
        verifiedBy: ['dawit', 'selam', 'abeni'],
        status: 'published',
      }),
    );

    const finalDoc = await getDoc(doc(db('dawit'), 'family_recipes', id));
    if (finalDoc.data().status !== 'published') {
      throw new Error('three vouches must publish');
    }
  });

  it('the author cannot fake the auto-publish flip with a self-vouch', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'liya'), 'family_recipes', PENDING_ID), {
        verifiedBy: ['liya'],
        status: 'published',
      }),
    );
  });

  it('two vouches cannot publish early', async () => {
    const id = 'early-1';
    await seed(env, async (sdb) => {
      await setDoc(doc(sdb, 'family_recipes', id), { ...BASE });
    });
    await assertSucceeds(
      updateDoc(doc(asUser(env, 'dawit'), 'family_recipes', id), {
        verifiedBy: ['dawit'],
      }),
    );
    // Only two vouches: the status flip must be denied.
    await assertFails(
      updateDoc(doc(asUser(env, 'selam'), 'family_recipes', id), {
        verifiedBy: ['dawit', 'selam'],
        status: 'published',
      }),
    );
  });

  it('a moderator can still publish directly', async () => {
    await assertSucceeds(
      updateDoc(doc(asModerator(env), 'family_recipes', PENDING_ID), {
        status: 'published',
      }),
    );
  });
});

// ---------------------------------------------------------------------------
// Versions — a submission may declare itself a version of another recipe.
// ---------------------------------------------------------------------------

describe('recipe versions', () => {
  let env;
  const FAMILY_BASE_ID = '11111111-2222-3333-4444-555555555555';

  beforeAll(async () => {
    env = await createTestEnv();
  });

  afterAll(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearFirestore();
    await seed(env, async (db) => {
      // A published family recipe to be a version of.
      await setDoc(doc(db, 'family_recipes', FAMILY_BASE_ID), {
        authorId: 'liya',
        status: 'published',
        title: 'Emahoy shiro',
      });
      // The catalogue dish variants attach to, and Dawit's proof-of-cook:
      // a completed session for exactly that dish in his own history.
      await setDoc(doc(db, 'recipes/doro-wat'), {
        title: 'Doro Wat',
        status: 'published',
      });
      await setDoc(
        doc(db, 'users/dawit/cooking_sessions/session-doro'),
        {
          recipeId: 'doro-wat',
          status: 'completed',
        },
      );
    });
  });

  it('a version of a published family recipe is submittable', async () => {
    await assertSucceeds(
      setDoc(doc(asUser(env, 'dawit'), 'family_recipes', 'variant-1'), {
        authorId: 'dawit',
        status: 'pending',
        title: 'Dawit shiro',
        baseId: FAMILY_BASE_ID,
        variantLabel: 'With chickpea flour, like in Gondar',
      }),
    );
  });

  it('a version of a catalogue dish needs proof-of-cook', async () => {
    await assertSucceeds(
      setDoc(doc(asUser(env, 'dawit'), 'family_recipes', 'variant-2'), {
        authorId: 'dawit',
        status: 'pending',
        title: 'Doro, the fast way',
        baseId: 'doro-wat',
        variantLabel: 'Pressure cooker, one hour',
        proofSessionId: 'session-doro',
      }),
    );
  });

  it('a catalogue version without a completed session is denied', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'selam'), 'family_recipes', 'variant-3'), {
        authorId: 'selam',
        status: 'pending',
        title: 'Doro I never cooked',
        baseId: 'doro-wat',
        variantLabel: 'Bogus',
        proofSessionId: 'session-doro',
      }),
    );
  });

  it('a catalogue version citing a session of a DIFFERENT dish is denied', async () => {
    await seed(env, async (db) => {
      await setDoc(doc(db, 'users/selam/cooking_sessions/session-shiro'), {
        recipeId: 'shiro',
        status: 'completed',
      });
    });
    await assertFails(
      setDoc(doc(asUser(env, 'selam'), 'family_recipes', 'variant-4'), {
        authorId: 'selam',
        status: 'pending',
        title: 'Doro via my shiro cook',
        baseId: 'doro-wat',
        variantLabel: 'Cross-crediting',
        proofSessionId: 'session-shiro',
      }),
    );
  });

  it('an incomplete session is not proof', async () => {
    await seed(env, async (db) => {
      await setDoc(doc(db, 'users/abeni/cooking_sessions/session-partial'), {
        recipeId: 'doro-wat',
        status: 'inProgress',
      });
    });
    await assertFails(
      setDoc(doc(asUser(env, 'abeni'), 'family_recipes', 'variant-5'), {
        authorId: 'abeni',
        status: 'pending',
        title: 'Doro, halfway',
        baseId: 'doro-wat',
        variantLabel: 'Half done',
        proofSessionId: 'session-partial',
      }),
    );
  });

  it('baseId without variantLabel is rejected', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'dawit'), 'family_recipes', 'variant-6'), {
        authorId: 'dawit',
        status: 'pending',
        title: 'Half-declared variant',
        baseId: FAMILY_BASE_ID,
      }),
    );
  });

  it('a variant of a family recipe that does not exist is rejected', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'dawit'), 'family_recipes', 'variant-7'), {
        authorId: 'dawit',
        status: 'pending',
        title: 'Ghost base',
        baseId: '99999999-2222-3333-4444-555555555555',
        variantLabel: 'No such recipe',
      }),
    );
  });

  it('a recipe cannot be a version of itself', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'dawit'), 'family_recipes', 'variant-8'), {
        authorId: 'dawit',
        status: 'pending',
        title: 'Self-loop',
        baseId: 'variant-8',
        variantLabel: 'Me, but me',
      }),
    );
  });
});

// ---------------------------------------------------------------------------
// Vouch notifications — the one client-written carve-out into another user's
// notifications. The vouching cook drops a note into the AUTHOR's collection;
// the rules prove the note cites a real vouch.
// ---------------------------------------------------------------------------

describe('vouch notifications', () => {
  let env;

  beforeAll(async () => {
    env = await createTestEnv();
  });

  afterAll(async () => {
    await env.cleanup();
  });

  const AUTHOR = 'author-uid-1';
  const VOUCHER = 'voucher-uid-1';
  const RECIPE = 'recipe-1';

  async function seedVouched(db, count) {
    await setDoc(doc(db, 'family_recipes', RECIPE), {
      authorId: AUTHOR,
      status: count >= 3 ? 'published' : 'pending',
      title: 'Test recipe',
      verifiedBy: Array.from({ length: count }, (_, i) => `v-${i}`),
    });
  }

  const note = (type, count) => ({
    type,
    recipeId: RECIPE,
    otherUid: `${count}`,
    otherName: 'Dawit M.',
    count,
  });

  beforeEach(async () => {
    await env.clearFirestore();
  });

  it('the vouching cook can create the note in the author collection', async () => {
    await seed(env, async (db) => {
      await seedVouched(db, 1);
    });
    await assertSucceeds(
      setDoc(
        doc(asUser(env, 'v-0'), `users/${AUTHOR}/notifications`, `vouch_${RECIPE}_v-0`),
        note('recipeVouched', 1),
      ),
    );
  });

  it('a note citing a vouch that does not exist is denied', async () => {
    await seed(env, async (db) => {
      await seedVouched(db, 1);
    });
    // 'impostor' is not in verifiedBy — the rules read the recipe and deny.
    await assertFails(
      setDoc(
        doc(asUser(env, 'impostor'), `users/${AUTHOR}/notifications`, `vouch_${RECIPE}_impostor`),
        note('recipeVouched', 1),
      ),
    );
  });

  it('the count must match the recipe real vouch count', async () => {
    await seed(env, async (db) => {
      await seedVouched(db, 2);
    });
    await assertFails(
      setDoc(
        doc(asUser(env, 'v-0'), `users/${AUTHOR}/notifications`, `vouch_${RECIPE}_v-0`),
        note('recipeVouched', 3),
      ),
    );
    await assertSucceeds(
      setDoc(
        doc(asUser(env, 'v-1'), `users/${AUTHOR}/notifications`, `vouch_${RECIPE}_v-1`),
        note('recipeVouched', 2),
      ),
    );
  });

  it('the celebration type is only allowed on the threshold vouch', async () => {
    await seed(env, async (db) => {
      await seedVouched(db, 3);
    });
    await assertSucceeds(
      setDoc(
        doc(asUser(env, 'v-2'), `users/${AUTHOR}/notifications`, `vouch_${RECIPE}_v-2`),
        note('recipeVerified', 3),
      ),
    );
    await seed(env, async (db) => {
      await seedVouched(db, 1);
    });
    await assertFails(
      setDoc(
        doc(asUser(env, 'v-0'), `users/${AUTHOR}/notifications`, `vouch_${RECIPE}_v-0`),
        note('recipeVerified', 1),
      ),
    );
  });

  it('the author cannot mint a note claiming someone vouched', async () => {
    await seed(env, async (db) => {
      await seedVouched(db, 1);
    });
    // The author is not in verifiedBy, so their note cannot cite a real vouch.
    await assertFails(
      setDoc(
        doc(asUser(env, AUTHOR), `users/${AUTHOR}/notifications`, `vouch_${RECIPE}_${AUTHOR}`),
        note('recipeVouched', 1),
      ),
    );
  });

  it('a stranger cannot write into a third party notifications', async () => {
    await seed(env, async (db) => {
      await seedVouched(db, 1);
    });
    await assertFails(
      setDoc(
        doc(asUser(env, 'v-0'), 'users/some-third-party/notifications', `vouch_${RECIPE}_v-0`),
        note('recipeVouched', 1),
      ),
    );
  });

  it('a note with junk fields is denied', async () => {
    await seed(env, async (db) => {
      await seedVouched(db, 1);
    });
    await assertFails(
      setDoc(
        doc(asUser(env, 'v-0'), `users/${AUTHOR}/notifications`, `vouch_${RECIPE}_v-0`),
        { ...note('recipeVouched', 1), injected: 'field' },
      ),
    );
  });

  it('the honest flow: vouch + note in ONE transaction passes together',
    async () => {
      // The app writes both in a single transaction. getAfter() in the
      // rules evaluates the recipe at post-batch state, so the note citing
      // the new vouch is validated against the write that carries it.
      await seed(env, async (db) => {
        await setDoc(doc(db, 'family_recipes', RECIPE), {
          authorId: AUTHOR,
          status: 'pending',
          title: 'Test recipe',
          verifiedBy: ['v-0', 'v-1'],
        });
      });
      const sdk = asUser(env, 'v-2');
      await assertSucceeds(
        runTransaction(sdk, async (tx) => {
          const ref = doc(sdk, 'family_recipes', RECIPE);
          const snap = await tx.get(ref);
          const verifiedBy = snap.data().verifiedBy;
          verifiedBy.push('v-2');
          tx.update(ref, {
            verifiedBy,
            ...(verifiedBy.length >= 3 ? { status: 'published' } : {}),
          });
          tx.set(
            doc(sdk, `users/${AUTHOR}/notifications`, `vouch_${RECIPE}_v-2`),
            {
              type: 'recipeVerified',
              recipeId: RECIPE,
              otherUid: '3',
              otherName: 'Dawit M.',
              count: 3,
            },
          );
        }),
      );
    });

  it('notes are owner-read, and nobody can delete them', async () => {
    await seed(env, async (db) => {
      await seedVouched(db, 1);
      await setDoc(doc(db, `users/${AUTHOR}/notifications/n1`), {
        type: 'recipeVouched', recipeId: RECIPE, otherUid: '1',
        otherName: 'x', count: 1,
      });
    });
    await assertSucceeds(
      getDoc(doc(asUser(env, AUTHOR), `users/${AUTHOR}/notifications/n1`)),
    );
    await assertFails(
      getDoc(doc(asUser(env, 'v-0'), `users/${AUTHOR}/notifications/n1`)),
    );
  });
});
