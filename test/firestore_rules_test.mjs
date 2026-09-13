import { readFile } from 'node:fs/promises';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  Timestamp,
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const projectId = 'demo-munib-tests';
const host = '127.0.0.1';
const port = 8080;

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      rules: await readFile('firestore.rules', 'utf8'),
      host,
      port,
    },
  });
});

after(async () => {
  await testEnv.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

function verifiedDb(uid = 'alice') {
  return testEnv
    .authenticatedContext(uid, {
      email: `${uid}@example.com`,
      email_verified: true,
    })
    .firestore();
}

function unverifiedDb(uid = 'alice') {
  return testEnv
    .authenticatedContext(uid, {
      email: `${uid}@example.com`,
      email_verified: false,
    })
    .firestore();
}

async function seedUser(uid, overrides = {}) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const now = Timestamp.fromDate(new Date('2026-09-09T08:00:00Z'));
    await setDoc(doc(context.firestore(), 'users', uid), {
      name: 'Alice User',
      email: `${uid}@example.com`,
      email_verified: true,
      created_at: now,
      last_login: now,
      score: 0,
      ...overrides,
    });
  });
}

describe('users/{uid} access control', () => {
  test('rejects unauthenticated reads', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'users', 'alice')));
  });

  test('rejects reads from unverified email users', async () => {
    await seedUser('alice');
    await assertFails(getDoc(doc(unverifiedDb(), 'users', 'alice')));
  });

  test('allows a verified owner to read their own profile', async () => {
    await seedUser('alice');
    await assertSucceeds(getDoc(doc(verifiedDb(), 'users', 'alice')));
  });

  test('rejects access to another user profile', async () => {
    await seedUser('bob');
    await assertFails(getDoc(doc(verifiedDb('alice'), 'users', 'bob')));
  });
});

describe('profile creation', () => {
  test('allows a verified owner to create a valid profile', async () => {
    const db = verifiedDb();
    await assertSucceeds(
      setDoc(doc(db, 'users', 'alice'), {
        name: 'Alice User',
        email: 'alice@example.com',
        email_verified: true,
        created_at: serverTimestamp(),
        last_login: serverTimestamp(),
        score: 0,
      }),
    );
  });

  test('rejects unverified users and foreign document ids', async () => {
    await assertFails(
      setDoc(doc(unverifiedDb(), 'users', 'alice'), {
        name: 'Alice User',
        email: 'alice@example.com',
        email_verified: false,
        score: 0,
      }),
    );

    await assertFails(
      setDoc(doc(verifiedDb('alice'), 'users', 'bob'), {
        name: 'Alice User',
        email: 'alice@example.com',
        email_verified: true,
        score: 0,
      }),
    );
  });

  test('rejects unknown fields, score tampering, and identity spoofing', async () => {
    const db = verifiedDb();
    const ref = doc(db, 'users', 'alice');

    await assertFails(
      setDoc(ref, {
        name: 'Alice User',
        email: 'alice@example.com',
        email_verified: true,
        score: 0,
        admin: true,
      }),
    );

    await assertFails(
      setDoc(ref, {
        name: 'Alice User',
        email: 'alice@example.com',
        email_verified: true,
        score: 50,
      }),
    );

    await assertFails(
      setDoc(ref, {
        name: 'Alice User',
        email: 'other@example.com',
        email_verified: true,
        score: 0,
      }),
    );
  });
});

describe('30-day display-name enforcement', () => {
  test('allows the first manual rename and requires server time', async () => {
    await seedUser('alice');
    const ref = doc(verifiedDb(), 'users', 'alice');

    await assertSucceeds(
      updateDoc(ref, {
        name: 'Alice Renamed',
        name_updated_at: serverTimestamp(),
      }),
    );
  });

  test('blocks another rename before 30 days', async () => {
    await seedUser('alice', {
      name_updated_at: Timestamp.fromDate(
        new Date(Date.now() - 29 * 24 * 60 * 60 * 1000),
      ),
    });
    const ref = doc(verifiedDb(), 'users', 'alice');

    await assertFails(
      updateDoc(ref, {
        name: 'Alice Too Soon',
        name_updated_at: serverTimestamp(),
      }),
    );
  });

  test('allows a rename after the cooldown expires', async () => {
    await seedUser('alice', {
      name_updated_at: Timestamp.fromDate(
        new Date(Date.now() - 31 * 24 * 60 * 60 * 1000),
      ),
    });
    const ref = doc(verifiedDb(), 'users', 'alice');

    await assertSucceeds(
      updateDoc(ref, {
        name: 'Alice Allowed',
        name_updated_at: serverTimestamp(),
      }),
    );
  });

  test('rejects client-forged name_updated_at timestamps', async () => {
    await seedUser('alice');
    const ref = doc(verifiedDb(), 'users', 'alice');

    await assertFails(
      updateDoc(ref, {
        name: 'Alice Forged',
        name_updated_at: Timestamp.fromDate(new Date('2030-01-01T00:00:00Z')),
      }),
    );
  });
});

describe('protected and Cloudinary profile fields', () => {
  test('blocks score, created_at, and email verification tampering', async () => {
    await seedUser('alice');
    const ref = doc(verifiedDb(), 'users', 'alice');

    await assertFails(updateDoc(ref, { score: 999 }));
    await assertFails(updateDoc(ref, { created_at: serverTimestamp() }));
    await assertFails(updateDoc(ref, { email_verified: false }));
  });

  test('allows Cloudinary photo metadata updates with valid types', async () => {
    await seedUser('alice');
    const ref = doc(verifiedDb(), 'users', 'alice');

    await assertSucceeds(
      updateDoc(ref, {
        photo_url: 'https://res.cloudinary.com/demo/image/upload/profile.jpg',
        photo_public_id: 'munib/profiles/alice',
        photo_updated_at: serverTimestamp(),
      }),
    );
  });

  test('verified owner can delete own profile but not another profile', async () => {
    await seedUser('alice');
    await seedUser('bob');

    await assertSucceeds(deleteDoc(doc(verifiedDb('alice'), 'users', 'alice')));
    await assertFails(deleteDoc(doc(verifiedDb('alice'), 'users', 'bob')));
  });
});
