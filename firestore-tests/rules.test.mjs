// 가족 공유 규칙 테스트 — 에뮬레이터 + @firebase/rules-unit-testing
// 결함(2026-09-05 라이브와 동일): 아무나 invites 를 열거하고, 초대코드 없이
// sharedAccess 를 위조해 남의 아기 기록에 닿는다. 아래 1·2·3·6·7·소유자-mismatch
// 는 「고치기 전」 규칙에서 FAIL(침입이 성공하므로) = RED. 규칙을 고치면 전부 GREEN.
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  initializeTestEnvironment, assertFails, assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  doc, setDoc, getDoc, getDocs, deleteDoc, collection, Timestamp,
} from 'firebase/firestore';

const OWNER = 'ownerA';
const BABY = 'babyX';
const CODE = 'ABC234';
const DOCID = `${OWNER}_${BABY}`; // sharedAccess 문서 ID 규약
const future = () => Timestamp.fromMillis(Date.now() + 7 * 864e5);
const past = () => Timestamp.fromMillis(Date.now() - 864e5);

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-babycare',
    firestore: {
      rules: readFileSync('../firestore.rules', 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
});
after(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

// 규칙을 우회해 초기 데이터를 심는다(실제 발급된 초대 등).
async function seedInvite({ code = CODE, owner = OWNER, baby = BABY, isUsed = false, exp = future() } = {}) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'invites', code), {
      code, ownerUserId: owner, babyId: baby, babyName: '아기',
      createdAt: Timestamp.now(), expiresAt: exp, isUsed,
    });
  });
}
function sharedAccessPayload(extra = {}) {
  return {
    ownerUserId: OWNER, babyId: BABY, babyName: '아기',
    role: 'editor', joinedAt: Timestamp.now(), ...extra,
  };
}

// ── 침입 차단 ──────────────────────────────────────────────

test('1. 침입자가 초대코드 없이 sharedAccess 를 위조 생성 — 거부', async () => {
  await seedInvite();
  const intr = env.authenticatedContext('intruder').firestore();
  await assertFails(setDoc(doc(intr, 'users', 'intruder', 'sharedAccess', DOCID),
    sharedAccessPayload())); // inviteCode 없음
});

test('2. 침입자가 틀린 초대코드로 sharedAccess 생성 — 거부', async () => {
  await seedInvite();
  const intr = env.authenticatedContext('intruder').firestore();
  await assertFails(setDoc(doc(intr, 'users', 'intruder', 'sharedAccess', DOCID),
    sharedAccessPayload({ inviteCode: 'WRONG9' })));
});

test('3. 아무나 invites 컬렉션을 열거 — 거부', async () => {
  await seedInvite();
  const intr = env.authenticatedContext('intruder').firestore();
  await assertFails(getDocs(collection(intr, 'invites')));
});

test('6. 만료된 초대로 sharedAccess 생성 — 거부', async () => {
  await seedInvite({ exp: past() });
  const fam = env.authenticatedContext('family').firestore();
  await assertFails(setDoc(doc(fam, 'users', 'family', 'sharedAccess', DOCID),
    sharedAccessPayload({ inviteCode: CODE })));
});

test('7. 이미 쓴 초대(isUsed=true)로 sharedAccess 생성 — 거부', async () => {
  await seedInvite({ isUsed: true });
  const fam = env.authenticatedContext('family').firestore();
  await assertFails(setDoc(doc(fam, 'users', 'family', 'sharedAccess', DOCID),
    sharedAccessPayload({ inviteCode: CODE })));
});

test('소유자가 code≠문서ID 로 초대 생성 — 거부(문서ID=code 규약)', async () => {
  const own = env.authenticatedContext(OWNER).firestore();
  await assertFails(setDoc(doc(own, 'invites', 'MISMAT'), {
    code: 'OTHER1', ownerUserId: OWNER, babyId: BABY, babyName: '아기',
    createdAt: Timestamp.now(), expiresAt: future(), isUsed: false,
  }));
});

// ── 정상 흐름 허용 ─────────────────────────────────────────

test('4. 유효한 초대로 가족이 sharedAccess 생성 — 허용', async () => {
  await seedInvite();
  const fam = env.authenticatedContext('family').firestore();
  await assertSucceeds(setDoc(doc(fam, 'users', 'family', 'sharedAccess', DOCID),
    sharedAccessPayload({ inviteCode: CODE })));
});

test('5. 소유자가 자기 초대를 생성(문서ID=code) — 허용', async () => {
  const own = env.authenticatedContext(OWNER).firestore();
  await assertSucceeds(setDoc(doc(own, 'invites', CODE), {
    code: CODE, ownerUserId: OWNER, babyId: BABY, babyName: '아기',
    createdAt: Timestamp.now(), expiresAt: future(), isUsed: false,
  }));
});

test('5b. 침입자가 남의 ownerUserId 로 초대 생성 — 거부', async () => {
  const intr = env.authenticatedContext('intruder').firestore();
  await assertFails(setDoc(doc(intr, 'invites', 'HACK01'), {
    code: 'HACK01', ownerUserId: OWNER, babyId: BABY, babyName: '아기',
    createdAt: Timestamp.now(), expiresAt: future(), isUsed: false,
  }));
});

test('수락자가 code 를 아는 단건 조회(get) — 허용', async () => {
  await seedInvite();
  const fam = env.authenticatedContext('family').firestore();
  await assertSucceeds(getDoc(doc(fam, 'invites', CODE)));
});

// ── 기존 공유 하위호환 ─────────────────────────────────────

test('8. 기존 공유(inviteCode 없는 sharedAccess)로 아기 기록 읽기 — 허용', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users', 'family', 'sharedAccess', DOCID), sharedAccessPayload());
    await setDoc(doc(db, 'users', OWNER, 'babies', BABY), { name: '아기' });
    await setDoc(doc(db, 'users', OWNER, 'babies', BABY, 'activities', 'a1'), { type: 'feeding_bottle' });
  });
  const fam = env.authenticatedContext('family').firestore();
  await assertSucceeds(getDoc(doc(fam, 'users', OWNER, 'babies', BABY, 'activities', 'a1')));
});

test('8b. 기존 공유(inviteCode 없는 composite)의 update·delete 는 본인이 가능 — 하위호환 관리', async () => {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), 'users', 'family', 'sharedAccess', DOCID), sharedAccessPayload());
  });
  const fam = env.authenticatedContext('family').firestore();
  // 라벨 수정(update) — create 가 아니므로 inviteCode 교차검증 없이 허용되어야 한다
  await assertSucceeds(setDoc(doc(fam, 'users', 'family', 'sharedAccess', DOCID),
    sharedAccessPayload({ relationship: 'grandmother' }), { merge: true }));
  // 공유 해제(delete)
  await assertSucceeds(deleteDoc(doc(fam, 'users', 'family', 'sharedAccess', DOCID)));
});

test('C1. 레거시 마이그레이션 지점: inviteCode 없는 composite sharedAccess create 는 거부', async () => {
  // fetchSharedAccess 의 UUID→composite 마이그레이션(본인이 자기 레거시를 옮김)이 막히는 바로 그 지점.
  // 앱은 await 로 이 거부를 잡아 레거시 원본을 보존해야 한다(소멸 방지). 레거시 가족을 "살리는" 것은
  // 배포 전 서버측 일괄 마이그레이션의 몫.
  const self = env.authenticatedContext('family').firestore();
  await assertFails(setDoc(doc(self, 'users', 'family', 'sharedAccess', DOCID),
    sharedAccessPayload())); // inviteCode 없음
});
