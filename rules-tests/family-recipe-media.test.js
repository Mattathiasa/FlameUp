import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';
import { ref, uploadBytes, getBytes, deleteObject } from 'firebase/storage';

import {
  assertFails,
  assertSucceeds,
  createTestEnv,
  storageAsUser,
} from './helpers.js';

const JPEG_BYTES = new Uint8Array([0xff, 0xd8, 0xff, 0xe0]);
const MP4_BYTES = new Uint8Array([
  0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x74, 0x79, 0x6d, 0x70, 0x34, 0x32,
]);

describe("family recipe media lives in its author's own space", () => {
  let env;

  beforeAll(async () => {
    env = await createTestEnv();
  });

  afterAll(async () => {
    await env.cleanup();
  });

  beforeEach(async () => {
    await env.clearStorage();
  });

  it('the author can upload a photo of their dish', async () => {
    const storage = storageAsUser(env, 'liya');
    await assertSucceeds(
      uploadBytes(
        ref(storage, 'users/liya/family_recipes/r1/doro.jpg'),
        JPEG_BYTES,
        { contentType: 'image/jpeg' },
      ),
    );
  });

  it('the author can upload video of the cooking itself', async () => {
    const storage = storageAsUser(env, 'liya');
    await assertSucceeds(
      uploadBytes(
        ref(storage, 'users/liya/family_recipes/r1/shiro.mp4'),
        MP4_BYTES,
        { contentType: 'video/mp4' },
      ),
    );
  });

  it("a stranger cannot write into someone else's media space", async () => {
    // The hole this test exists for: the previous rules let any signed-in
    // user overwrite or delete any other user's uploads, because the path
    // carried no ownership to check against.
    const storage = storageAsUser(env, 'dawit');
    await assertFails(
      uploadBytes(
        ref(storage, 'users/liya/family_recipes/r1/fake.jpg'),
        JPEG_BYTES,
        { contentType: 'image/jpeg' },
      ),
    );
  });

  it("a stranger cannot delete someone else's media", async () => {
    const owner = storageAsUser(env, 'liya');
    const victimRef = ref(owner, 'users/liya/family_recipes/r1/doro.jpg');
    await uploadBytes(victimRef, JPEG_BYTES, { contentType: 'image/jpeg' });

    const stranger = storageAsUser(env, 'dawit');
    await assertFails(deleteObject(ref(stranger, victimRef.fullPath)));
  });

  it('signed-in users can read published-family-recipe media', async () => {
    const owner = storageAsUser(env, 'liya');
    const mediaRef = ref(owner, 'users/liya/family_recipes/r1/doro.jpg');
    await uploadBytes(mediaRef, JPEG_BYTES, { contentType: 'image/jpeg' });

    const reader = storageAsUser(env, 'dawit');
    await assertSucceeds(getBytes(ref(reader, mediaRef.fullPath)));
  });

  it('signed-out visitors cannot read media', async () => {
    const owner = storageAsUser(env, 'liya');
    const mediaRef = ref(owner, 'users/liya/family_recipes/r1/doro.jpg');
    await uploadBytes(mediaRef, JPEG_BYTES, { contentType: 'image/jpeg' });

    const visitor = env.unauthenticatedContext().storage();
    await assertFails(getBytes(ref(visitor, mediaRef.fullPath)));
  });

  it('non-media content types are rejected', async () => {
    // A binary that is neither picture nor video has no place in the
    // archive, whatever its filename claims.
    const storage = storageAsUser(env, 'liya');
    await assertFails(
      uploadBytes(
        ref(storage, 'users/liya/family_recipes/r1/thing.bin'),
        JPEG_BYTES,
        { contentType: 'application/octet-stream' },
      ),
    );
  });
});
