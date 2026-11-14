// 손님 기기에 남은 옛 판의 요청 — 2.8.13(2026-11-08 출시 · 빌드 117 · 커밋 ec7ac1d)
//
// 왜: 2026-11-11 규칙을 조여 배포했는데, 그때 손님 전원이 쓰던 2.8.13 엔 맞춘 코드가 없었다. 영향을 「초대 화면」만
// 세고 보고해, 아기 삭제·계정 삭제 끝의 초대 목록 조회가 막힌 것을 3일 뒤에야 찾았다(아기 삭제가 「실패」로 뜨고
// 사진 정리를 건너뜀). 규칙을 바꿀 때 이 파일이 「손님 기기에 남은 판이 무엇에 막히나」를 보여 준다.
//
// 쓰는 법: 요청 모양은 그 판 출시 커밋의 코드에서 옮긴다(`git show ec7ac1d:BabyCare/Services/FirestoreService+Family.swift` 등).
// 기대(허용/거부)는 「그 판 손님에게 맞는 동작」 — 보안상 막아야 하는 것(초대 만들기·받기)은 거부가 정답이고,
// 막혀선 안 되는 것(아기·계정 삭제의 정리)은 허용이 정답이다. 새 판이 나가면 그 판의 파일을 같은 꼴로 더하고,
// 옛 판 파일은 최소 지원 판이 그 위로 올라갈 때까지 지우지 않는다.
import { test, before, after, beforeEach } from 'node:test';
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc, setDoc, getDocs, deleteDoc, collection, query, where, limit, Timestamp,
} from 'firebase/firestore';

const OWNER = 'ownerA';
const BABY = 'babyX';
const CODE = 'ABC234';
const JOINER = 'family';
const future = () => Timestamp.fromMillis(Date.now() + 7 * 864e5);

let env;
before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-babycare',
    firestore: { rules: readFileSync('../firestore.rules', 'utf8'), host: '127.0.0.1', port: 8080 },
  });
});
after(async () => { await env.cleanup(); });
beforeEach(async () => { await env.clearFirestore(); });

const as = (uid) => env.authenticatedContext(uid).firestore();
async function seed(fn) { await env.withSecurityRulesDisabled(async (ctx) => fn(ctx.firestore())); }
const invite = (extra = {}) => ({
  code: CODE, ownerUserId: OWNER, babyId: BABY, babyName: '아기',
  createdAt: Timestamp.now(), expiresAt: future(), isUsed: false, ...extra,
});

// ── 막혀선 안 되는 것 — 2.8.13 의 삭제 흐름 ─────────────────────────────────────────

test('[2.8.13 아기 삭제] 하위 기록·아기 문서·아기 수 갱신 → 끝의 「그 아기 내 초대」 목록 조회·삭제 — 허용', async () => {
  // FirestoreService+Baby.deleteBaby(ec7ac1d): 하위 컬렉션 문서 하나씩 지움 → 아기 문서 → babyCount -1 →
  // invites where ownerUserId == 나 && babyId == 그 아기 → 하나씩 지움. 마지막 조회가 막히면 앱은 「아기 삭제에 실패」.
  await seed(async (db) => {
    await setDoc(doc(db, 'users', OWNER, 'babies', BABY), { name: '아기' });
    await setDoc(doc(db, 'users', OWNER, 'babies', BABY, 'activities', 'a1'), { type: 'feeding' });
    await setDoc(doc(db, 'invites', CODE), invite());
  });
  const own = as(OWNER);
  await assertSucceeds(deleteDoc(doc(own, 'users', OWNER, 'babies', BABY, 'activities', 'a1')));
  await assertSucceeds(deleteDoc(doc(own, 'users', OWNER, 'babies', BABY)));
  await assertSucceeds(setDoc(doc(own, 'users', OWNER), { babyCount: 0 }, { merge: true }));
  await assertSucceeds(getDocs(query(collection(own, 'invites'),
    where('ownerUserId', '==', OWNER), where('babyId', '==', BABY))));
  await assertSucceeds(deleteDoc(doc(own, 'invites', CODE)));
});

test('[2.8.13 계정 삭제] 끝의 「내 초대 전부」 목록 조회 — 허용', async () => {
  // FirestoreService+User.deleteAllUserData(ec7ac1d) 끝: invites where ownerUserId == 나.
  // (2.8.13 계정 삭제는 이와 별개로 로그인을 먼저 지워 기록을 못 지운다 — 2.8.14 에서 고침. 이 조회만은 막지 않는다.)
  await seed((db) => setDoc(doc(db, 'invites', CODE), invite()));
  await assertSucceeds(getDocs(query(collection(as(OWNER), 'invites'), where('ownerUserId', '==', OWNER))));
});

// ── 막아야 하는 것 — 보안 구멍(11/11)이 다시 열리지 않게. 2.8.13 손님은 2.8.14 로 올려야 초대가 된다 ──────────

test('[2.8.13 초대 받기] 코드·사용 여부 조건 목록 — 거부(아무 초대나 한 장씩 열거할 수 있다)', async () => {
  await seed((db) => setDoc(doc(db, 'invites', CODE), invite()));
  await assertFails(getDocs(query(collection(as(JOINER), 'invites'),
    where('code', '==', CODE), where('isUsed', '==', false), limit(1))));
});

test('[2.8.13 초대 만들기] 문서 이름 = UUID(코드 아님) — 거부', async () => {
  await assertFails(setDoc(doc(as(OWNER), 'invites', '5F0E2C1A-7B7D-4E1B-9C59-2D1B7F1A9E11'), invite()));
});

test('[2.8.13 초대 받기] inviteCode 없는 공유 문서 만들기 — 거부(위조 공유)', async () => {
  await seed((db) => setDoc(doc(db, 'invites', CODE), invite()));
  await assertFails(setDoc(doc(as(JOINER), 'users', JOINER, 'sharedAccess', `${OWNER}_${BABY}`), {
    ownerUserId: OWNER, babyId: BABY, babyName: '아기', role: 'editor', joinedAt: Timestamp.now(),
  }));
});

// ── 원래부터 닿지 못하는 옛 자리 — 규칙이 없다(2026-03-03 이후). 바뀌면 일부러 바꾼 것인지 확인할 것 ─────────

test('[2.8.13 계정 삭제] 사용자 바로 아래 옛 이름 4개(activities·diaryEntries·purchaseRecords·familySharing) — 거부', async () => {
  const own = as(OWNER);
  for (const name of ['activities', 'diaryEntries', 'purchaseRecords', 'familySharing']) {
    await assertFails(getDocs(collection(own, 'users', OWNER, name)));
  }
});
