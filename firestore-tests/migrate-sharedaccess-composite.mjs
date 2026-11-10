// C1 배포 전 마이그레이션 — 레거시 UUID-keyed sharedAccess → composite {ownerUserId}_{babyId}
//
// 왜: 강화된 sharedAccess create 규칙은 inviteCode 없는 레거시 문서의 composite 생성을 거부한다.
// 2026-03-23(313e01c) 이전에 공유를 맺고 그 뒤 앱을 안 연 휴면 가족은 아직 UUID-keyed 문서를
// 갖고 있을 수 있다. 규칙을 배포하기 "전에" Admin SDK(규칙 우회)로 composite 로 옮겨두면,
// 클라이언트 마이그레이션이 발동하지 않고 아기 공유 규칙 exists({owner}_{baby}) 를 만족한다.
//
// 멱등: 재실행해도 composite 문서는 건너뛰고, UUID 문서만 처리한다. 레거시가 0이면 무해(변경 0).
// 안전: 기본은 DRY-RUN(아무것도 안 바꿈). 실제 적용은 --apply 플래그.
//
// 실행 (서비스계정 필요 — babycare-admin/.env.local 의 FIREBASE_SERVICE_ACCOUNT(base64) 재사용):
//   FIREBASE_SERVICE_ACCOUNT="$(grep '^FIREBASE_SERVICE_ACCOUNT=' /Users/roque/babycare-admin/.env.local | cut -d= -f2-)" \
//     node migrate-sharedaccess-composite.mjs            # dry-run: 몇 건을 바꿀지만 출력
//   ... 같은 env ... node migrate-sharedaccess-composite.mjs --apply   # 실제 변환
// 또는 GOOGLE_APPLICATION_CREDENTIALS=<path/to/serviceAccount.json> 로도 가능.
import admin from 'firebase-admin';

const APPLY = process.argv.includes('--apply');

function loadCredential() {
  const b64 = process.env.FIREBASE_SERVICE_ACCOUNT;
  if (b64) {
    const raw = b64.trim().replace(/^["']|["']$/g, '');
    let json;
    try { json = JSON.parse(Buffer.from(raw, 'base64').toString('utf8')); }
    catch { json = JSON.parse(raw); }
    return admin.credential.cert(json);
  }
  if (process.env.GOOGLE_APPLICATION_CREDENTIALS) return admin.credential.applicationDefault();
  throw new Error('서비스계정 없음: FIREBASE_SERVICE_ACCOUNT(base64) 또는 GOOGLE_APPLICATION_CREDENTIALS 설정 필요');
}

const isUuid = (id) => /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id);

admin.initializeApp({ credential: loadCredential() });
const db = admin.firestore();

(async () => {
  const snap = await db.collectionGroup('sharedAccess').get();
  let legacy = 0, migrated = 0, deletedDup = 0, skippedBadData = 0;

  for (const doc of snap.docs) {
    if (!isUuid(doc.id)) continue; // composite(또는 기타)는 그대로 둔다
    legacy++;
    const d = doc.data();
    if (!d.ownerUserId || !d.babyId) { skippedBadData++; continue; }
    const parentUid = doc.ref.parent.parent.id; // users/{uid}/sharedAccess
    const expectedId = `${d.ownerUserId}_${d.babyId}`;
    const compositeRef = db.collection('users').doc(parentUid).collection('sharedAccess').doc(expectedId);
    const existing = await compositeRef.get();
    if (existing.exists) {
      if (APPLY) await doc.ref.delete(); // composite 이미 있음 → 중복 UUID 원본 제거
      deletedDup++;
    } else {
      if (APPLY) {
        await compositeRef.set(d);   // composite 생성(규칙 우회 · 데이터 그대로)
        await doc.ref.delete();      // UUID 원본 제거
      }
      migrated++;
    }
  }

  console.log(JSON.stringify({
    mode: APPLY ? 'APPLY (실제 변환함)' : 'DRY-RUN (아무것도 안 바꿈)',
    totalSharedAccess: snap.size,
    legacyUuidFound: legacy,
    migratedToComposite: migrated,
    deletedDuplicateUuid: deletedDup,
    skippedMissingFields: skippedBadData,
  }, null, 2));
  process.exit(0);
})().catch((e) => { console.error('ERR:', e.message); process.exit(1); });
