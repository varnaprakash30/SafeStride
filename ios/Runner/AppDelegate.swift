import Flutter
import UIKit
import GoogleMaps // Make sure this is imported

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Provide your Google Maps API Key here
    GMSServices.provideAPIKey("AIzaSyCoyKIaN3gLOBxsFmBeStrpgHDLv9Jk9OQ")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}