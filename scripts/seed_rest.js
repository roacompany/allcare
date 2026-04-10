#!/usr/bin/env node
/**
 * seed_rest.js — Firestore REST API로 60곡 시드
 * Firebase CLI 토큰 사용 (gcloud ADC 불필요)
 */
const fs = require("fs");
const path = require("path");

// Firebase CLI 토큰 읽기
const configPath = path.join(
  process.env.HOME,
  ".config/configstore/firebase-tools.json"
);
const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
const accessToken = config.tokens?.access_token;
if (!accessToken) {
  console.error("❌ Firebase access token not found. Run: firebase login");
  process.exit(1);
}

const PROJECT_ID = "lotto-app-47230";
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// 모든 트랙 데이터
const allTracks = [
  // 로컬 10개
  { id:"white_noise", name:"화이트 노이즈", artist:"BabyCare", category:"백색소음", duration:0, storageURL:"", iconName:"waveform", isFree:true, sortOrder:0, isLocal:true, localFileName:"white_noise.wav" },
  { id:"pink_noise", name:"핑크 노이즈", artist:"BabyCare", category:"백색소음", duration:0, storageURL:"", iconName:"waveform.badge.minus", isFree:true, sortOrder:1, isLocal:true, localFileName:"pink_noise.wav" },
  { id:"rain", name:"빗소리", artist:"BabyCare", category:"자연", duration:0, storageURL:"", iconName:"cloud.rain.fill", isFree:true, sortOrder:10, isLocal:true, localFileName:"rain.wav" },
  { id:"ocean", name:"파도소리", artist:"BabyCare", category:"자연", duration:0, storageURL:"", iconName:"water.waves", isFree:true, sortOrder:11, isLocal:true, localFileName:"ocean.wav" },
  { id:"birds", name:"새소리", artist:"BabyCare", category:"자연", duration:0, storageURL:"", iconName:"bird.fill", isFree:true, sortOrder:12, isLocal:true, localFileName:"birds.wav" },
  { id:"heartbeat", name:"심장박동", artist:"BabyCare", category:"생활", duration:0, storageURL:"", iconName:"heart.fill", isFree:true, sortOrder:20, isLocal:true, localFileName:"heartbeat.wav" },
  { id:"fan", name:"선풍기", artist:"BabyCare", category:"생활", duration:0, storageURL:"", iconName:"fan.fill", isFree:true, sortOrder:21, isLocal:true, localFileName:"fan.wav" },
  { id:"shushing", name:"쉬 소리", artist:"BabyCare", category:"생활", duration:0, storageURL:"", iconName:"mouth.fill", isFree:true, sortOrder:22, isLocal:true, localFileName:"shushing.wav" },
  { id:"lullaby", name:"자장가", artist:"BabyCare", category:"자장가", duration:0, storageURL:"", iconName:"moon.stars.fill", isFree:true, sortOrder:30, isLocal:true, localFileName:"lullaby.wav" },
  { id:"music_box", name:"오르골", artist:"BabyCare", category:"자장가", duration:0, storageURL:"", iconName:"music.note.list", isFree:true, sortOrder:31, isLocal:true, localFileName:"music_box.wav" },
  // 모차르트 10곡
  ...["자장가 K.350|180|mozart_lullaby.m4a|100","피아노 소나타 11번 3악장|210|mozart_piano_sonata11_3.m4a|101","아이네 클라이네 나흐트무지크|360|mozart_eine_kleine.m4a|102","피아노 협주곡 21번 2악장|420|mozart_piano_conc21_2.m4a|103","플루트와 하프 협주곡 2악장|390|mozart_flute_harp_2.m4a|104","교향곡 40번 1악장|480|mozart_symphony40_1.m4a|105","터키 행진곡|210|mozart_turkish_march.m4a|106","피아노 소나타 16번|300|mozart_piano_sonata16.m4a|107","클라리넷 협주곡 2악장|450|mozart_clarinet_conc_2.m4a|108","디베르티멘토 K.136|270|mozart_divertimento136.m4a|109"]
    .map(s => { const [name,dur,fn,so] = s.split("|"); return { id:fn.replace(".m4a",""), name, artist:"모차르트", category:"클래식-모차르트", duration:+dur, storageURL:`sounds/classical/${fn}`, iconName:"music.note", isFree:true, sortOrder:+so, isLocal:false, localFileName:null }; }),
  // 바흐 8곡
  ...["G선상의 아리아|420|bach_air_on_g_string.m4a|200","골드베르크 변주곡 아리아|300|bach_goldberg_aria.m4a|201","무반주 첼로 모음곡 1번 프렐류드|150|bach_cello_suite1_prelude.m4a|202","예수 인간 소망의 기쁨|210|bach_jesu_joy.m4a|203","브란덴부르크 협주곡 3번|540|bach_brandenburg3.m4a|204","평균율 클라비어 1번 프렐류드|150|bach_wt_prelude1.m4a|205","미뉴에트 G장조|120|bach_minuet_g.m4a|206","양떼는 평화로이 풀을 뜯고|270|bach_sheep_grazing.m4a|207"]
    .map(s => { const [name,dur,fn,so] = s.split("|"); return { id:fn.replace(".m4a",""), name, artist:"바흐", category:"클래식-바흐", duration:+dur, storageURL:`sounds/classical/${fn}`, iconName:"music.quarternote.3", isFree:true, sortOrder:+so, isLocal:false, localFileName:null }; }),
  // 쇼팽 8곡
  ...["녹턴 Op.9 No.2|270|chopin_nocturne9_2.m4a|300","자장가 Op.57|240|chopin_berceuse57.m4a|301","빗방울 전주곡|300|chopin_raindrop.m4a|302","이별의 곡|300|chopin_etude10_3.m4a|303","발라드 1번|540|chopin_ballade1.m4a|304","봄 왈츠|210|chopin_spring_waltz.m4a|305","녹턴 Op.48 No.1|360|chopin_nocturne48_1.m4a|306","전주곡 Op.28 No.15|330|chopin_prelude28_15.m4a|307"]
    .map(s => { const [name,dur,fn,so] = s.split("|"); return { id:fn.replace(".m4a",""), name, artist:"쇼팽", category:"클래식-쇼팽", duration:+dur, storageURL:`sounds/classical/${fn}`, iconName:"pianokeys.inverse", isFree:true, sortOrder:+so, isLocal:false, localFileName:null }; }),
  // 드뷔시 6곡
  ...["달빛|360|debussy_clair_de_lune.m4a|400","아라베스크 1번|240|debussy_arabesque1.m4a|401","아마색 머리 소녀|180|debussy_flaxen_hair.m4a|402","꿈|270|debussy_reverie.m4a|403","목신의 오후에의 전주곡|660|debussy_afternoon_faun.m4a|404","물의 반영|300|debussy_reflections.m4a|405"]
    .map(s => { const [name,dur,fn,so] = s.split("|"); return { id:fn.replace(".m4a",""), name, artist:"드뷔시", category:"클래식-드뷔시", duration:+dur, storageURL:`sounds/classical/${fn}`, iconName:"water.waves", isFree:true, sortOrder:+so, isLocal:false, localFileName:null }; }),
  // 브람스 5곡
  ...["자장가|180|brahms_lullaby.m4a|500","헝가리 무곡 5번|210|brahms_hungarian5.m4a|501","교향곡 3번 3악장|420|brahms_symphony3_3.m4a|502","간주곡 Op.118 No.2|300|brahms_intermezzo118.m4a|503","왈츠 Op.39 No.15|150|brahms_waltz39_15.m4a|504"]
    .map(s => { const [name,dur,fn,so] = s.split("|"); return { id:fn.replace(".m4a",""), name, artist:"브람스", category:"클래식-기타", duration:+dur, storageURL:`sounds/classical/${fn}`, iconName:"music.note.list", isFree:true, sortOrder:+so, isLocal:false, localFileName:null }; }),
  // 기타 클래식 13곡
  { id:"saintsaens_swan", name:"백조", artist:"생상스", category:"클래식-기타", duration:240, storageURL:"sounds/classical/saintsaens_swan.m4a", iconName:"music.note.list", isFree:true, sortOrder:600, isLocal:false, localFileName:null },
  { id:"tchaikovsky_swan_lake", name:"백조의 호수", artist:"차이콥스키", category:"클래식-기타", duration:300, storageURL:"sounds/classical/tchaikovsky_swan_lake.m4a", iconName:"music.note.list", isFree:true, sortOrder:601, isLocal:false, localFileName:null },
  { id:"tchaikovsky_waltz_flowers", name:"호두까기인형 꽃의 왈츠", artist:"차이콥스키", category:"클래식-기타", duration:240, storageURL:"sounds/classical/tchaikovsky_waltz_flowers.m4a", iconName:"music.note.list", isFree:true, sortOrder:602, isLocal:false, localFileName:null },
  { id:"vivaldi_spring", name:"사계 봄", artist:"비발디", category:"클래식-기타", duration:780, storageURL:"sounds/classical/vivaldi_spring.m4a", iconName:"music.note.list", isFree:true, sortOrder:603, isLocal:false, localFileName:null },
  { id:"beethoven_moonlight", name:"월광 소나타", artist:"베토벤", category:"클래식-기타", duration:390, storageURL:"sounds/classical/beethoven_moonlight.m4a", iconName:"music.note.list", isFree:true, sortOrder:604, isLocal:false, localFileName:null },
  { id:"beethoven_fur_elise", name:"엘리제를 위하여", artist:"베토벤", category:"클래식-기타", duration:180, storageURL:"sounds/classical/beethoven_fur_elise.m4a", iconName:"music.note.list", isFree:true, sortOrder:605, isLocal:false, localFileName:null },
  { id:"schubert_lullaby", name:"자장가", artist:"슈베르트", category:"클래식-기타", duration:180, storageURL:"sounds/classical/schubert_lullaby.m4a", iconName:"music.note.list", isFree:true, sortOrder:606, isLocal:false, localFileName:null },
  { id:"schumann_traumerei", name:"트로이메라이", artist:"슈만", category:"클래식-기타", duration:210, storageURL:"sounds/classical/schumann_traumerei.m4a", iconName:"music.note.list", isFree:true, sortOrder:607, isLocal:false, localFileName:null },
  { id:"grieg_morning_mood", name:"아침", artist:"그리그", category:"클래식-기타", duration:240, storageURL:"sounds/classical/grieg_morning_mood.m4a", iconName:"music.note.list", isFree:true, sortOrder:608, isLocal:false, localFileName:null },
  { id:"satie_gymnopedie1", name:"짐노페디 1번", artist:"사티", category:"클래식-기타", duration:210, storageURL:"sounds/classical/satie_gymnopedie1.m4a", iconName:"music.note.list", isFree:true, sortOrder:609, isLocal:false, localFileName:null },
  { id:"pachelbel_canon", name:"캐논", artist:"파헬벨", category:"클래식-기타", duration:300, storageURL:"sounds/classical/pachelbel_canon.m4a", iconName:"music.note.list", isFree:true, sortOrder:610, isLocal:false, localFileName:null },
  { id:"elgar_salut_damour", name:"사랑의 인사", artist:"엘가", category:"클래식-기타", duration:210, storageURL:"sounds/classical/elgar_salut_damour.m4a", iconName:"music.note.list", isFree:true, sortOrder:611, isLocal:false, localFileName:null },
  { id:"massenet_meditation", name:"타이스의 명상곡", artist:"마스네", category:"클래식-기타", duration:360, storageURL:"sounds/classical/massenet_meditation.m4a", iconName:"music.note.list", isFree:true, sortOrder:612, isLocal:false, localFileName:null },
];

// Firestore REST API 값 변환
function toFirestoreValue(val) {
  if (val === null) return { nullValue: null };
  if (typeof val === "boolean") return { booleanValue: val };
  if (typeof val === "number") return { integerValue: String(val) };
  if (typeof val === "string") return { stringValue: val };
  return { stringValue: String(val) };
}

function toFirestoreDoc(obj) {
  const fields = {};
  for (const [k, v] of Object.entries(obj)) {
    fields[k] = toFirestoreValue(v);
  }
  return { fields };
}

async function seed() {
  let success = 0;
  let fail = 0;

  for (const track of allTracks) {
    const { id, ...data } = track;
    const doc = toFirestoreDoc(data);
    const url = `${BASE_URL}/sounds/${id}`;

    try {
      const res = await fetch(url + "?updateMask.fieldPaths=" + Object.keys(data).join("&updateMask.fieldPaths="), {
        method: "PATCH",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(doc),
      });

      if (res.ok) {
        success++;
      } else {
        const err = await res.text();
        console.error(`❌ ${id}: ${res.status} ${err.substring(0, 100)}`);
        fail++;
      }
    } catch (e) {
      console.error(`❌ ${id}: ${e.message}`);
      fail++;
    }
  }

  console.log(`\n✅ Seeded: ${success}/${allTracks.length} tracks (${fail} failed)`);
}

seed();
