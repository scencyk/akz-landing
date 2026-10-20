// Prints duration and tracks of a video, saves a JPEG frame. Usage: swift tools/probe.swift in.mp4 out.jpg [seconds]
import AVFoundation
import AppKit
let a = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: a[1]))
let sem = DispatchSemaphore(value: 0)
Task {
  do {
    let d = try await asset.load(.duration); print("duration s:", d.seconds)
    for t in try await asset.load(.tracks) {
      let size = try await t.load(.naturalSize), fr = try await t.load(.nominalFrameRate), br = try await t.load(.estimatedDataRate)
      let fd = try await t.load(.formatDescriptions)
      let codec = fd.first.map { CMFormatDescriptionGetMediaSubType($0) }.map { String(format: "%08x", $0) } ?? "?"
      print(t.mediaType.rawValue, size, "fps", fr, "kbps", Int(br / 1000), "codec", codec)
    }
    let g = AVAssetImageGenerator(asset: asset); g.appliesPreferredTrackTransform = true
    let s = a.count > 3 ? Double(a[3])! : d.seconds / 2
    let (img, _) = try await g.image(at: CMTime(seconds: s, preferredTimescale: 600))
    try NSBitmapImageRep(cgImage: img).representation(using: .jpeg, properties: [.compressionFactor: 0.8])!.write(to: URL(fileURLWithPath: a[2]))
  } catch { print("ERR", error) }
  sem.signal()
}
sem.wait()
