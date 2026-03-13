import Flutter
import UIKit
import GoogleMaps // 구글 맵 라이브러리 추가

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // [신규] iOS 구글 맵 API 키 초기화
    GMSServices.provideAPIKey("AIzaSyBcXgANLU-mnTOx0BWZK6mIH-pyaf0Ptgs")
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
