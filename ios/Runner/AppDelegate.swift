import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle URL scheme redirects for OAuth
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    
    // Log the incoming URL for debugging
    print("📱 Received URL: \(url.absoluteString)")
    
    // Check if this is a Privy OAuth callback
    if url.scheme == "dreamapp" {
      print("✅ Handling Privy OAuth callback")
      // Let Flutter handle the OAuth callback
      return super.application(app, open: url, options: options)
    }
    
    // Handle other URL schemes if needed
    print("⚠️ Unknown URL scheme: \(url.scheme ?? "none")")
    return super.application(app, open: url, options: options)
  }

  
  // Handle universal links
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }
}
