import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

import {
  asUser,
  asVisitor,
  assertFails,
  assertSucceeds,
  createTestEnv,
  seed,
} from './helpers.js';

describe('challenges cannot be gamed by peeking or self-declaring', () => {
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
      await setDoc(doc(db, 'challenges/c1'), {
        createdBy: 'liya',
        opponentId: 'dawit',
        recipeId: 'doro',
        status: 'accepted',
      });
      await setDoc(doc(db, 'challenges/c1/submissions/liya'), {
        uid: 'liya',
        sessionId: 's1',
        scores: { taste: 5 },
      });
    });
  });

  it('a participant can read the challenge', async () => {
    await assertSucceeds(getDoc(doc(asUser(env, 'dawit'), 'challenges/c1')));
  });

  it('an outsider cannot', async () => {
    await assertFails(getDoc(doc(asUser(env, 'meron'), 'challenges/c1')));
  });

  it('an opponent who has not submitted cannot see the other entry', async () => {
    // The heart of it: seeing the first cook's scores would let the second
    // simply out-score them.
    await assertFails(
      getDoc(doc(asUser(env, 'dawit'), 'challenges/c1/submissions/liya')),
    );
  });

  it('once both have submitted, each can see the other', async () => {
    await seed(env, async (db) => {
      await setDoc(doc(db, 'challenges/c1/submissions/dawit'), {
        uid: 'dawit',
        sessionId: 's2',
        scores: { taste: 4 },
      });
    });

    await assertSucceeds(
      getDoc(doc(asUser(env, 'dawit'), 'challenges/c1/submissions/liya')),
    );
  });

  it('a participant can always read their own entry', async () => {
    await assertSucceeds(
      getDoc(doc(asUser(env, 'liya'), 'challenges/c1/submissions/liya')),
    );
  });

  it('a submission cannot be edited after the fact', async () => {
    // Otherwise a losing entry could be revised once the other is visible.
    await assertFails(
      updateDoc(doc(asUser(env, 'liya'), 'challenges/c1/submissions/liya'), {
        scores: { taste: 5, presentation: 5 },
      }),
    );
  });

  it('a participant cannot submit for the other person', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'liya'), 'challenges/c1/submissions/dawit'), {
        uid: 'dawit',
        sessionId: 's9',
      }),
    );
  });

  it('neither participant can declare themselves the winner', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'liya'), 'challenges/c1'), {
        winnerId: 'liya',
      }),
    );
    await assertFails(
      updateDoc(doc(asUser(env, 'dawit'), 'challenges/c1'), {
        winnerId: 'dawit',
      }),
    );
  });

  it('a participant can still change the status, to accept or decline',
    async () => {
      await assertSucceeds(
        updateDoc(doc(asUser(env, 'dawit'), 'challenges/c1'), {
          status: 'cooking',
        }),
      );
    });
});

describe('posts and likes cannot be inflated by their author', () => {
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
      await setDoc(doc(db, 'posts/p1'), {
        authorId: 'liya',
        sessionId: 's1',
        recipeId: 'doro',
        body: 'Four hours of onion patience.',
        likeCount: 3,
        commentCount: 1,
        visibility: 'public',
      });
    });
  });

  it('a signed-in user can read the feed', async () => {
    await assertSucceeds(getDoc(doc(asUser(env, 'dawit'), 'posts/p1')));
  });

  it('a signed-out visitor cannot', async () => {
    await assertFails(getDoc(doc(asVisitor(env), 'posts/p1')));
  });

  it('a user can post as themselves', async () => {
    await assertSucceeds(
      setDoc(doc(asUser(env, 'dawit'), 'posts/p2'), {
        authorId: 'dawit',
        sessionId: 's2',
        recipeId: 'kitfo',
      }),
    );
  });

  it('a user cannot post as someone else', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'dawit'), 'posts/p3'), {
        authorId: 'liya',
        sessionId: 's3',
      }),
    );
  });

  it('an author can edit their own text', async () => {
    await assertSucceeds(
      updateDoc(doc(asUser(env, 'liya'), 'posts/p1'), { body: 'Edited.' }),
    );
  });

  it('an author cannot inflate their own like count', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'liya'), 'posts/p1'), { likeCount: 9999 }),
    );
  });

  it('an author cannot smuggle a counter into a legitimate edit', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'liya'), 'posts/p1'), {
        body: 'Edited.',
        likeCount: 9999,
      }),
    );
  });

  it('a stranger cannot edit or delete a post', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'meron'), 'posts/p1'), { body: 'hacked' }),
    );
  });

  it('a like is keyed by the liker, so it cannot be double-counted', async () => {
    await assertSucceeds(
      setDoc(doc(asUser(env, 'dawit'), 'posts/p1/likes/dawit'), {
        createdAt: new Date().toISOString(),
      }),
    );
    await assertFails(
      setDoc(doc(asUser(env, 'dawit'), 'posts/p1/likes/meron'), {
        createdAt: new Date().toISOString(),
      }),
    );
  });
});

describe('personal lists belong to their owner', () => {
  let env;

  beforeAll(async () => {
    env = await createTestEnv();
  });

  afterAll(async () => {
    await env.cleanup();
  });

  beforeEach(() => env.clearFirestore());

  it('an owner can manage their shopping list', async () => {
    const db = asUser(env, 'liya');
    await assertSucceeds(
      setDoc(doc(db, 'users/liya/shopping_items/i1'), { name: 'Berbere' }),
    );
  });

  it('nobody else can read it', async () => {
    await seed(env, async (db) => {
      await setDoc(doc(db, 'users/liya/shopping_items/i1'), {
        name: 'Berbere',
      });
    });
    await assertFails(
      getDoc(doc(asUser(env, 'dawit'), 'users/liya/shopping_items/i1')),
    );
  });

  it('saved recipes and meal plans follow the same rule', async () => {
    const mine = asUser(env, 'liya');
    await assertSucceeds(
      setDoc(doc(mine, 'users/liya/saved_recipes/doro'), { savedAt: 'now' }),
    );
    await assertSucceeds(
      setDoc(doc(mine, 'users/liya/meal_plans/2026-W10'), { slots: {} }),
    );

    const theirs = asUser(env, 'dawit');
    await assertFails(
      setDoc(doc(theirs, 'users/liya/saved_recipes/doro'), { savedAt: 'now' }),
    );
  });

  it('config is public to read and closed to write', async () => {
    await seed(env, async (db) => {
      await setDoc(doc(db, 'config/level_curve'), { thresholds: [0, 100] });
    });

    await assertSucceeds(getDoc(doc(asVisitor(env), 'config/level_curve')));
    await assertFails(
      setDoc(doc(asUser(env, 'liya'), 'config/level_curve'), {
        thresholds: [0, 1],
      }),
    );
  });
});
