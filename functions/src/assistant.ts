/**
 * The AI cooking assistant.
 *
 * Runs entirely server-side. The provider key lives in Functions config and is
 * never shipped to a device -- a key in the app binary is a key anyone can
 * extract from the APK.
 *
 * The assistant is instructed to distinguish what it is saying:
 *
 *   - recipe instruction    what this app's own recipe says
 *   - community tradition   how people commonly do it
 *   - AI suggestion         the model's own inference
 *
 * That separation is a product requirement, not a nicety. FlameUp is a
 * cultural archive as much as a cooking app, and a model's guess about
 * Ethiopian food practice must never be presented with the same authority as
 * something a cook actually told us.
 */

import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';

const REGION = 'us-central1';

/** Requests per user per rolling hour. */
const HOURLY_LIMIT = 30;

const SYSTEM_PROMPT = `You are FlameUp's cooking assistant, helping people cook
Ethiopian food.

Label every claim you make with one of three markers, and never blur them:

[RECIPE] — what the recipe in front of the user actually says. Only use this
when the recipe text is given to you below.

[TRADITION] — how this dish is commonly cooked or eaten. Describe practice, not
history. Never date a dish, name an inventor, or state a disputed origin as
fact. If regional practice varies, say so.

[SUGGESTION] — your own inference: a substitution, a fix for something that went
wrong, a technique tip. Make clear it is a suggestion.

If you do not know, say you do not know. A confident wrong answer about someone
else's food culture is worse than no answer.

Answer briefly. The user is usually cooking while reading.`;

interface AssistantRequest {
  question: string;
  recipeId?: string;
  stepIndex?: number;
}

/**
 * Simple per-user rate limiting.
 *
 * Not for cost alone: an unbounded assistant is also a way to turn the app
 * into someone else's free inference endpoint.
 */
async function withinRateLimit(uid: string): Promise<boolean> {
  const db = getFirestore();
  const ref = db.doc(`users/${uid}/ai_usage/hourly`);
  const now = Date.now();

  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const data = snap.data();
    const windowStart = data?.windowStart ?? 0;
    const count = data?.count ?? 0;

    if (now - windowStart > 3_600_000) {
      tx.set(ref, { windowStart: now, count: 1 });
      return true;
    }
    if (count >= HOURLY_LIMIT) return false;

    tx.set(ref, { windowStart, count: count + 1 }, { merge: true });
    return true;
  });
}

export const askAssistant = onCall(
  { region: REGION, secrets: ['ANTHROPIC_API_KEY'] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in to ask a question.');
    }

    const { question, recipeId, stepIndex } =
      (request.data ?? {}) as AssistantRequest;

    if (typeof question !== 'string' || question.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'A question is required.');
    }
    if (question.length > 500) {
      throw new HttpsError('invalid-argument', 'That question is too long.');
    }

    if (!(await withinRateLimit(uid))) {
      throw new HttpsError(
        'resource-exhausted',
        'You have asked a lot of questions this hour. Try again shortly.',
      );
    }

    const apiKey = process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      // Stated rather than faked. A stub answer would be indistinguishable
      // from a real one to the user, which is the worst possible failure for
      // a feature whose whole job is being trustworthy.
      logger.warn('assistant called with no ANTHROPIC_API_KEY configured');
      throw new HttpsError(
        'failed-precondition',
        'The cooking assistant is not configured yet.',
      );
    }

    // Ground the answer in the actual recipe, so [RECIPE] claims are real.
    let context = '';
    if (typeof recipeId === 'string' && recipeId.length > 0) {
      const recipe = await getFirestore().doc(`recipes/${recipeId}`).get();
      const data = recipe.data();
      if (data) {
        const steps = Array.isArray(data.steps) ? data.steps : [];
        const current =
          typeof stepIndex === 'number' ? steps[stepIndex] : undefined;

        context = [
          `The user is cooking: ${data.title}`,
          data.story ? `Cultural note from our archive: ${data.story}` : '',
          current?.text ? `They are on this step: ${current.text}` : '',
          `Ingredients: ${(data.ingredients ?? [])
            .map((i: { name?: string }) => i.name)
            .filter(Boolean)
            .join(', ')}`,
        ]
          .filter(Boolean)
          .join('\n');
      }
    }

    const response = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: 'claude-sonnet-4-5',
        max_tokens: 600,
        system: SYSTEM_PROMPT,
        messages: [
          {
            role: 'user',
            content: context ? `${context}\n\nQuestion: ${question}` : question,
          },
        ],
      }),
    });

    if (!response.ok) {
      logger.error('assistant upstream failed', {
        status: response.status,
        uid,
      });
      throw new HttpsError('unavailable', 'The assistant is unavailable.');
    }

    const payload = (await response.json()) as {
      content?: { type: string; text?: string }[];
    };

    const answer = (payload.content ?? [])
      .filter((block) => block.type === 'text')
      .map((block) => block.text ?? '')
      .join('\n')
      .trim();

    if (answer.length === 0) {
      throw new HttpsError('internal', 'The assistant returned nothing.');
    }

    return { answer };
  },
);
