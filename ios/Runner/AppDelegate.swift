import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Stores the result of iOS APNs registration — read by Flutter via MethodChannel
  static var apnsStatus: String = "pending"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Expose APNs diagnostic status to Flutter
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "apns_debug",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { _, result in
        result(AppDelegate.apnsStatus)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
    AppDelegate.apnsStatus = "registered:\(token)"
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    AppDelegate.apnsStatus = "failed:\(error.localizedDescription) | \(error)"
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
}
