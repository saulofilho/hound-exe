// Junta os quadros PNG e o WAV do Movie Maker num MP4 1920x1080 (H.264 + AAC),
// ampliando 5x sem borrar. Uso: swift tools/encode_trailer.swift <pasta> <saida.mp4>
import AVFoundation
import CoreGraphics
import ImageIO

let args = CommandLine.arguments
guard args.count == 3 else { print("uso: encode_trailer.swift <pasta> <saida.mp4>"); exit(1) }
let dir = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: args[2])
let fps: Int32 = 60
let width = 1920, height = 1080

let all = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
let frames = all.filter { $0.pathExtension == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
guard !frames.isEmpty, let wav = all.first(where: { $0.pathExtension == "wav" }) else { print("sem quadros ou WAV"); exit(1) }
try? FileManager.default.removeItem(at: out)

let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
  AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
  AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 12_000_000, AVVideoExpectedSourceFrameRateKey: fps],
])
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
  kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
  kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
])
let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
  AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 192_000,
])
writer.add(video)
writer.add(audio)

let asset = AVURLAsset(url: wav)
let reader = try AVAssetReader(asset: asset)
let track = try await asset.loadTracks(withMediaType: .audio)[0]
let pcm = AVAssetReaderTrackOutput(track: track, outputSettings: [
  AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 48_000, AVNumberOfChannelsKey: 2,
  AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false,
])
reader.add(pcm)
guard reader.startReading(), writer.startWriting() else { print("falha ao iniciar"); exit(1) }
writer.startSession(atSourceTime: .zero)
let length = CMTime(value: CMTimeValue(frames.count), timescale: fps)

let done = DispatchGroup()
done.enter()
var next = 0
video.requestMediaDataWhenReady(on: DispatchQueue(label: "video")) {
  while video.isReadyForMoreMediaData {
    guard next < frames.count else { video.markAsFinished(); done.leave(); return }
    autoreleasepool {
      var buffer: CVPixelBuffer?
      CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
      let source = CGImageSourceCreateWithURL(frames[next] as CFURL, nil)!
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)!
      CVPixelBufferLockBaseAddress(buffer!, [])
      let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer!), width: width, height: height, bitsPerComponent: 8,
                              bytesPerRow: CVPixelBufferGetBytesPerRow(buffer!), space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
      context.interpolationQuality = .none
      context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      CVPixelBufferUnlockBaseAddress(buffer!, [])
      _ = adaptor.append(buffer!, withPresentationTime: CMTime(value: CMTimeValue(next), timescale: fps))
    }
    next += 1
  }
}
done.enter()
audio.requestMediaDataWhenReady(on: DispatchQueue(label: "audio")) {
  while audio.isReadyForMoreMediaData {
    guard let sample = pcm.copyNextSampleBuffer(), CMSampleBufferGetPresentationTimeStamp(sample) < length else {
      audio.markAsFinished(); done.leave(); return
    }
    audio.append(sample)
  }
}
await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in done.notify(queue: .global()) { c.resume() } }
writer.endSession(atSourceTime: length)
await writer.finishWriting()
guard writer.status == .completed else { print("falha: \(String(describing: writer.error))"); exit(1) }
print("\(out.lastPathComponent): \(frames.count) quadros, \(String(format: "%.1f", length.seconds)) s")
