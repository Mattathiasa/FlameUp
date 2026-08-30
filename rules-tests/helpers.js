import { readFileSync } from 'node:fs';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

export { assertFails, assertSucceeds };

/**
 * Boots a Firestore emulator bound to the real firestore.rules.
 *
 * The rules file is read from the repository rather than duplicated here, so
 * these tests cannot drift from what actually ships.
 */
export async function createTestEnv() {
  return initializeTestEnvironment({
    projectId: 'flameup-rules-test',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
}

/** Firestore for a signed-in user. */
export const asUser = (env, uid) => env.authenticatedContext(uid).firestore();

/** Firestore for a signed-out visitor. */
export const asVisitor = (env) => env.unauthenticatedContext().firestore();

/** Firestore for a moderator, via the custom claim the rules check. */
export const asModerator = (env, uid = 'mod') =>
  env.authenticatedContext(uid, { moderator: true }).firestore();

/**
 * Seeds documents with the rules disabled.
 *
 * Setting fixtures up through the rules would mean a rule change could break
 * the setup and mask the thing under test.
 */
export async function seed(env, write) {
  await env.withSecurityRulesDisabled(async (context) => {
    await write(context.firestore());
  });
}
