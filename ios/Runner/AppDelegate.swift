import UIKit
import Flutter
import GoogleSignIn
import BranchSDK
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Google Maps SDK 초기화 (Info.plist의 GMSApiKey 사용)
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String, !apiKey.isEmpty {
      GMSServices.provideAPIKey(apiKey)
    } else {
      print("GMSApiKey not found in Info.plist or is empty.")
    }
    
    // Google Sign-In 설정 (Branch 초기화 전에 먼저)
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       let plist = NSDictionary(contentsOfFile: path),
       let clientId = plist["CLIENT_ID"] as? String {
      GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    } else {
      print("GoogleService-Info.plist 파일을 찾을 수 없거나 CLIENT_ID가 없습니다.")
    }
    
    // Branch.io 초기화
    Branch.getInstance().initSession(launchOptions: launchOptions) { (params, error) in
      print("Branch 초기화 완료: \(String(describing: params))")
      if let error = error {
        print("Branch 초기화 오류: \(error)")
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(_ app: UIApplication,
                           open url: URL,
                           options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    print("URL 처리 시도: \(url)")
    
    // Google Sign-In URL 먼저 처리
    if GIDSignIn.sharedInstance.handle(url) {
      print("Google Sign-In URL 처리됨")
      return true
    }
    
    // Google Sign-In에서 처리되지 않은 경우 Branch.io로 전달
    print("Branch.io URL 처리")
    return Branch.getInstance().application(app, open: url, options: options)
  }
  
  override func application(_ application: UIApplication,
                           continue userActivity: NSUserActivity,
                           restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    // Universal Links 처리 (Branch.io)
    return Branch.getInstance().continue(userActivity)
  }
}
