import UIKit
import Flutter
import GoogleSignIn
import Branch

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Branch.io 초기화
    Branch.getInstance().initSession(launchOptions: launchOptions) { (params, error) in
      print("Branch 초기화 완료: \(String(describing: params))")
      if let error = error {
        print("Branch 초기화 오류: \(error)")
      }
    }
    
    // Google Sign-In 설정
    if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
       let plist = NSDictionary(contentsOfFile: path),
       let clientId = plist["CLIENT_ID"] as? String {
      GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  override func application(_ app: UIApplication,
                           open url: URL,
                           options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    // Branch.io URL 처리
    Branch.getInstance().application(app, open: url, options: options)
    
    // Google Sign-In URL 처리
    return GIDSignIn.sharedInstance.handle(url)
  }
  
  override func application(_ application: UIApplication,
                           continue userActivity: NSUserActivity,
                           restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
    // Universal Links 처리 (Branch.io)
    return Branch.getInstance().continue(userActivity)
  }
}
