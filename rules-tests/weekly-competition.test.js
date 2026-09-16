import { afterAll, beforeAll, describe, it } from 'vitest';
import { Timestamp } from 'firebase/firestore';

import {
  asModerator,
  asUser,
  assertFails,
  assertSucceeds,
  createTestEnv,
  seed,
} from './helpers.js';

// ---------------------------------------------------------------------------
// Week id — mirrors weekIdFor() in
// lib/features/community/domain/weekly_competition.dart.
//
// The rules compute the current week on the SERVER clock; the client computes
// it on the device. The create-row cases below use THIS function's output as
// the weekId, so a passing test is proof the two implementations agree — if
// they ever drift, those tests fail and the leaderboard goes dark.
// ---------------------------------------------------------------------------

function weekStartUtc(date) {
  const utc = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
  const day = new Date(utc).getUTCDay(); // 0 = Sunday
  const backToMonday = (day + 6) % 7;
  return new Date(utc - backToMonday * 86400000);
}

function weekIdFor(date) {
  const start = weekStartUtc(date);
  const thursday = new Date(start.getTime() + 3 * 86400000);
  const year = thursday.getUTCFullYear();

  const jan4 = weekStartUtc(new Date(Date.UTC(year, 0, 4)));
  const week = Math.round((start - jan4) / (7 * 86400000)) + 1;
  return `w${year}w${week}`;
}

const RECIPE_ID = 'doro-wat';
const RECIPE_XP = 40;

function futureWeekDoc() {
  return {
    recipeId: RECIPE_ID,
    recipeTitle: 'Doro Wat',
    recipeTitleAm: 'ዶሮ ወጥ',
    deadline: Timestamp.fromDate(new Date(Date.now() + 3 * 86400000)),
    publishedAt: Timestamp.fromDate(new Date(0)),
  };
}

function expiredWeekDoc() {
  return {
    recipeId: RECIPE_ID,
    recipeTitle: 'Doro Wat',
    recipeTitleAm: 'ዶሮ ወጥ',
    deadline: Timestamp.fromDate(new Date(Date.now() - 86400000)),
    publishedAt: Timestamp.fromDate(new Date(0)),
  };
}

function completedSession(recipeId = RECIPE_ID) {
  return {
    recipeId,
    status: 'completed',
    startedAt: Timestamp.fromDate(new Date(Date.now() - 3600000)),
    completedAt: Timestamp.fromDate(new Date()),
  };
}

function validEntry(uid) {
  return {
    uid,
    sessionId: 'sess-1',
    displayName: 'Liya',
    xp: RECIPE_XP,
  };
}

describe('the weekly competition', () => {
  let env;

  beforeAll(async () => {
    env = await createTestEnv();
  });

  afterAll(async () => {
    await env.cleanup();
  });

  describe('weekly_xp rows', () => {
    const weekId = weekIdFor(new Date());
    const rowId = `${weekId}_u1`;

    it('accepts a cook reporting their own current-week row', async () => {
      await assertSucceeds(
        asUser(env, 'u1')
          .doc(`weekly_xp/${rowId}`)
          .set({ uid: 'u1', weekId, displayName: 'Liya', xp: 40, cooks: 1 }),
      );
    });

    it('accepts a retry that merges onto the same row (xp never decreases)', async () => {
      await assertSucceeds(
        asUser(env, 'u1')
          .doc(`weekly_xp/${rowId}`)
          .set({ uid: 'u1', weekId, displayName: 'Liya', xp: 80, cooks: 2 }),
      );
    });

    it('refuses a write that would lower the total', async () => {
      await assertFails(
        asUser(env, 'u1')
          .doc(`weekly_xp/${rowId}`)
          .set({ uid: 'u1', weekId, displayName: 'Liya', xp: 10, cooks: 3 }),
      );
    });

    it("refuses someone else's row — the id's uid must be the writer", async () => {
      await assertFails(
        asUser(env, 'villain')
          .doc(`weekly_xp/${weekId}_u1`)
          .set({ uid: 'u1', weekId, displayName: 'Liya', xp: 9999, cooks: 99 }),
      );
    });

    it('refuses a row whose uid field disagrees with the writer', async () => {
      await assertFails(
        asUser(env, 'villain')
          .doc(`weekly_xp/${weekId}_villain`)
          .set({ uid: 'u1', weekId, displayName: 'Liya', xp: 40, cooks: 1 }),
      );
    });

    it('refuses a row whose weekId field disagrees with the document id', async () => {
      await assertFails(
        asUser(env, 'u1')
          .doc(`weekly_xp/${weekId}_u2`)
          .set({ uid: 'u1', weekId, displayName: 'Liya', xp: 40, cooks: 1 }),
      );
    });

    it('refuses a row claimed for a past week', async () => {
      await assertFails(
        asUser(env, 'u1')
          .doc('weekly_xp/w2020w1_u1')
          .set({ uid: 'u1', weekId: 'w2020w1', displayName: 'Liya', xp: 40, cooks: 1 }),
      );
    });

    it('refuses absurd numbers', async () => {
      await assertFails(
        asUser(env, 'u1')
          .doc(`weekly_xp/${weekId}_u3`)
          .set({ uid: 'u1', weekId, displayName: 'Liya', xp: 999999, cooks: 1 }),
      );
      await assertFails(
        asUser(env, 'u1')
          .doc(`weekly_xp/${weekId}_u3`)
          .set({ uid: 'u1', weekId, displayName: 'Liya', xp: 40, cooks: 1000 }),
      );
    });

    it('refuses an empty display name', async () => {
      await assertFails(
        asUser(env, 'u1')
          .doc(`weekly_xp/${weekId}_u4`)
          .set({ uid: 'u1', weekId, displayName: '', xp: 40, cooks: 1 }),
      );
    });

    it('refuses deletion', async () => {
      await assertFails(asUser(env, 'u1').doc(`weekly_xp/${rowId}`).delete());
    });
  });

  describe('cook-off entries', () => {
    it('accepts an entry backed by a real completed cook of the week dish', async () => {
      await seed(env, (fs) => {
        const batch = fs.batch();
        batch.set(fs.doc('weekly_challenges/w2030w1'), futureWeekDoc());
        batch.set(
          fs.doc('users/enter/cooking_sessions/sess-1'),
          completedSession(),
        );
        batch.set(fs.doc(`recipes/${RECIPE_ID}`), { xpReward: RECIPE_XP, title: 'Doro Wat' });
        return batch.commit();
      });

      await assertSucceeds(
        asUser(env, 'enter')
          .doc('weekly_challenges/w2030w1/entries/enter')
          .set(validEntry('enter')),
      );
    });

    it('refuses an entry citing a session that does not exist', async () => {
      await seed(env, (fs) => fs.doc('weekly_challenges/w2030w2').set(futureWeekDoc()));

      await assertFails(
        asUser(env, 'ghost')
          .doc('weekly_challenges/w2030w2/entries/ghost')
          .set({ ...validEntry('ghost'), sessionId: 'never-cooked' }),
      );
    });

    it('refuses an entry whose session is not completed', async () => {
      await seed(env, (fs) => {
        const batch = fs.batch();
        batch.set(fs.doc('weekly_challenges/w2030w3'), futureWeekDoc());
        batch.set(fs.doc('users/halfway/cooking_sessions/sess-h'), {
          ...completedSession(),
          status: 'inProgress',
        });
        return batch.commit();
      });

      await assertFails(
        asUser(env, 'halfway')
          .doc('weekly_challenges/w2030w3/entries/halfway')
          .set(validEntry('halfway')),
      );
    });

    it('refuses an entry for a different dish than the week is about', async () => {
      await seed(env, (fs) => {
        const batch = fs.batch();
        batch.set(fs.doc('weekly_challenges/w2030w4'), futureWeekDoc());
        batch.set(
          fs.doc('users/offrecipe/cooking_sessions/sess-o'),
          completedSession('shiro'),
        );
        return batch.commit();
      });

      await assertFails(
        asUser(env, 'offrecipe')
          .doc('weekly_challenges/w2030w4/entries/offrecipe')
          .set(validEntry('offrecipe')),
      );
    });

    it('refuses an entry whose xp does not match the recipe reward', async () => {
      await seed(env, (fs) => {
        const batch = fs.batch();
        batch.set(fs.doc('weekly_challenges/w2030w5'), futureWeekDoc());
        batch.set(
          fs.doc('users/inflator/cooking_sessions/sess-i'),
          completedSession(),
        );
        return batch.commit();
      });

      await assertFails(
        asUser(env, 'inflator')
          .doc('weekly_challenges/w2030w5/entries/inflator')
          .set({ ...validEntry('inflator'), xp: RECIPE_XP * 100 }),
      );
    });

    it('refuses an entry after the deadline — by server time, not device time', async () => {
      await seed(env, (fs) => {
        const batch = fs.batch();
        batch.set(fs.doc('weekly_challenges/w2030w6'), expiredWeekDoc());
        batch.set(
          fs.doc('users/late/cooking_sessions/sess-l'),
          completedSession(),
        );
        return batch.commit();
      });

      await assertFails(
        asUser(env, 'late')
          .doc('weekly_challenges/w2030w6/entries/late')
          .set(validEntry('late')),
      );
    });

    it('refuses writing into someone else’s slot and editing an entry', async () => {
      await seed(env, (fs) => {
        const batch = fs.batch();
        batch.set(fs.doc('weekly_challenges/w2030w7'), futureWeekDoc());
        batch.set(fs.doc('users/real/cooking_sessions/sess-r'), completedSession());
        return batch.commit();
      });

      await assertFails(
        asUser(env, 'impersonator')
          .doc('weekly_challenges/w2030w7/entries/real')
          .set(validEntry('real')),
      );

      await assertFails(
        asUser(env, 'real')
          .doc('weekly_challenges/w2030w7/entries/real')
          .set({ ...validEntry('real'), xp: 999 }),
      );

      await assertFails(
        asUser(env, 'real').doc('weekly_challenges/w2030w7/entries/real').delete(),
      );
    });

    it('lets any signed-in user read entries, and only moderators run weeks', async () => {
      await assertSucceeds(asUser(env, 'reader').doc('weekly_challenges/w2030w1').get());

      await assertFails(
        asUser(env, 'reader').doc('weekly_challenges/w2030w9').set(futureWeekDoc()),
      );
      await assertSucceeds(
        asModerator(env).doc('weekly_challenges/w2030w9').set(futureWeekDoc()),
      );
    });
  });
});
