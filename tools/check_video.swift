// Confere um vídeo para a Steam: taxa, tamanho, quadros e áudio.
// Uso: swift tools/check_video.swift <video.mp4> <kbps mínimo>
import AVFoundation

let args = CommandLine.arguments
guard args.count == 3, let floor = Float(args[2]) else { print("uso: check_video.swift <video> <kbps mínimo>"); exit(2) }
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
guard let video = try await asset.loadTracks(withMediaType: .video).first,
      let audio = try await asset.loadTracks(withMediaType: .audio).first else { print("TRAILER FALHOU: falta vídeo ou áudio"); exit(1) }
let kbps = try await video.load(.estimatedDataRate) / 1000
let size = try await video.load(.naturalSize)
let fps = try await video.load(.nominalFrameRate)
let seconds = try await asset.load(.duration).seconds
let format = try await audio.load(.formatDescriptions)[0]
let rate = CMAudioFormatDescriptionGetStreamBasicDescription(format)?.pointee.mSampleRate ?? 0
var bad: [String] = []
if kbps < floor { bad.append("\(Int(kbps)) kbps, abaixo de \(Int(floor))") }
if Int(size.width) != 1920 || Int(size.height) != 1080 { bad.append("não é 1920x1080") }
if fps < 29 || fps > 61 { bad.append("\(fps) quadros por segundo") }
if rate != 44_100 && rate != 48_000 { bad.append("áudio em \(rate) Hz") }
print("\(Int(kbps)) kbps, \(Int(size.width))x\(Int(size.height)), \(Int(fps.rounded())) fps, áudio \(Int(rate)) Hz, \(Int(seconds)) s")
if !bad.isEmpty { print("TRAILER FALHOU: " + bad.joined(separator: ", ")); exit(1) }
print("TRAILER OK")
