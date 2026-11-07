#!/usr/bin/env swift
// PNG 여러 장을 한 장에 가로로 나란히 붙인다 — 장면마다 파일명(t=…s)을 위에 적는다(AppKit, ffmpeg 불필요).
//
//   swift scripts/xcresult_montage.swift <out.png> <frame_017.0.png> <frame_018.5.png> …
//
// 짝: scripts/xcresult_frames.swift 가 뽑은 장면을 한눈에 비교할 때 쓴다(탭 전후로 화면이 바뀌었나).

import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    print("사용법: swift scripts/xcresult_montage.swift <out.png> <frame.png>…")
    exit(1)
}
let out = args[1]
let files = Array(args.dropFirst(2))
let images = files.compactMap { NSImage(contentsOfFile: $0) }
let gap: CGFloat = 8
let width = images.map { $0.size.width }.reduce(0, +) + CGFloat(max(images.count - 1, 0)) * gap
let height = images.map { $0.size.height }.max() ?? 0

let canvas = NSImage(size: NSSize(width: width, height: height + 24))
canvas.lockFocus()
NSColor.white.setFill()
NSRect(x: 0, y: 0, width: width, height: height + 24).fill()
var x: CGFloat = 0
for (index, image) in images.enumerated() {
    image.draw(in: NSRect(x: x, y: 0, width: image.size.width, height: image.size.height))
    let label = (files[index] as NSString).lastPathComponent
        .replacingOccurrences(of: "frame_", with: "t=")
        .replacingOccurrences(of: ".png", with: "s")
    (label as NSString).draw(at: NSPoint(x: x + 4, y: height + 4), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 14)])
    x += image.size.width + gap
}
canvas.unlockFocus()

guard let tiff = canvas.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    print("PNG 만들기 실패")
    exit(1)
}
try png.write(to: URL(fileURLWithPath: out))
print(out)
