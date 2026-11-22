// Junta os quadros PNG e o WAV do Movie Maker num MP4 1920x1080 (H.264 + AAC),
// ampliando 5x sem borrar. Uso: swift tools/encode_trailer.swift <pasta> <saida.mp4>
// Com um terceiro e um quarto argumento (logo e ícone em PNG) sai vertical,
// 1080x1920: o quadro inteiro no meio, o nome em cima e o ícone embaixo.
// CBR_MBPS=20 força taxa constante (a Steam pede 5.000 kbps ou mais, e com taxa
// média pixel art sai perto de 1.400). Sem ele, o arquivo fica leve para a web.
import AVFoundation
import CoreGraphics
import ImageIO
import VideoToolbox

let args = CommandLine.arguments
guard args.count == 3 || args.count == 5 else { print("uso: encode_trailer.swift <pasta> <saida.mp4> [logo.png icone.png, para vertical]"); exit(1) }
let dir = URL(fileURLWithPath: args[1])
let out = URL(fileURLWithPath: args[2])
let fps: Int32 = 60
let vertical = args.count == 5
let width = vertical ? 1080 : 1920, height = vertical ? 1920 : 1080
func loadImage(_ url: URL) -> CGImage? {
  guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
  return CGImageSourceCreateImageAtIndex(source, 0, nil)
}
let logo = vertical ? loadImage(URL(fileURLWithPath: args[3])) : nil
let icon = vertical ? loadImage(URL(fileURLWithPath: args[4])) : nil
if vertical && (logo == nil || icon == nil) { print("logo ou icone ilegivel"); exit(1) }
// 384 não cabe inteiro em 1080: amplia 5x sem borrar e só então reduz, para nada ser cortado
let enlarge = CGContext(data: nil, width: 1920, height: 1080, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
enlarge.interpolationQuality = .none

let all = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
let frames = all.filter { $0.pathExtension == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
guard !frames.isEmpty, let wav = all.first(where: { $0.pathExtension == "wav" }) else { print("sem quadros ou WAV"); exit(1) }
try? FileManager.default.removeItem(at: out)

let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
var compression: [String: Any] = [AVVideoAverageBitRateKey: 12_000_000, AVVideoExpectedSourceFrameRateKey: fps]
if let wanted = ProcessInfo.processInfo.environment["CBR_MBPS"] {
  guard let mbps = Int(wanted), (1...50).contains(mbps) else { print("CBR_MBPS precisa ser de 1 a 50"); exit(1) }
  compression.removeValue(forKey: AVVideoAverageBitRateKey)
  compression[kVTCompressionPropertyKey_ConstantBitRate as String] = mbps * 1_000_000
}
let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
  AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
  AVVideoCompressionPropertiesKey: compression,
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
      if vertical, let logo, let icon {
        context.setFillColor(red: 0, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        enlarge.draw(image, in: CGRect(x: 0, y: 0, width: 1920, height: 1080))
        context.interpolationQuality = .high
        context.draw(enlarge.makeImage()!, in: CGRect(x: 0, y: 656, width: 1080, height: 608))
        context.interpolationQuality = .none
        context.draw(icon, in: CGRect(x: 356, y: 180, width: 368, height: 368))
        let logoWidth = 928
        let logoHeight = logoWidth * logo.height / logo.width
        context.draw(logo, in: CGRect(x: (width - logoWidth) / 2, y: 1400, width: logoWidth, height: logoHeight))
        context.setFillColor(red: 47.0 / 255, green: 181.0 / 255, blue: 168.0 / 255, alpha: 1)
        context.fill(CGRect(x: 76, y: 1330, width: 928, height: 8))
      } else {
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
      }
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
