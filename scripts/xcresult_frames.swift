#!/usr/bin/env swift
// xcresult 화면 녹화(mp4)에서 원하는 시각의 장면을 PNG 로 뽑는다 — ffmpeg 없이(AVFoundation).
//
//   1) 녹화 꺼내기:
//      xcrun xcresulttool export attachments --path <xcresult> --output-path <dir> \
//        --test-id "PregnancyFlowTests/test_addBabyView_cancel_returnsToOnboarding()"
//      → <dir>/manifest.json 에서 "Screen Recording …mp4" 의 exportedFileName 을 찾는다.
//   2) 장면 뽑기(초 단위, 여러 개):
//      swift scripts/xcresult_frames.swift <video.mp4> <out-dir> 17 18.5 19.5 20.5 22.5
//   3) 한 장으로 나란히 보기:
//      swift scripts/xcresult_montage.swift <out.png> <frame.png>…
//
// 🔑 탭 뒤 화면이 「느리게」 바뀐 것인지 「아예 안」 바뀐 것인지는 로그로 못 가른다 — 장면으로 본다
//    (.claude/rules/build-gotchas.md 「XCUITest 콜드 런치 첫 탭」). 테스트 로그의 `t = …s` 가 녹화 시각과 거의 같다.
// ⚠️ deprecated API 컴파일 경고는 무시해도 된다 — 한 번 돌리는 진단용 스크립트다.

import AVFoundation
import AppKit

let args = CommandLine.arguments
guard args.count >= 4 else {
    print("사용법: swift scripts/xcresult_frames.swift <video.mp4> <out-dir> <초> [<초>…]")
    exit(1)
}
let url = URL(fileURLWithPath: args[1])
let out = args[2]
let asset = AVURLAsset(url: url)
let duration = CMTimeGetSeconds(asset.duration)
print("길이", duration)

let generator = AVAssetImageGenerator(asset: asset)
generator.appliesPreferredTrackTransform = true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
generator.maximumSize = CGSize(width: 300, height: 650)

for t in args.dropFirst(3).compactMap(Double.init) where t <= duration {
    guard let image = try? generator.copyCGImage(at: CMTime(seconds: t, preferredTimescale: 600), actualTime: nil) else {
        print("못 뽑음:", t)
        continue
    }
    let path = "\(out)/frame_\(String(format: "%05.1f", t)).png"
    let rep = NSBitmapImageRep(cgImage: image)
    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    print(path)
}
