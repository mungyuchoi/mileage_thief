# Branch iOS Universal Links 설정 가이드

확인일: 2026-05-14

이 문서는 마일캐치 Flutter 프로젝트에서 Branch.io 링크가 Android에서는 정상 동작하지만 iPhone에서는 앱이 열리지 않고 웹/fallback으로 이동하는 문제를 기준으로 작성했다.

## 결론

초기 문제의 가장 유력한 원인은 Branch Dashboard의 iOS Universal Links 설정에서 `Apple App Prefix`가 비어 있어 iOS용 AASA 파일이 정상 생성되지 않았던 것이다.

초기 확인 결과:

- `https://milecatch.app.link/.well-known/apple-app-site-association` -> HTTP 404
- `https://milecatch-alternate.app.link/.well-known/apple-app-site-association` -> HTTP 404
- `https://milecatch.app.link/.well-known/assetlinks.json` -> HTTP 200

즉 Android App Links 설정은 Branch 쪽에 정상 반영되어 있지만, iOS Universal Links 설정은 Branch 쪽에서 완성되지 않은 상태로 볼 수 있다. 진단 당시 스크린샷상 iOS 설정의 `Apple App Prefix`가 비어 있는 점이 핵심 의심 지점이었다.

`Apple App Prefix`에 `V9MN8893Z6`를 추가하고 프로젝트 entitlements를 정리한 뒤 재확인한 결과:

- `https://milecatch-alternate.app.link/apple-app-site-association`가 HTTP 200을 반환할 때 AASA 응답에 `V9MN8893Z6.com.mungyu.mileageThief` 포함
- 다만 Branch/CloudFront 응답이 아직 안정적으로 전파되지 않아, 확인 시점에 따라 `milecatch.app.link` 또는 `milecatch-alternate.app.link`가 HTTP 404를 반환할 수 있음

따라서 프로젝트 내부 iOS 설정은 맞춰졌고, 남은 핵심은 Branch AASA 응답이 두 도메인에서 안정적으로 200이 되는지 재확인한 뒤 iOS 빌드를 설치해 기기 캐시를 갱신하는 것이다.

## 현재 프로젝트 값

프로젝트에서 확인한 값은 다음과 같다.

| 항목 | 값 |
| --- | --- |
| iOS Bundle Identifier | `com.mungyu.mileageThief` |
| Apple Team ID / Development Team | `V9MN8893Z6` |
| Branch URI Scheme | `milecatch` |
| Branch link domain | `milecatch.app.link` |
| Branch alternate link domain | `milecatch-alternate.app.link` |
| iOS App Store ID | `6446247689` |
| Android Package Name | `com.mungyu.mileage_thief` |

관련 파일:

- `ios/Runner.xcodeproj/project.pbxproj`
  - `DEVELOPMENT_TEAM = V9MN8893Z6`
  - `PRODUCT_BUNDLE_IDENTIFIER = com.mungyu.mileageThief`
- `ios/Runner/Info.plist`
  - `branch_key`
  - `branch_universal_link_domains`
  - `CFBundleURLSchemes`
- `ios/Runner/Runner.entitlements`
  - Associated Domains
- `android/app/src/main/AndroidManifest.xml`
  - Android App Links, URI scheme, Branch key

## Branch Dashboard 설정

Branch Dashboard의 iOS Redirects에서 다음처럼 맞춘다.

1. `I have an iOS App` 체크
2. `iOS URI Scheme`
   - Dashboard에는 `milecatch://` 형태로 입력
   - iOS `Info.plist`의 실제 scheme 값은 `milecatch`
3. fallback 설정
   - `Apple Store Search` 사용
   - 앱: `마일캐치`
   - App Store ID: `6446247689`
4. `Enable Universal Links` 체크
5. `Bundle Identifiers`
   - `com.mungyu.mileageThief`
6. `Apple App Prefix`
   - 우선 `V9MN8893Z6` 입력
   - 단, Apple Developer Portal의 App ID Prefix가 Team ID와 다르면 Developer Portal에 표시된 App ID Prefix 값을 사용
7. 저장 후 몇 분 정도 반영 시간을 둔다.

Branch 공식 문서에서도 Universal Links 활성화 시 Bundle Identifier와 Apple App Prefix를 입력해야 한다고 안내한다.

참고:

- [Branch Apple Universal Links](https://help.branch.io/developer-hub/docs/ios-universal-links)
- [Branch Flutter SDK Basic Integration](https://help.branch.io/developer-hub/docs/flutter-sdk-basic-integration)

## Xcode / iOS 프로젝트 설정

`ios/Runner/Runner.entitlements`의 Associated Domains에는 Branch 기본 도메인과 alternate 도메인을 모두 넣는다.

아래처럼 두 Branch 도메인을 모두 넣어야 한다.

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:milecatch.app.link</string>
    <string>applinks:milecatch-alternate.app.link</string>
</array>
```

`ios/Runner/Info.plist`의 `branch_universal_link_domains`는 이미 두 도메인이 들어가 있으므로 유지한다.

```xml
<key>branch_universal_link_domains</key>
<array>
    <string>milecatch.app.link</string>
    <string>milecatch-alternate.app.link</string>
</array>
```

`Info.plist` 안에도 `com.apple.developer.associated-domains`가 들어가 있지만, iOS Universal Links에서 실제로 중요한 것은 `.entitlements` 파일이다. 혼동 방지를 위해 `Info.plist`의 Associated Domains 항목은 제거해도 된다.

## AASA 반영 확인

Branch Dashboard를 저장한 뒤 아래 명령으로 AASA 파일이 정상 제공되는지 확인한다.

```sh
curl -I https://milecatch.app.link/apple-app-site-association
curl -I https://milecatch-alternate.app.link/apple-app-site-association
```

정상이라면 둘 다 HTTP 200이 나와야 한다.

본문까지 확인하려면:

```sh
curl -sS https://milecatch.app.link/apple-app-site-association
curl -sS https://milecatch-alternate.app.link/apple-app-site-association
```

응답 JSON 안에 다음 형태의 appID가 포함되어 있어야 한다.

```text
V9MN8893Z6.com.mungyu.mileageThief
```

만약 루트 경로와 `.well-known` 경로가 모두 404라면 Branch Dashboard의 iOS Universal Links 설정이 저장되지 않았거나, Apple App Prefix / Bundle Identifier 값이 맞지 않는 상태로 보면 된다.

## iPhone 테스트 방법

iOS는 AASA 파일을 강하게 캐시한다. 설정을 바꾼 뒤에는 기존 설치 상태로 바로 테스트하면 실패한 캐시가 남아 있을 수 있다.

권장 순서:

1. Branch Dashboard 저장
2. AASA URL이 HTTP 200인지 확인
3. `Runner.entitlements`에 두 도메인이 모두 들어간 빌드 설치
4. iPhone에서 기존 앱 삭제
5. 앱 재설치
6. 메모, 문자, 카카오톡 등에서 Branch 링크 클릭

주의할 점:

- Safari 주소창에 Branch 링크를 직접 붙여넣는 방식은 Universal Links 테스트로 적합하지 않다.
- Branch 링크를 다른 짧은 링크나 광고 추적 링크로 감싸면 iOS에서 앱이 열리지 않을 수 있다.
- 사용자가 과거에 Universal Link 배너에서 웹으로 열기를 선택한 경우, 해당 기기에서 앱 열기가 비활성화되어 있을 수 있다.

## 정상 동작 기준

앱 설치 상태:

- Branch 링크 클릭
- Safari/fallback이 아니라 마일캐치 앱이 바로 열림
- Flutter 로그에 Branch 딥링크 데이터가 찍힘
- `+clicked_branch_link` 값이 `true`

앱 미설치 상태:

- Branch 링크 클릭
- App Store의 마일캐치 페이지로 이동
- App Store ID는 `6446247689`

## 빠른 체크리스트

- [ ] Branch Dashboard iOS `Apple App Prefix`에 `V9MN8893Z6` 또는 실제 App ID Prefix 입력
- [ ] Branch Dashboard iOS Bundle Identifier가 `com.mungyu.mileageThief`인지 확인
- [ ] Branch Dashboard iOS App Store ID가 `6446247689`인지 확인
- [ ] `Runner.entitlements`에 `applinks:milecatch.app.link` 추가
- [ ] `Runner.entitlements`에 `applinks:milecatch-alternate.app.link` 추가
- [ ] AASA 루트 URL 두 개가 HTTP 200인지 확인
- [ ] iPhone 앱 삭제 후 재설치
- [ ] Safari 주소창 직접 입력이 아니라 메시지/메모/카톡에서 링크 클릭 테스트
