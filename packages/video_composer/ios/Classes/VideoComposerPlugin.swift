import AVFoundation
import CoreImage
import Flutter
import UIKit

/// Video + music + animated overlay composition with AVFoundation.
public class VideoComposerPlugin: NSObject, FlutterPlugin {
  private var export: AVAssetExportSession?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "video_composer", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(VideoComposerPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any] else {
      result(FlutterError(code: "failed", message: "No arguments", details: nil))
      return
    }
    switch call.method {
    case "probe":
      probe(args, result)
    case "compose":
      compose(args, result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private static func displaySize(_ track: AVAssetTrack) -> CGSize {
    let size = track.naturalSize.applying(track.preferredTransform)
    return CGSize(width: abs(size.width), height: abs(size.height))
  }

  private func probe(_ args: [String: Any], _ result: @escaping FlutterResult) {
    guard let path = args["video"] as? String else {
      result(FlutterError(code: "failed", message: "No video", details: nil))
      return
    }
    let asset = AVURLAsset(url: URL(fileURLWithPath: path))
    guard let track = asset.tracks(withMediaType: .video).first else {
      result(FlutterError(code: "failed", message: "No video track", details: nil))
      return
    }
    let size = Self.displaySize(track)
    result([
      "width": Int(size.width.rounded()),
      "height": Int(size.height.rounded()),
      "durationMs": Int(CMTimeGetSeconds(asset.duration) * 1000),
    ])
  }

  private func compose(_ args: [String: Any], _ result: @escaping FlutterResult) {
    func fail(_ message: String) {
      DispatchQueue.main.async {
        result(FlutterError(code: "failed", message: message, details: nil))
      }
    }
    guard
      let videoPath = args["video"] as? String,
      let durationMs = args["durationMs"] as? Int,
      let overlayDir = args["overlayDir"] as? String,
      let fps = args["overlayFps"] as? Int,
      let framesData = (args["overlayFrames"] as? FlutterStandardTypedData)?.data,
      let width = args["width"] as? Int,
      let height = args["height"] as? Int,
      let output = args["output"] as? String
    else {
      fail("Bad arguments")
      return
    }
    let audioPath = args["audio"] as? String
    let audioStartMs = args["audioStartMs"] as? Int ?? 0
    let frames: [Int32] = framesData.withUnsafeBytes { Array($0.bindMemory(to: Int32.self)) }

    let source = AVURLAsset(url: URL(fileURLWithPath: videoPath))
    guard let sourceVideo = source.tracks(withMediaType: .video).first else {
      fail("No video track")
      return
    }

    // Timeline: the video without its own sound, plus the music.
    let composition = AVMutableComposition()
    let duration = CMTimeMinimum(
      CMTime(value: CMTimeValue(durationMs), timescale: 1000), source.duration)
    let range = CMTimeRange(start: .zero, duration: duration)
    guard
      let videoTrack = composition.addMutableTrack(
        withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
    else {
      fail("Cannot create the video track")
      return
    }
    do {
      try videoTrack.insertTimeRange(range, of: sourceVideo, at: .zero)
    } catch {
      fail(error.localizedDescription)
      return
    }
    videoTrack.preferredTransform = sourceVideo.preferredTransform

    if let audioPath = audioPath {
      let music = AVURLAsset(url: URL(fileURLWithPath: audioPath))
      if let musicTrack = music.tracks(withMediaType: .audio).first,
        let audioTrack = composition.addMutableTrack(
          withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
      {
        let start = CMTime(value: CMTimeValue(audioStartMs), timescale: 1000)
        let available = CMTimeSubtract(music.duration, start)
        let length = CMTimeMinimum(available, duration)
        if CMTimeCompare(length, .zero) > 0 {
          try? audioTrack.insertTimeRange(
            CMTimeRange(start: start, duration: length), of: musicTrack, at: .zero)
        }
      }
    }

    // Frames: the video (upright, scaled to the output) under the overlay.
    let renderSize = CGSize(width: width, height: height)
    let display = Self.displaySize(sourceVideo)
    let t = sourceVideo.preferredTransform
    // Core Image is y-up: the same rotation runs the other way.
    let ciRotation = CGAffineTransform(a: t.a, b: -t.b, c: -t.c, d: t.d, tx: 0, ty: 0)
    let overlays = OverlayCache(dir: overlayDir, fps: fps, frames: frames)

    let videoComposition = AVMutableVideoComposition(
      asset: composition,
      applyingCIFiltersWithHandler: { request in
        var image = request.sourceImage
        // Some systems hand over the frame unrotated: rotate it ourselves.
        let e = image.extent
        if abs(e.width - display.width) > 1, abs(e.width - display.height) <= 1 {
          image = image.transformed(by: ciRotation)
        }
        image = image.transformed(
          by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        image = image.transformed(
          by: CGAffineTransform(
            scaleX: renderSize.width / image.extent.width,
            y: renderSize.height / image.extent.height))
        let ms = CMTimeGetSeconds(request.compositionTime) * 1000
        if let overlay = overlays.image(atMs: ms) {
          let o = overlay.transformed(
            by: CGAffineTransform(
              scaleX: renderSize.width / overlay.extent.width,
              y: renderSize.height / overlay.extent.height))
          image = o.composited(over: image)
        }
        request.finish(
          with: image.cropped(to: CGRect(origin: .zero, size: renderSize)), context: nil)
      })
    videoComposition.renderSize = renderSize

    guard
      let session = AVAssetExportSession(
        asset: composition, presetName: AVAssetExportPresetHighestQuality)
    else {
      fail("Cannot export")
      return
    }
    let url = URL(fileURLWithPath: output)
    try? FileManager.default.removeItem(at: url)
    session.outputURL = url
    session.outputFileType = .mp4
    session.shouldOptimizeForNetworkUse = true
    session.videoComposition = videoComposition
    export = session
    session.exportAsynchronously { [weak self] in
      DispatchQueue.main.async {
        self?.export = nil
        if session.status == .completed {
          result(nil)
        } else {
          result(
            FlutterError(
              code: "failed",
              message: session.error?.localizedDescription ?? "Export failed",
              details: nil))
        }
      }
    }
  }
}

/// Loads overlay PNGs on demand, keeping the last one (consecutive frames
/// usually share it).
private final class OverlayCache {
  init(dir: String, fps: Int, frames: [Int32]) {
    self.dir = dir
    self.fps = max(1, fps)
    self.frames = frames
  }

  private let dir: String
  private let fps: Int
  private let frames: [Int32]
  private let lock = NSLock()
  private var lastIndex: Int32 = -1
  private var lastImage: CIImage?

  func image(atMs ms: Double) -> CIImage? {
    if frames.isEmpty { return nil }
    let frame = min(frames.count - 1, max(0, Int(ms * Double(fps) / 1000)))
    let index = frames[frame]
    if index < 0 { return nil }
    lock.lock()
    defer { lock.unlock() }
    if index != lastIndex {
      lastImage = CIImage(contentsOf: URL(fileURLWithPath: "\(dir)/f\(index).png"))
      lastIndex = index
    }
    return lastImage
  }
}
