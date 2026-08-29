/**
 * FlameUp Cloud Functions.
 *
 * Everything the client must not be trusted with: XP, levels, streaks,
 * mastery, quest and achievement grants, rating aggregates and leaderboards.
 * Firestore rules make those fields unwritable by clients, so this is the only
 * path that can change them.
 *
 * DEPLOYMENT: requires the Blaze plan. The project is currently on Spark, so
 * these run against the emulator during development and are not yet deployed.
 * See docs/FIREBASE_SETUP.md.
 */

import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';

export { askAssistant } from './assistant';

import {
  awardsForCook,
  dayKey,
  levelFor,
  masteryLevelFor,
  streakAfterCook,
  totalOf,
  type StreakState,
} from './progression';

initializeApp();
const db = getFirestore();

const REGION = 'us-central1';

/**
 * Grants the rewards for a completed cooking session.
 *
 * Idempotent by construction: the session's own key is written as a marker
 * document inside the same transaction that applies the XP. A replay -- a
 * retry after a crash, an outbox drain that ran twice, a user tapping finish
 * on two devices -- finds the marker and grants nothing.
 */
export const claimCookingReward = onCall(
  { region: REGION },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in to claim rewards.');
    }

    const sessionId = request.data?.sessionId;
    if (typeof sessionId !== 'string' || sessionId.length === 0) {
      throw new HttpsError('invalid-argument', 'sessionId is required.');
    }

    const sessionRef = db.doc(`users/${uid}/cooking_sessions/${sessionId}`);
    const userRef = db.doc(`users/${uid}`);

    return db.runTransaction(async (tx) => {
      const session = await tx.get(sessionRef);
      if (!session.exists) {
        throw new HttpsError('not-found', 'No such cooking session.');
      }

      const data = session.data()!;
      if (data.status !== 'completed') {
        throw new HttpsError(
          'failed-precondition',
          'That session is not finished.',
        );
      }

      const key = data.idempotencyKey;
      if (typeof key !== 'string') {
        throw new HttpsError('invalid-argument', 'Session has no reward key.');
      }

      // The marker is the whole idempotency mechanism.
      const markerRef = db.doc(`users/${uid}/reward_claims/${key}`);
      const marker = await tx.get(markerRef);
      if (marker.exists) {
        logger.info('reward already granted', { uid, sessionId, key });
        return { alreadyGranted: true, xpAwarded: 0 };
      }

      const recipeSnap = await tx.get(db.doc(`recipes/${data.recipeId}`));
      const recipe = recipeSnap.data();
      const recipeXp = typeof recipe?.xpReward === 'number'
        ? recipe.xpReward
        : 50;

      const userSnap = await tx.get(userRef);
      const user = userSnap.data() ?? {};
      const timeZone = typeof user.timezone === 'string'
        ? user.timezone
        : 'Africa/Addis_Ababa';

      const masteryRef = db.doc(`users/${uid}/mastery/${data.recipeId}`);
      const masterySnap = await tx.get(masteryRef);
      const previousCooks = masterySnap.data()?.cookCount ?? 0;

      const streakBefore: StreakState = {
        current: user.flames ?? 0,
        longest: user.longestStreak ?? 0,
        lastCookedOn: user.lastCookedOn ?? null,
        freezeDaysLeft: user.freezeDaysLeft ?? 2,
      };
      const streakAfter = streakAfterCook(
        streakBefore,
        dayKey(new Date(), timeZone),
      );

      const awards = awardsForCook({
        recipeXp,
        recipeId: data.recipeId,
        previousCooks,
        streakAfter: streakAfter.current,
      });
      const xpAwarded = totalOf(awards);

      const xpBefore = user.xp ?? 0;
      const xpAfter = xpBefore + xpAwarded;
      const levelBefore = levelFor(xpBefore);
      const levelAfter = levelFor(xpAfter);

      tx.set(markerRef, {
        sessionId,
        recipeId: data.recipeId,
        awards,
        xpAwarded,
        grantedAt: FieldValue.serverTimestamp(),
      });

      tx.set(
        userRef,
        {
          xp: xpAfter,
          level: levelAfter,
          flames: streakAfter.current,
          longestStreak: streakAfter.longest,
          lastCookedOn: streakAfter.lastCookedOn,
          freezeDaysLeft: streakAfter.freezeDaysLeft,
          recipesCooked: FieldValue.increment(1),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      const cookCount = previousCooks + 1;
      tx.set(
        masteryRef,
        {
          recipeId: data.recipeId,
          cookCount,
          level: masteryLevelFor(cookCount),
          lastCookedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      tx.set(
        db.doc(`recipes/${data.recipeId}`),
        { numberOfCooks: FieldValue.increment(1) },
        { merge: true },
      );

      logger.info('reward granted', { uid, sessionId, xpAwarded, levelAfter });

      return {
        alreadyGranted: false,
        xpAwarded,
        awards,
        level: levelAfter,
        leveledUp: levelAfter > levelBefore,
        streak: streakAfter.current,
      };
    });
  },
);

/**
 * Keeps a recipe's rating aggregate current.
 *
 * Recomputed from the reviews rather than incremented, so an edited or deleted
 * review corrects the average instead of leaving it permanently skewed.
 */
export const onReviewWritten = onDocumentWritten(
  { region: REGION, document: 'recipes/{recipeId}/reviews/{uid}' },
  async (event) => {
    const recipeId = event.params.recipeId;
    const reviews = await db.collection(`recipes/${recipeId}/reviews`).get();

    let total = 0;
    let count = 0;
    reviews.forEach((doc) => {
      const taste = doc.data().taste;
      if (typeof taste === 'number') {
        total += taste;
        count++;
      }
    });

    await db.doc(`recipes/${recipeId}`).set(
      {
        averageRating: count === 0 ? 0 : total / count,
        ratingCount: count,
      },
      { merge: true },
    );
  },
);

/**
 * Rebuilds the leaderboard documents.
 *
 * One document per scope, written here. Rankings are never computed by pulling
 * the users collection onto a device, and anyone who opted out is excluded.
 */
export const rebuildLeaderboards = onSchedule(
  { region: REGION, schedule: 'every 60 minutes' },
  async () => {
    const top = await db
      .collection('users')
      .where('leaderboardOptOut', '!=', true)
      .orderBy('leaderboardOptOut')
      .orderBy('xp', 'desc')
      .limit(100)
      .get();

    const entries = top.docs.map((doc, index) => ({
      uid: doc.id,
      displayName: doc.data().displayName ?? '',
      photoUrl: doc.data().photoUrl ?? null,
      xp: doc.data().xp ?? 0,
      rank: index + 1,
    }));

    await db.doc('leaderboards/global').set({
      entries,
      updatedAt: FieldValue.serverTimestamp(),
    });

    logger.info('leaderboard rebuilt', { entries: entries.length });
  },
);

/**
 * Removes a user's data when their account is deleted.
 *
 * A trigger rather than client-side deletion, so it completes even if the app
 * is killed mid-delete.
 */
export const onUserDeleted = onDocumentWritten(
  { region: REGION, document: 'users/{uid}' },
  async (event) => {
    if (event.data?.after.exists) return;

    const uid = event.params.uid;
    const subcollections = [
      'cooking_sessions',
      'mastery',
      'user_quests',
      'user_achievements',
      'saved_recipes',
      'shopping_items',
      'meal_plans',
      'reward_claims',
    ];

    for (const name of subcollections) {
      const docs = await db.collection(`users/${uid}/${name}`).get();
      const batch = db.batch();
      docs.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }

    logger.info('user data removed', { uid });
  },
);
