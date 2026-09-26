import Flutter
import UIKit

/// Shares an image to the Instagram Stories composer via the pasteboard,
/// as documented by Meta ("Sharing to Stories").
public class InstagramStorySharePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "instagram_story_share", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(InstagramStorySharePlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "shareBackgroundImage" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard
      let args = call.arguments as? [String: Any],
      let path = args["imagePath"] as? String,
      let appId = args["appId"] as? String,
      let data = FileManager.default.contents(atPath: path),
      let url = URL(string: "instagram-stories://share?source_application=\(appId)")
    else {
      result(false)
      return
    }

    let items: [[String: Any]] = [["com.instagram.sharedSticker.backgroundImage": data]]
    let options: [UIPasteboard.OptionsKey: Any] = [
      .expirationDate: Date().addingTimeInterval(60 * 5)
    ]
    UIPasteboard.general.setItems(items, options: options)

    // open(_:) works without LSApplicationQueriesSchemes; success is false
    // when Instagram is not installed.
    UIApplication.shared.open(url, options: [:]) { success in
      result(success)
    }
  }
}
