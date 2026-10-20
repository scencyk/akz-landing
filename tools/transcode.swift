// Re-encodes a video to H.264 (no audio), optionally cropping first.
// Build: swiftc -O tools/transcode.swift -o tools/transcode
// Usage: tools/transcode in.mp4 out.mp4 outW outH kbps [cropX cropY cropW cropH]
import AVFoundation

let a = CommandLine.arguments
let src = AVURLAsset(url: URL(fileURLWithPath: a[1]))
let outURL = URL(fileURLWithPath: a[2]); try? FileManager.default.removeItem(at: outURL)
let w = Int(a[3])!, h = Int(a[4])!, kbps = Int(a[5])!
let track = src.tracks(withMediaType: .video)[0]
let crop = a.count > 9
  ? CGRect(x: Double(a[6])!, y: Double(a[7])!, width: Double(a[8])!, height: Double(a[9])!)
  : CGRect(origin: .zero, size: track.naturalSize)

// Crop by shifting the frame inside a smaller render canvas.
let comp = AVMutableVideoComposition()
comp.renderSize = crop.size
// Work in plain BT.709 so 10-bit sources tagged with unusual transfer functions (e.g. "UseGamma") are not misread.
comp.colorPrimaries = AVVideoColorPrimaries_ITU_R_709_2
comp.colorTransferFunction = AVVideoTransferFunction_ITU_R_709_2
comp.colorYCbCrMatrix = AVVideoYCbCrMatrix_ITU_R_709_2
comp.frameDuration = CMTime(value: 1, timescale: CMTimeScale(track.nominalFrameRate.rounded()))
let ins = AVMutableVideoCompositionInstruction()
ins.timeRange = CMTimeRange(start: .zero, duration: src.duration)
let li = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
li.setTransform(CGAffineTransform(translationX: -crop.minX, y: -crop.minY), at: .zero)
ins.layerInstructions = [li]
comp.instructions = [ins]

let reader = try! AVAssetReader(asset: src)
let ro = AVAssetReaderVideoCompositionOutput(videoTracks: [track], videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
ro.videoComposition = comp
reader.add(ro)

let writer = try! AVAssetWriter(outputURL: outURL, fileType: .mp4)
writer.shouldOptimizeForNetworkUse = true // moov atom first, so the browser can start playing early
let wi = AVAssetWriterInput(mediaType: .video, outputSettings: [
  AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: w, AVVideoHeightKey: h,
  AVVideoScalingModeKey: AVVideoScalingModeResize,
  AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                              AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                              AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2],
  AVVideoCompressionPropertiesKey: [
    AVVideoAverageBitRateKey: kbps * 1000, AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
    AVVideoMaxKeyFrameIntervalKey: 25, AVVideoExpectedSourceFrameRateKey: 25,
  ] as [String: Any],
])
wi.expectsMediaDataInRealTime = false
writer.add(wi)

reader.startReading(); writer.startWriting(); writer.startSession(atSourceTime: .zero)
var n = 0
while true {
  while !wi.isReadyForMoreMediaData { usleep(2000) }
  guard let sb = ro.copyNextSampleBuffer() else { break }
  wi.append(sb); n += 1
}
wi.markAsFinished()
let sem = DispatchSemaphore(value: 0)
writer.finishWriting { sem.signal() }
sem.wait()
print("frames", n, "status", writer.status.rawValue, reader.error as Any, writer.error as Any)
