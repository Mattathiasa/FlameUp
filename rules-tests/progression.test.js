import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
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

/**
 * The central invariant: the client cannot award itself progression.
 *
 * If any test in this file starts passing when it should fail, XP is
 * self-awardable and the entire gamification design is decorative.
 */
describe('progression is server-authoritative', () => {
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
      await setDoc(doc(db, 'users/liya'), {
        displayName: 'Liya',
        xp: 500,
        level: 5,
        flames: 12,
        longestStreak: 21,
        recipesCooked: 8,
        profileVisibility: 'friends',
      });
    });
  });

  it('a user can edit their own display name', async () => {
    const db = asUser(env, 'liya');
    await assertSucceeds(
      updateDoc(doc(db, 'users/liya'), { displayName: 'Liya B' }),
    );
  });

  it('a user cannot give themselves XP', async () => {
    const db = asUser(env, 'liya');
    await assertFails(updateDoc(doc(db, 'users/liya'), { xp: 999999 }));
  });

  it('a user cannot raise their own level', async () => {
    const db = asUser(env, 'liya');
    await assertFails(updateDoc(doc(db, 'users/liya'), { level: 60 }));
  });

  it('a user cannot inflate their streak', async () => {
    const db = asUser(env, 'liya');
    await assertFails(updateDoc(doc(db, 'users/liya'), { flames: 365 }));
    await assertFails(updateDoc(doc(db, 'users/liya'), { longestStreak: 365 }));
  });

  it('XP cannot be smuggled in alongside a legitimate edit', async () => {
    // The attack the diff()-based rule exists to stop: a valid field and a
    // forbidden one in the same write.
    const db = asUser(env, 'liya');
    await assertFails(
      updateDoc(doc(db, 'users/liya'), { displayName: 'Liya B', xp: 999999 }),
    );
  });

  it('a new profile cannot be created with XP already in it', async () => {
    const db = asUser(env, 'newcomer');
    await assertFails(
      setDoc(doc(db, 'users/newcomer'), { displayName: 'New', xp: 10000 }),
    );
    await assertSucceeds(
      setDoc(doc(db, 'users/newcomer'), { displayName: 'New' }),
    );
  });

  it('one user cannot edit another', async () => {
    const db = asUser(env, 'dawit');
    await assertFails(
      updateDoc(doc(db, 'users/liya'), { displayName: 'hacked' }),
    );
  });

  it('mastery is read-only to the client', async () => {
    await seed(env, async (db) => {
      await setDoc(doc(db, 'users/liya/mastery/doro'), { cookCount: 3 });
    });

    const db = asUser(env, 'liya');
    await assertSucceeds(getDoc(doc(db, 'users/liya/mastery/doro')));
    await assertFails(
      setDoc(doc(db, 'users/liya/mastery/doro'), { cookCount: 99 }),
    );
  });

  it('achievements cannot be self-granted', async () => {
    const db = asUser(env, 'liya');
    await assertFails(
      setDoc(doc(db, 'users/liya/user_achievements/thirty_day_fire'), {
        unlockedAt: new Date().toISOString(),
      }),
    );
  });

  it('quest progress cannot be written by the client', async () => {
    // Quest progress converts into XP, so it is as sensitive as XP itself.
    const db = asUser(env, 'liya');
    await assertFails(
      setDoc(doc(db, 'users/liya/user_quests/daily_fasting'), {
        progress: 99,
        target: 1,
      }),
    );
  });

  it('a reward claim marker cannot be forged or deleted', async () => {
    // Deleting the marker would make a completed cook claimable twice.
    await seed(env, async (db) => {
      await setDoc(doc(db, 'users/liya/reward_claims/key-1'), {
        xpAwarded: 240,
      });
    });

    const db = asUser(env, 'liya');
    await assertSucceeds(getDoc(doc(db, 'users/liya/reward_claims/key-1')));
    await assertFails(
      setDoc(doc(db, 'users/liya/reward_claims/key-2'), { xpAwarded: 9999 }),
    );
  });

  it('the leaderboard cannot be written by a client', async () => {
    const db = asUser(env, 'liya');
    await assertFails(
      setDoc(doc(db, 'leaderboards/global'), {
        entries: [{ uid: 'liya', xp: 999999, rank: 1 }],
      }),
    );
  });

  it('cooking sessions stay client-writable, being a record not a reward',
    async () => {
      const db = asUser(env, 'liya');
      await assertSucceeds(
        setDoc(doc(db, 'users/liya/cooking_sessions/s1'), {
          recipeId: 'doro',
          status: 'completed',
          idempotencyKey: 'k1',
        }),
      );
    });

  it('one user cannot read another\'s private sessions', async () => {
    await seed(env, async (db) => {
      await setDoc(doc(db, 'users/liya/cooking_sessions/s1'), {
        recipeId: 'doro',
      });
    });

    const db = asUser(env, 'dawit');
    await assertFails(getDoc(doc(db, 'users/liya/cooking_sessions/s1')));
  });

  it('a signed-out visitor cannot read a private profile', async () => {
    const db = asVisitor(env);
    await assertFails(getDoc(doc(db, 'users/liya')));
  });

  it('a moderator still cannot hand out XP', async () => {
    // Moderation is about content, not progression. Even a privileged client
    // goes through the reward function.
    const db = asModerator(env);
    await assertFails(updateDoc(doc(db, 'users/liya'), { xp: 999999 }));
  });
});
