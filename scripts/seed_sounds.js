#!/usr/bin/env node
/**
 * seed_sounds.js
 * Firebase Firestore `sounds` 컬렉션에 60개 트랙 시드
 *
 * 사용법:
 *   npm install firebase-admin
 *   GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json node seed_sounds.js
 *
 * Firebase 프로젝트: lotto-app-47230
 */

const admin = require("firebase-admin");

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  storageBucket: "lotto-app-47230.appspot.com",
});

const db = admin.firestore();

// ─────────────────────────────────────────────
// 기존 10개 로컬 사운드 (isLocal: true)
// ─────────────────────────────────────────────
const localSounds = [
  {
    id: "white_noise",
    name: "화이트 노이즈",
    artist: "BabyCare",
    category: "백색소음",
    duration: 0,
    storageURL: "",
    iconName: "waveform",
    isFree: true,
    sortOrder: 0,
    isLocal: true,
    localFileName: "white_noise.wav",
  },
  {
    id: "pink_noise",
    name: "핑크 노이즈",
    artist: "BabyCare",
    category: "백색소음",
    duration: 0,
    storageURL: "",
    iconName: "waveform.badge.minus",
    isFree: true,
    sortOrder: 1,
    isLocal: true,
    localFileName: "pink_noise.wav",
  },
  {
    id: "rain",
    name: "빗소리",
    artist: "BabyCare",
    category: "자연",
    duration: 0,
    storageURL: "",
    iconName: "cloud.rain.fill",
    isFree: true,
    sortOrder: 10,
    isLocal: true,
    localFileName: "rain.wav",
  },
  {
    id: "ocean",
    name: "파도소리",
    artist: "BabyCare",
    category: "자연",
    duration: 0,
    storageURL: "",
    iconName: "water.waves",
    isFree: true,
    sortOrder: 11,
    isLocal: true,
    localFileName: "ocean.wav",
  },
  {
    id: "birds",
    name: "새소리",
    artist: "BabyCare",
    category: "자연",
    duration: 0,
    storageURL: "",
    iconName: "bird.fill",
    isFree: true,
    sortOrder: 12,
    isLocal: true,
    localFileName: "birds.wav",
  },
  {
    id: "heartbeat",
    name: "심장박동",
    artist: "BabyCare",
    category: "생활",
    duration: 0,
    storageURL: "",
    iconName: "heart.fill",
    isFree: true,
    sortOrder: 20,
    isLocal: true,
    localFileName: "heartbeat.wav",
  },
  {
    id: "fan",
    name: "선풍기",
    artist: "BabyCare",
    category: "생활",
    duration: 0,
    storageURL: "",
    iconName: "fan.fill",
    isFree: true,
    sortOrder: 21,
    isLocal: true,
    localFileName: "fan.wav",
  },
  {
    id: "shushing",
    name: "쉬 소리",
    artist: "BabyCare",
    category: "생활",
    duration: 0,
    storageURL: "",
    iconName: "mouth.fill",
    isFree: true,
    sortOrder: 22,
    isLocal: true,
    localFileName: "shushing.wav",
  },
  {
    id: "lullaby",
    name: "자장가",
    artist: "BabyCare",
    category: "자장가",
    duration: 0,
    storageURL: "",
    iconName: "moon.stars.fill",
    isFree: true,
    sortOrder: 30,
    isLocal: true,
    localFileName: "lullaby.wav",
  },
  {
    id: "music_box",
    name: "오르골",
    artist: "BabyCare",
    category: "자장가",
    duration: 0,
    storageURL: "",
    iconName: "music.note.list",
    isFree: true,
    sortOrder: 31,
    isLocal: true,
    localFileName: "music_box.wav",
  },
];

// ─────────────────────────────────────────────
// 클래식 50개 (storageURL = Firebase Storage 경로)
// ─────────────────────────────────────────────

// 모차르트 10곡 (sortOrder 100~109)
const mozartTracks = [
  { id: "mozart_lullaby",          name: "자장가 K.350",                    duration: 180, fileName: "mozart_lullaby.m4a",          sortOrder: 100 },
  { id: "mozart_piano11_3",        name: "피아노 소나타 11번 3악장",           duration: 210, fileName: "mozart_piano_sonata11_3.m4a",  sortOrder: 101 },
  { id: "mozart_eine_kleine",      name: "아이네 클라이네 나흐트무지크",         duration: 360, fileName: "mozart_eine_kleine.m4a",       sortOrder: 102 },
  { id: "mozart_piano21_2",        name: "피아노 협주곡 21번 2악장",            duration: 420, fileName: "mozart_piano_conc21_2.m4a",    sortOrder: 103 },
  { id: "mozart_flute_harp_2",     name: "플루트와 하프 협주곡 2악장",           duration: 390, fileName: "mozart_flute_harp_2.m4a",      sortOrder: 104 },
  { id: "mozart_sym40_1",          name: "교향곡 40번 1악장",                  duration: 480, fileName: "mozart_symphony40_1.m4a",      sortOrder: 105 },
  { id: "mozart_turkish_march",    name: "터키 행진곡",                       duration: 210, fileName: "mozart_turkish_march.m4a",     sortOrder: 106 },
  { id: "mozart_piano16",          name: "피아노 소나타 16번",                  duration: 300, fileName: "mozart_piano_sonata16.m4a",    sortOrder: 107 },
  { id: "mozart_clarinet_2",       name: "클라리넷 협주곡 2악장",               duration: 450, fileName: "mozart_clarinet_conc_2.m4a",   sortOrder: 108 },
  { id: "mozart_divertimento136",  name: "디베르티멘토 K.136",                  duration: 270, fileName: "mozart_divertimento136.m4a",   sortOrder: 109 },
].map((t) => ({
  ...t,
  artist: "모차르트",
  category: "클래식-모차르트",
  storageURL: `sounds/classical/${t.fileName}`,
  iconName: "music.note",
  isFree: true,
  isLocal: false,
  localFileName: null,
}));

// 바흐 8곡 (sortOrder 200~207)
const bachTracks = [
  { id: "bach_air_g",           name: "G선상의 아리아",                   duration: 420, fileName: "bach_air_on_g_string.m4a",     sortOrder: 200 },
  { id: "bach_goldberg_aria",   name: "골드베르크 변주곡 아리아",             duration: 300, fileName: "bach_goldberg_aria.m4a",        sortOrder: 201 },
  { id: "bach_cello1_prelude",  name: "무반주 첼로 모음곡 1번 프렐류드",       duration: 150, fileName: "bach_cello_suite1_prelude.m4a", sortOrder: 202 },
  { id: "bach_jesu_joy",        name: "예수 인간 소망의 기쁨",               duration: 210, fileName: "bach_jesu_joy.m4a",             sortOrder: 203 },
  { id: "bach_brandenburg3",    name: "브란덴부르크 협주곡 3번",              duration: 540, fileName: "bach_brandenburg3.m4a",         sortOrder: 204 },
  { id: "bach_wt_prelude1",     name: "평균율 클라비어 1번 프렐류드",          duration: 150, fileName: "bach_wt_prelude1.m4a",          sortOrder: 205 },
  { id: "bach_minuet_g",        name: "미뉴에트 G장조",                    duration: 120, fileName: "bach_minuet_g.m4a",             sortOrder: 206 },
  { id: "bach_sheep_grazing",   name: "양떼는 평화로이 풀을 뜯고",            duration: 270, fileName: "bach_sheep_grazing.m4a",         sortOrder: 207 },
].map((t) => ({
  ...t,
  artist: "바흐",
  category: "클래식-바흐",
  storageURL: `sounds/classical/${t.fileName}`,
  iconName: "music.quarternote.3",
  isFree: true,
  isLocal: false,
  localFileName: null,
}));

// 쇼팽 8곡 (sortOrder 300~307)
const chopinTracks = [
  { id: "chopin_nocturne9_2",   name: "녹턴 Op.9 No.2",    duration: 270, fileName: "chopin_nocturne9_2.m4a",   sortOrder: 300 },
  { id: "chopin_berceuse57",    name: "자장가 Op.57",       duration: 240, fileName: "chopin_berceuse57.m4a",    sortOrder: 301 },
  { id: "chopin_raindrop",      name: "빗방울 전주곡",       duration: 300, fileName: "chopin_raindrop.m4a",      sortOrder: 302 },
  { id: "chopin_farewell",      name: "이별의 곡",           duration: 300, fileName: "chopin_etude10_3.m4a",     sortOrder: 303 },
  { id: "chopin_ballade1",      name: "발라드 1번",          duration: 540, fileName: "chopin_ballade1.m4a",      sortOrder: 304 },
  { id: "chopin_spring_waltz",  name: "봄 왈츠",             duration: 210, fileName: "chopin_spring_waltz.m4a",  sortOrder: 305 },
  { id: "chopin_nocturne48_1",  name: "녹턴 Op.48 No.1",   duration: 360, fileName: "chopin_nocturne48_1.m4a",  sortOrder: 306 },
  { id: "chopin_prelude28_15",  name: "전주곡 Op.28 No.15", duration: 330, fileName: "chopin_prelude28_15.m4a",  sortOrder: 307 },
].map((t) => ({
  ...t,
  artist: "쇼팽",
  category: "클래식-쇼팽",
  storageURL: `sounds/classical/${t.fileName}`,
  iconName: "pianokeys.inverse",
  isFree: true,
  isLocal: false,
  localFileName: null,
}));

// 드뷔시 6곡 (sortOrder 400~405)
const debussyTracks = [
  { id: "debussy_clair_de_lune",  name: "달빛",                  duration: 360, fileName: "debussy_clair_de_lune.m4a",   sortOrder: 400 },
  { id: "debussy_arabesque1",     name: "아라베스크 1번",           duration: 240, fileName: "debussy_arabesque1.m4a",      sortOrder: 401 },
  { id: "debussy_flaxen_hair",    name: "아마색 머리 소녀",          duration: 180, fileName: "debussy_flaxen_hair.m4a",     sortOrder: 402 },
  { id: "debussy_reverie",        name: "꿈",                    duration: 270, fileName: "debussy_reverie.m4a",          sortOrder: 403 },
  { id: "debussy_faun",           name: "목신의 오후에의 전주곡",     duration: 660, fileName: "debussy_afternoon_faun.m4a",  sortOrder: 404 },
  { id: "debussy_reflections",    name: "물의 반영",               duration: 300, fileName: "debussy_reflections.m4a",     sortOrder: 405 },
].map((t) => ({
  ...t,
  artist: "드뷔시",
  category: "클래식-드뷔시",
  storageURL: `sounds/classical/${t.fileName}`,
  iconName: "water.waves",
  isFree: true,
  isLocal: false,
  localFileName: null,
}));

// 브람스 5곡 (sortOrder 500~504)
const brahmsTracks = [
  { id: "brahms_lullaby",       name: "자장가",               duration: 180, fileName: "brahms_lullaby.m4a",       sortOrder: 500 },
  { id: "brahms_hungarian5",    name: "헝가리 무곡 5번",        duration: 210, fileName: "brahms_hungarian5.m4a",    sortOrder: 501 },
  { id: "brahms_sym3_3",        name: "교향곡 3번 3악장",       duration: 420, fileName: "brahms_symphony3_3.m4a",   sortOrder: 502 },
  { id: "brahms_intermezzo118", name: "간주곡 Op.118 No.2",   duration: 300, fileName: "brahms_intermezzo118.m4a", sortOrder: 503 },
  { id: "brahms_waltz39_15",    name: "왈츠 Op.39 No.15",     duration: 150, fileName: "brahms_waltz39_15.m4a",    sortOrder: 504 },
].map((t) => ({
  ...t,
  artist: "브람스",
  category: "클래식-기타",
  storageURL: `sounds/classical/${t.fileName}`,
  iconName: "music.note.list",
  isFree: true,
  isLocal: false,
  localFileName: null,
}));

// 기타 클래식 13곡 (sortOrder 600~612)
const classicEtcTracks = [
  { id: "saintSaens_swan",      name: "백조",                   artist: "생상스",    duration: 240, fileName: "saintsaens_swan.m4a",        sortOrder: 600 },
  { id: "tchaikovsky_swan",     name: "백조의 호수",              artist: "차이콥스키", duration: 300, fileName: "tchaikovsky_swan_lake.m4a",   sortOrder: 601 },
  { id: "tchaikovsky_waltz",    name: "호두까기인형 꽃의 왈츠",    artist: "차이콥스키", duration: 240, fileName: "tchaikovsky_waltz_flowers.m4a",sortOrder: 602 },
  { id: "vivaldi_spring",       name: "사계 봄",                 artist: "비발디",    duration: 780, fileName: "vivaldi_spring.m4a",           sortOrder: 603 },
  { id: "beethoven_moonlight",  name: "월광 소나타",              artist: "베토벤",    duration: 390, fileName: "beethoven_moonlight.m4a",      sortOrder: 604 },
  { id: "beethoven_fur_elise",  name: "엘리제를 위하여",           artist: "베토벤",    duration: 180, fileName: "beethoven_fur_elise.m4a",      sortOrder: 605 },
  { id: "schubert_lullaby",     name: "자장가",                  artist: "슈베르트",  duration: 180, fileName: "schubert_lullaby.m4a",         sortOrder: 606 },
  { id: "schumann_traumerei",   name: "트로이메라이",             artist: "슈만",      duration: 210, fileName: "schumann_traumerei.m4a",       sortOrder: 607 },
  { id: "grieg_morning",        name: "아침",                   artist: "그리그",    duration: 240, fileName: "grieg_morning_mood.m4a",       sortOrder: 608 },
  { id: "satie_gymnopedie1",    name: "짐노페디 1번",             artist: "사티",      duration: 210, fileName: "satie_gymnopedie1.m4a",        sortOrder: 609 },
  { id: "pachelbel_canon",      name: "캐논",                   artist: "파헬벨",    duration: 300, fileName: "pachelbel_canon.m4a",          sortOrder: 610 },
  { id: "elgar_salut_damour",   name: "사랑의 인사",              artist: "엘가",      duration: 210, fileName: "elgar_salut_damour.m4a",       sortOrder: 611 },
  { id: "massenet_meditation",  name: "타이스의 명상곡",           artist: "마스네",    duration: 360, fileName: "massenet_meditation.m4a",      sortOrder: 612 },
].map((t) => ({
  ...t,
  category: "클래식-기타",
  storageURL: `sounds/classical/${t.fileName}`,
  iconName: "music.note.list",
  isFree: true,
  isLocal: false,
  localFileName: null,
}));

// ─────────────────────────────────────────────
// 전체 합산 (10 로컬 + 50 클래식 = 60개)
// ─────────────────────────────────────────────
const allTracks = [
  ...localSounds,
  ...mozartTracks,
  ...bachTracks,
  ...chopinTracks,
  ...debussyTracks,
  ...brahmsTracks,
  ...classicEtcTracks,
];

// ─────────────────────────────────────────────
// Firestore 업서트
// ─────────────────────────────────────────────
async function seed() {
  const col = db.collection("sounds");
  const batch = db.batch();

  for (const track of allTracks) {
    const { id, ...data } = track;
    const ref = col.doc(id);
    batch.set(ref, data, { merge: true });
  }

  await batch.commit();
  console.log(`✅ Seeded ${allTracks.length} tracks to Firestore.`);
  process.exit(0);
}

seed().catch((err) => {
  console.error("❌ Seed failed:", err);
  process.exit(1);
});
