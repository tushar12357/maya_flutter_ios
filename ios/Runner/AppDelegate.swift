import UIKit
import Flutter
import FirebaseCore
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FirebaseApp.configure() // Initialize Firebase
    GeneratedPluginRegistrant.register(with: self) // ✅ Register Flutter plugins
    #if DEBUG
    let providerFactory = AppCheckDebugProviderFactory()
    AppCheck.setAppCheckProviderFactory(providerFactory)
    let token = AppCheckDebugProviderFactory.debugToken()
print("🔥🔥🔥 APP CHECK DEBUG TOKEN 🔥🔥🔥")
print("👉 \(token)")
    #endif
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
