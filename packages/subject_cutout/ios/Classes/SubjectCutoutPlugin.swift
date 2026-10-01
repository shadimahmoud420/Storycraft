import CoreImage
import Flutter
import UIKit
import Vision

/// Background removal and face landmarks with Apple Vision, fully on device.
public class SubjectCutoutPlugin: NSObject, FlutterPlugin {
  private let queue = DispatchQueue(label: "subject_cutout", qos: .userInitiated)
  private let context = CIContext()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "subject_cutout", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(SubjectCutoutPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "removeBackground" || call.method == "detectFaces" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard
      let args = call.arguments as? [String: Any],
      let data = (args["image"] as? FlutterStandardTypedData)?.data
    else {
      result(FlutterError(code: "failed", message: "No image", details: nil))
      return
    }
    let faces = call.method == "detectFaces"
    queue.async {
      let outcome: Any
      do {
        outcome = faces
          ? try self.detectFaces(data)
          : FlutterStandardTypedData(bytes: try self.cutout(data))
      } catch let failure as CutoutFailure {
        outcome = FlutterError(code: failure.rawValue, message: nil, details: nil)
      } catch {
        outcome = FlutterError(
          code: "failed", message: error.localizedDescription, details: nil)
      }
      DispatchQueue.main.async { result(outcome) }
    }
  }

  /// Face landmarks for the beauty tools, in pixels of the upright image
  /// (origin top left). Each face is a map of region name to a flat
  /// [x0, y0, x1, y1, ...] list.
  private func detectFaces(_ data: Data) throws -> [[String: [Double]]] {
    guard let image = UIImage(data: data), let upright = Self.upright(image),
      let cgImage = upright.cgImage
    else {
      throw CutoutFailure.failed
    }
    let request = VNDetectFaceLandmarksRequest()
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    try handler.perform([request])
    let size = CGSize(width: cgImage.width, height: cgImage.height)

    func flat(_ region: VNFaceLandmarkRegion2D?) -> [Double]? {
      guard let region = region, region.pointCount > 0 else { return nil }
      var out: [Double] = []
      for p in region.pointsInImage(imageSize: size) {
        out.append(Double(p.x))
        out.append(Double(size.height - p.y))  // Vision's origin is bottom left.
      }
      return out
    }

    var faces: [[String: [Double]]] = []
    for face in request.results ?? [] {
      guard let lm = face.landmarks else { continue }
      let box = face.boundingBox
      var map: [String: [Double]] = [
        "bounds": [
          Double(box.minX * size.width), Double((1 - box.maxY) * size.height),
          Double(box.width * size.width), Double(box.height * size.height),
        ]
      ]
      let regions: [(String, VNFaceLandmarkRegion2D?)] = [
        ("contour", lm.faceContour), ("leftEye", lm.leftEye),
        ("rightEye", lm.rightEye), ("leftBrow", lm.leftEyebrow),
        ("rightBrow", lm.rightEyebrow), ("outerLips", lm.outerLips),
        ("innerLips", lm.innerLips), ("nose", lm.nose),
        ("noseCrest", lm.noseCrest),
      ]
      for (name, region) in regions {
        if let points = flat(region) { map[name] = points }
      }
      faces.append(map)
    }
    return faces
  }

  private func cutout(_ data: Data) throws -> Data {
    guard let image = UIImage(data: data), let upright = Self.upright(image),
      let cgImage = upright.cgImage
    else {
      throw CutoutFailure.failed
    }
    let input = CIImage(cgImage: cgImage)
    let output: CIImage

    if #available(iOS 17.0, *) {
      // Any salient subject: people, pets, objects.
      let request = VNGenerateForegroundInstanceMaskRequest()
      let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
      try handler.perform([request])
      guard let observation = request.results?.first,
        !observation.allInstances.isEmpty
      else { throw CutoutFailure.noSubject }
      let buffer = try observation.generateMaskedImage(
        ofInstances: observation.allInstances, from: handler,
        croppedToInstancesExtent: false)
      output = CIImage(cvPixelBuffer: buffer)
    } else if #available(iOS 15.0, *) {
      // Older systems: people only.
      let request = VNGeneratePersonSegmentationRequest()
      request.qualityLevel = .accurate
      request.outputPixelFormat = kCVPixelFormatType_OneComponent8
      let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
      try handler.perform([request])
      guard let maskBuffer = request.results?.first?.pixelBuffer else {
        throw CutoutFailure.noSubject
      }
      var mask = CIImage(cvPixelBuffer: maskBuffer)
      mask = mask.transformed(by: CGAffineTransform(
        scaleX: input.extent.width / mask.extent.width,
        y: input.extent.height / mask.extent.height))
      guard let blend = CIFilter(name: "CIBlendWithMask") else {
        throw CutoutFailure.unsupported
      }
      blend.setValue(input, forKey: kCIInputImageKey)
      blend.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
      blend.setValue(mask, forKey: kCIInputMaskImageKey)
      guard let blended = blend.outputImage else { throw CutoutFailure.noSubject }
      output = blended.cropped(to: input.extent)
    } else {
      throw CutoutFailure.unsupported
    }

    guard
      let cg = context.createCGImage(
        output, from: output.extent, format: .RGBA8,
        colorSpace: CGColorSpace(name: CGColorSpace.sRGB)),
      let png = UIImage(cgImage: cg).pngData()
    else {
      throw CutoutFailure.failed
    }
    return png
  }

  /// Bakes the EXIF orientation into the pixels so Vision and the result
  /// agree with what the user sees.
  private static func upright(_ image: UIImage) -> UIImage? {
    if image.imageOrientation == .up { return image }
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
      image.draw(in: CGRect(origin: .zero, size: image.size))
    }
  }
}

/// Error codes understood by the Dart side.
enum CutoutFailure: String, Error {
  case unsupported
  case noSubject = "no_subject"
  case failed
}
