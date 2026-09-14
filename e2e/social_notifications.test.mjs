/**
 * End-to-end verification of the social notification flow against the
 * emulator suite: two real Auth users, a friend request sent through the
 * production Firestore rules, the Cloud Function triggers writing the
 * notifications, then an accept and the "now friends" notification.
 *
 * Run under `firebase emulators:exec` so the suite is up for the duration.
 * Assertions go straight at Firestore documents -- no client code involved
 * -- which is what makes this an E2E of the whole loop (rules + triggers),
 * not of any one layer.
 */
import { initializeApp, deleteApp } from 'firebase/app';
import {
  getAuth,
  createUserWithEmailAndPassword,
  connectAuthEmulator,
} from 'firebase/auth';
import {
  getFirestore,
  connectFirestoreEmulator,
  doc,
  setDoc,
  getDoc,
  collection,
  getDocs,
} from 'firebase/firestore';

const project = 'flameup-78d15';

// Format-checked by the SDK even though the emulator ignores the value.
const API_KEY = 'AIzaSyCOAHGYbqc2RGMcRyo04WIcPsXVL4wlt68';

function client() {
  const app = initializeApp({ projectId: project, apiKey: API_KEY }, `app-${Math.random()}`);
  const auth = getAuth(app);
  const db = getFirestore(app);
  // Deliberate and explicit: without these the SDK would happily talk to
  // production, which is the one mistake this script must never make.
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  connectFirestoreEmulator(db, '127.0.0.1', 8080);
  return { auth, db, app };
}

const results = [];
function check(name, ok, detail = '') {
  results.push({ name, ok, detail });
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ` -- ${detail}` : ''}`);
}

async function waitFor(fn, { timeoutMs = 20000, everyMs = 500, label = 'condition' } = {}) {
  const deadline = Date.now() + timeoutMs;
  let last = {};
  while (Date.now() < deadline) {
    last = (await fn()) ?? {};
    if (last.ok) return last;
    await new Promise((r) => setTimeout(r, everyMs));
  }
  return { ok: false, reason: `${label}: timed out` };
}

// --- the flow ----------------------------------------------------------------

const liya = client();
const dawit = client();

try {
  // 1. Two real users in the Auth emulator.
  const liyaCred = await createUserWithEmailAndPassword(
    liya.auth, 'liya.e2e@flameup.test', 'Password123!',
  );
  const dawitCred = await createUserWithEmailAndPassword(
    dawit.auth, 'dawit.e2e@flameup.test', 'Password123!',
  );
  const liyaUid = liyaCred.user.uid;
  const dawitUid = dawitCred.user.uid;
  check('two auth users created', true, `liya=${liyaUid.slice(0, 8)} dawit=${dawitUid.slice(0, 8)}`);

  // Profiles + directory cards, exactly as the client would write them.
  await setDoc(doc(liya.db, 'users', liyaUid), {
    displayName: 'Liya', skillLevel: 'beginner', heatTolerance: 'mild',
    dietary: [], onboardingComplete: true,
  });
  await setDoc(doc(dawit.db, 'users', dawitUid), {
    displayName: 'Dawit', skillLevel: 'home_cook', heatTolerance: 'hot',
    dietary: [], onboardingComplete: true,
  });
  const { DirectoryUser: _ } = {};
  // friendCode = first 8 hex of sha256(uid) -- computed in-script via node:crypto.
  const { createHash } = await import('node:crypto');
  const codeOf = (uid) => createHash('sha256').update(uid).digest('hex').slice(0, 8);
  await setDoc(doc(liya.db, 'user_directory', liyaUid), {
    uid: liyaUid, displayName: 'Liya', nameSearch: 'liya', friendCode: codeOf(liyaUid),
  });
  await setDoc(doc(dawit.db, 'user_directory', dawitUid), {
    uid: dawitUid, displayName: 'Dawit', nameSearch: 'dawit', friendCode: codeOf(dawitUid),
  });
  check('profiles + directory cards written', true);

  // 2. Liya sends the friend request -- client-shaped, rules-checked.
  const reqPayload = {
    otherUid: dawitUid, direction: 'incoming', status: 'pending',
    displayName: 'Liya', createdAt: new Date().toISOString(),
  };
  await setDoc(doc(liya.db, 'users', dawitUid, 'friend_requests', liyaUid), reqPayload);
  await setDoc(doc(liya.db, 'users', liyaUid, 'friend_requests', dawitUid), {
    otherUid: dawitUid, direction: 'outgoing', status: 'pending',
    displayName: '', createdAt: new Date().toISOString(),
  });
  check('friend request sent through rules', true);

  // 3. The onFriendRequestCreated trigger writes Dawit's notification.
  const reqNotif = await waitFor(async () => {
    const snap = await getDoc(doc(dawit.db, 'users', dawitUid, 'notifications', `friend_request_${liyaUid}`));
    return snap.exists() && snap.data().type === 'friendRequest'
      ? { ok: true }
      : { ok: false };
  }, { label: 'request notification' });
  check('Dawit received the friend-request notification', reqNotif.ok);

  // 4. Dawit accepts -- the client's two-mirror batch, rules-checked.
  const since = new Date().toISOString();
  await setDoc(doc(dawit.db, 'users', dawitUid, 'friends', liyaUid), { displayName: 'Liya', since });
  await setDoc(doc(dawit.db, 'users', liyaUid, 'friends', dawitUid), { displayName: 'Dawit', since });
  check('request accepted (both mirrors written)', true);

  // 5. BOTH sides learn the friendship formed: the accept flow writes both
  //    mirrors, and each side's notification lands under its own uid. The
  //    acceptor's copy is a confirmation, not an echo.
  const addedForLiya = await waitFor(async () => {
    const snap = await getDoc(doc(liya.db, 'users', liyaUid, 'notifications', `friend_added_${dawitUid}`));
    return snap.exists() && snap.data().type === 'friendAdded' ? { ok: true } : { ok: false };
  }, { label: 'friend-added notification for liya' });
  check('Liya received the friend-added notification', addedForLiya.ok);

  const addedForDawit = await waitFor(async () => {
    const snap = await getDoc(doc(dawit.db, 'users', dawitUid, 'notifications', `friend_added_${liyaUid}`));
    return snap.exists() && snap.data().type === 'friendAdded' ? { ok: true } : { ok: false };
  }, { label: 'friend-added notification for dawit' });
  check('Dawit received the friend-added confirmation too', addedForDawit.ok);

  // 6. Mark-as-read honors the rules (client may set readAt only).
  await setDoc(
    doc(dawit.db, 'users', dawitUid, 'notifications', `friend_request_${liyaUid}`),
    { readAt: new Date().toISOString() },
    { merge: true },
  );
  const marked = await getDoc(doc(dawit.db, 'users', dawitUid, 'notifications', `friend_request_${liyaUid}`));
  check('mark-as-read accepted by rules', marked.exists() && !!marked.data().readAt);

  const all = await getDocs(collection(dawit.db, 'users', dawitUid, 'notifications'));
  check('notification list for dawit', all.size >= 2, `${all.size} document(s)`);
} catch (err) {
  check('unexpected exception', false, String(err));
} finally {
  await deleteApp(liya.app).catch(() => {});
  await deleteApp(dawit.app).catch(() => {});
}

const failed = results.filter((r) => !r.ok);
console.log(`\n${results.length - failed.length}/${results.length} checks passed`);
process.exit(failed.length ? 1 : 0);
