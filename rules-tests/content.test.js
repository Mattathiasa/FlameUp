import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

import {
  asModerator,
  asUser,
  asVisitor,
  assertFails,
  assertSucceeds,
  createTestEnv,
  seed,
} from './helpers.js';

describe('reviews require a cook that actually happened', () => {
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
      await setDoc(doc(db, 'recipes/doro'), { title: 'Doro Wat' });
      await setDoc(doc(db, 'users/liya/cooking_sessions/done-1'), {
        recipeId: 'doro',
        status: 'completed',
      });
      await setDoc(doc(db, 'users/liya/cooking_sessions/wip-1'), {
        recipeId: 'doro',
        status: 'in_progress',
      });
    });
  });

  const review = (sessionId, uid = 'liya') => ({
    uid,
    sessionId,
    taste: 5,
  });

  it('accepts a review backed by a completed session', async () => {
    const db = asUser(env, 'liya');
    await assertSucceeds(
      setDoc(doc(db, 'recipes/doro/reviews/liya'), review('done-1')),
    );
  });

  it('rejects a review for a session still in progress', async () => {
    // Rating a dish you have not finished is exactly what the rule exists for.
    const db = asUser(env, 'liya');
    await assertFails(
      setDoc(doc(db, 'recipes/doro/reviews/liya'), review('wip-1')),
    );
  });

  it('rejects a review naming a session that does not exist', async () => {
    const db = asUser(env, 'liya');
    await assertFails(
      setDoc(doc(db, 'recipes/doro/reviews/liya'), review('invented')),
    );
  });

  it('rejects a review with no session at all', async () => {
    const db = asUser(env, 'liya');
    await assertFails(
      setDoc(doc(db, 'recipes/doro/reviews/liya'), { uid: 'liya', taste: 5 }),
    );
  });

  it('rejects a review borrowing someone else\'s session', async () => {
    // Dawit cannot rate using Liya's cook.
    const db = asUser(env, 'dawit');
    await assertFails(
      setDoc(doc(db, 'recipes/doro/reviews/dawit'), review('done-1', 'dawit')),
    );
  });

  it('rejects writing a review under another user\'s id', async () => {
    const db = asUser(env, 'dawit');
    await assertFails(
      setDoc(doc(db, 'recipes/doro/reviews/liya'), review('done-1')),
    );
  });

  it('lets anyone read reviews, since they are public commentary', async () => {
    await seed(env, async (db) => {
      await setDoc(doc(db, 'recipes/doro/reviews/liya'), review('done-1'));
    });
    await assertSucceeds(getDoc(doc(asVisitor(env), 'recipes/doro/reviews/liya')));
  });

  it('keeps the recipe catalogue read-only to clients', async () => {
    const db = asUser(env, 'liya');
    await assertSucceeds(getDoc(doc(db, 'recipes/doro')));
    await assertFails(updateDoc(doc(db, 'recipes/doro'), { xpReward: 99999 }));
  });

  it('keeps rating aggregates out of client hands', async () => {
    const db = asUser(env, 'liya');
    await assertFails(
      updateDoc(doc(db, 'recipes/doro'), { averageRating: 5, ratingCount: 999 }),
    );
  });
});

describe('family recipes stay private until moderation publishes them', () => {
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
      await setDoc(doc(db, 'family_recipes/draft-1'), {
        authorId: 'liya',
        status: 'pending',
        title: "Grandmother's doro",
      });
      await setDoc(doc(db, 'family_recipes/draft-1/generations/g1'), {
        name: 'Emahoy Tsehay',
        relationship: 'grandmother',
      });
      await setDoc(doc(db, 'family_recipes/live-1'), {
        authorId: 'dawit',
        status: 'published',
        title: 'Kitfo',
      });
    });
  });

  it('the author can read their own unpublished draft', async () => {
    await assertSucceeds(
      getDoc(doc(asUser(env, 'liya'), 'family_recipes/draft-1')),
    );
  });

  it('a stranger cannot read an unpublished draft', async () => {
    await assertFails(
      getDoc(doc(asUser(env, 'dawit'), 'family_recipes/draft-1')),
    );
  });

  it('published recipes are readable', async () => {
    await assertSucceeds(
      getDoc(doc(asUser(env, 'liya'), 'family_recipes/live-1')),
    );
  });

  it('generations of an unpublished draft are not world-readable', async () => {
    // The leak this test exists for: generations name the relatives a recipe
    // was passed down through. A world-readable subcollection under a private
    // draft would expose family names the author has not published.
    await assertFails(
      getDoc(doc(asVisitor(env), 'family_recipes/draft-1/generations/g1')),
    );
    await assertFails(
      getDoc(doc(asUser(env, 'dawit'), 'family_recipes/draft-1/generations/g1')),
    );
  });

  it('the author can read their own draft generations', async () => {
    await assertSucceeds(
      getDoc(doc(asUser(env, 'liya'), 'family_recipes/draft-1/generations/g1')),
    );
  });

  it('an author cannot publish their own work', async () => {
    // Otherwise moderation is optional.
    await assertFails(
      updateDoc(doc(asUser(env, 'liya'), 'family_recipes/draft-1'), {
        status: 'published',
      }),
    );
  });

  it('an author can keep editing while it is pending', async () => {
    await assertSucceeds(
      updateDoc(doc(asUser(env, 'liya'), 'family_recipes/draft-1'), {
        title: 'Doro, the four-onion way',
        status: 'pending',
      }),
    );
  });

  it('a moderator can publish it', async () => {
    await assertSucceeds(
      updateDoc(doc(asModerator(env), 'family_recipes/draft-1'), {
        status: 'published',
      }),
    );
  });

  it('a submission cannot arrive already published', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'liya'), 'family_recipes/new-1'), {
        authorId: 'liya',
        status: 'published',
      }),
    );
  });

  it('a user cannot submit under another author id', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'dawit'), 'family_recipes/new-2'), {
        authorId: 'liya',
        status: 'pending',
      }),
    );
  });
});

describe('reports are write-only for clients', () => {
  let env;

  beforeAll(async () => {
    env = await createTestEnv();
  });

  afterAll(async () => {
    await env.cleanup();
  });

  beforeEach(() => env.clearFirestore());

  it('a user can file a report', async () => {
    await assertSucceeds(
      setDoc(doc(asUser(env, 'liya'), 'reports/r1'), {
        reporterId: 'liya',
        targetType: 'post',
        targetId: 'p1',
        reason: 'abuse',
      }),
    );
  });

  it('a reporter cannot read the moderation queue', async () => {
    await seed(env, async (db) => {
      await setDoc(doc(db, 'reports/r1'), { reporterId: 'liya' });
    });
    await assertFails(getDoc(doc(asUser(env, 'liya'), 'reports/r1')));
  });

  it('a user cannot file a report as someone else', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'dawit'), 'reports/r2'), { reporterId: 'liya' }),
    );
  });

  it('a moderator can read reports', async () => {
    await seed(env, async (db) => {
      await setDoc(doc(db, 'reports/r1'), { reporterId: 'liya' });
    });
    await assertSucceeds(getDoc(doc(asModerator(env), 'reports/r1')));
  });
});
