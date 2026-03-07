# Social Login Integration Guide (Naver + Kakao + Firebase Custom Token)

This document explains how to replicate the same Naver/Kakao login flow used in `jobworld`
into other projects such as `gatchcatch`, `dubai`, and `mileage_thief`.

Use this as an implementation checklist, not just reference.

## 0) What this guide gives you

- Naver login via OAuth code flow + Firebase Custom Token
- Kakao login via OAuth code flow + Firebase Custom Token
- HTTPS bridge redirects for mobile deep-link callbacks
- Firebase Functions secret setup and deployment commands
- Asset/UI references from `jobworld`
- Troubleshooting for the exact errors we already hit in real integration

## 1) Reference source in this repository

Use these files as baseline implementation:

- Client OAuth service:
  - `lib/features/auth/services/social_custom_auth_service.dart`
- Server Functions (OAuth bridge + custom token creation):
  - `server/notification/src/index.ts`
- Login UI buttons:
  - `lib/screens/profile_screen.dart`
- Login button widget:
  - `lib/widgets/common_widgets.dart`
- Build env sample:
  - `env/prod.json`

Asset references:

- Kakao login images:
  - `assets/img/kakao_login/`
- Naver login images:
  - `assets/img/naver_login/`

Notes:

- Some notes/messages may mention `kako_login` by typo; actual folder name in this repo is `kakao_login`.
- When porting to another project, copy assets and keep the same relative structure.

### 1.1) Asset copy example

From each target project root, copy from this repository:

```bash
mkdir -p assets/img
cp -R /Users/vory/StudioProjects/jobworld/assets/img/kakao_login assets/img/
cp -R /Users/vory/StudioProjects/jobworld/assets/img/naver_login assets/img/
```

Then register them in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/img/kakao_login/
    - assets/img/naver_login/
```

## 2) High-level flow

1. App opens OAuth authorize URL in browser (`flutter_web_auth_2`)
2. OAuth provider redirects to HTTPS bridge Function (`.../naverOauthBridge`, `.../kakaoOauthBridge`)
3. Bridge Function redirects to app deep-link (`<app-scheme>://oauth/naver|kakao`)
4. App calls callable Function (`createNaverCustomToken`, `createKakaoCustomToken`) with `code/state/redirectUri`
5. Function exchanges code for provider token, fetches profile, issues Firebase custom token
6. App signs in with `FirebaseAuth.signInWithCustomToken(...)`

## 3) Project-specific values you must decide

Replace these in each target project:

- `APP_SCHEME` (example in jobworld: `jobworld`)
- `FIREBASE_PROJECT_ID`
- `FUNCTION_REGION` (jobworld uses `asia-northeast3`)
- Android `applicationId`
- iOS `bundle id`
- Provider keys/secrets:
  - `NAVER_CLIENT_ID`
  - `NAVER_CLIENT_SECRET`
  - `KAKAO_REST_API_KEY`
  - `KAKAO_CLIENT_SECRET`

## 4) Client app setup

## 4.1 pubspec dependencies

Required (same pattern as jobworld):

- `firebase_auth`
- `cloud_functions`
- `flutter_web_auth_2`

Migration note (important):

- If you are migrating from `flutter_naver_login` to OAuth bridge flow, remove `flutter_naver_login` from `pubspec.yaml`.
- On iOS, remove stale SDK glue code from `ios/Runner/AppDelegate.swift`:
  - `import NidThirdPartyLogin`
  - `NidOAuth.shared.handleURL(...)`
- Keep only app scheme callback handling through `flutter_web_auth_2`.

## 4.2 URL scheme callback setup

### Android (`android/app/src/main/AndroidManifest.xml`)

Add intent filter to MainActivity:

```xml
<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data
      android:scheme="APP_SCHEME"
      android:host="oauth" />
</intent-filter>
```

### iOS (`ios/Runner/Info.plist`)

Add URL scheme:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>APP_SCHEME</string>
    </array>
  </dict>
</array>
```

## 4.3 OAuth constants (client)

In your social auth service, set:

- callback scheme: `APP_SCHEME`
- Naver redirect URI: `https://<region>-<project>.cloudfunctions.net/naverOauthBridge`
- Kakao redirect URI: `https://<region>-<project>.cloudfunctions.net/kakaoOauthBridge`

Important:

- Do NOT use `APP_SCHEME://...` directly in Kakao console redirect URI.
- Kakao console redirect URI field requires HTTPS URL.
- That is why bridge function is mandatory for Kakao in this architecture.

## 4.4 Kakao scope recommendation

Default safe scope:

- `profile_nickname,profile_image`

Do not request `account_email` unless that consent item is approved in Kakao console.
Otherwise you get `KOE205`.

## 4.5 Login button order and style (same as jobworld)

- Android login button order:
  - Google -> Naver -> Kakao
- iOS login button order:
  - Google -> Apple -> Naver -> Kakao
- Kakao button styling:
  - border radius `22`
  - width aligned exactly with other login buttons
  - placed directly under Naver login button

If you reuse jobworld UI implementation, verify the above on both Android and iOS simulators/devices.

## 4.6 User profile document creation rule (important)

After custom-token sign-in succeeds, persist user document to Firestore (`users/{uid}`).

Keep this behavior:

- provider: `naver` or `kakao`
- providerUid: provider user id
- createdAt / lastLoginAt timestamps
- roles includes `user`
- default `photoURL` fallback
- `displayName` must follow generated `형용사 + 직업` rule when provider returns placeholder names (`네이버사용자`, `카카오사용자`)

In jobworld, the adjective source list is intentionally fixed (20 values):

- `멋진`, `힘쌘`, `용감한`, `밝은`, `친절한`, `튼튼한`, `슬기로운`, `든든한`, `재빠른`, `창의적인`,
  `반짝이는`, `당찬`, `유쾌한`, `상냥한`, `기특한`, `씩씩한`, `유능한`, `똑똑한`, `꿈꾸는`, `열정적인`

Do not change this list when porting unless product policy intentionally changes.

## 4.7 User document ownership (important, prevents regressions)

For this architecture, keep responsibilities separated:

- Cloud Functions (`createNaverCustomToken`, `createKakaoCustomToken`) should issue token + profile payload only.
- Client app should be the single owner of `users/{uid}` upsert logic.

Why this matters:

- If Functions also upsert `users/{uid}` on every login, it can overwrite:
  - `displayName` (breaks generated naming rules)
  - counters (`postCount`, `commentCount`, etc.)
  - profile-mode compatibility fields

Recommended rule:

- For custom-provider new users, generate displayName in client with deterministic noun+noun logic.
- Treat provider placeholder names (for example `네이버사용자`, `카카오사용자`, `가챠러...`) as replaceable defaults.
- Preserve user-edited display names on subsequent logins.

## 5) Server Functions setup

Functions file: `server/notification/src/index.ts`

Required functions:

- `naverOauthBridge` (HTTPS -> `APP_SCHEME://oauth/naver`)
- `kakaoOauthBridge` (HTTPS -> `APP_SCHEME://oauth/kakao`)
- `createNaverCustomToken` (callable)
- `createKakaoCustomToken` (callable)

Use `defineSecret` + `secrets: [...]` in each callable options, same as jobworld.

```ts
const NAVER_CLIENT_ID = defineSecret("NAVER_CLIENT_ID");
const NAVER_CLIENT_SECRET = defineSecret("NAVER_CLIENT_SECRET");
const KAKAO_REST_API_KEY = defineSecret("KAKAO_REST_API_KEY");
const KAKAO_CLIENT_SECRET = defineSecret("KAKAO_CLIENT_SECRET");
```

## 5.1 Kakao provider UID parsing (important)

Kakao `/v2/user/me` can return numeric `id`.
If you parse only string values, login fails even with status 200.

Use helper like:

```ts
function asIdString(value: unknown): string {
  if (typeof value === "string") return value.trim();
  if (typeof value === "number" && Number.isFinite(value)) return String(value);
  if (typeof value === "bigint") return value.toString();
  return "";
}
```

and:

```ts
const providerUid = asIdString(profilePayload.id);
```

## 5.2 Client secret handling

- `KAKAO_CLIENT_SECRET` can be optional in code if console setting is off.
- If Kakao client secret is enabled in console, token exchange must include it.

## 6) Provider console setup checklist

## 6.1 Kakao Developers

1. Turn Kakao Login ON
2. Register platform keys:
   - Android package name
   - iOS bundle id
3. Register Redirect URI (HTTPS bridge):
   - `https://<region>-<project>.cloudfunctions.net/kakaoOauthBridge`
4. Consent items:
   - Enable `profile_nickname`
   - Enable `profile_image`
   - Enable `account_email` only if you have permission

## 6.2 Naver Developers

1. Register app and service
2. Set callback URL:
   - `https://<region>-<project>.cloudfunctions.net/naverOauthBridge`
3. Copy client ID/secret

## 7) Firebase secrets and deploy

Run in Functions directory (`server/notification`):

```bash
firebase login --reauth
firebase use <project-id>

printf '%s' 'NAVER_CLIENT_ID_VALUE' | firebase functions:secrets:set NAVER_CLIENT_ID --data-file=-
printf '%s' 'NAVER_CLIENT_SECRET_VALUE' | firebase functions:secrets:set NAVER_CLIENT_SECRET --data-file=-
printf '%s' 'KAKAO_REST_API_KEY_VALUE' | firebase functions:secrets:set KAKAO_REST_API_KEY --data-file=-
printf '%s' 'KAKAO_CLIENT_SECRET_VALUE' | firebase functions:secrets:set KAKAO_CLIENT_SECRET --data-file=-

firebase deploy --only functions:createNaverCustomToken,functions:createKakaoCustomToken,functions:naverOauthBridge,functions:kakaoOauthBridge
```

Notes:

- `--data-file=-` is required (do not append random text to it).
- After secret update, redeploy functions using those secrets.

Optional verification:

```bash
firebase functions:secrets:get NAVER_CLIENT_ID
firebase functions:secrets:get NAVER_CLIENT_SECRET
firebase functions:secrets:get KAKAO_REST_API_KEY
firebase functions:secrets:get KAKAO_CLIENT_SECRET
```

## 8) IAM fix for custom token signing (if needed)

If you get:

- `auth/insufficient-permission`
- `iam.serviceAccounts.signBlob denied`

grant role:

- `roles/iam.serviceAccountTokenCreator`

to runtime service account (often default compute service account).

## 9) App build/release with dart-define

Create env file (project root):

- `env/prod.json`

Example:

```json
{
  "NAVER_CLIENT_ID": "YOUR_NAVER_CLIENT_ID",
  "KAKAO_REST_API_KEY": "YOUR_KAKAO_REST_API_KEY"
}
```

Build:

```bash
flutter build appbundle --release --dart-define-from-file=env/prod.json
flutter build ipa --release --dart-define-from-file=env/prod.json
```

Local run:

```bash
flutter run --dart-define-from-file=env/prod.json
```

Do not use this wrong form:

```bash
flutter run --dart-define env/prod.json
```

Important:

- End users do not type dart-define.
- Build pipeline/CI must inject these values.

## 9.1 iOS release note

- `flutter build ipa ...` builds release artifacts and updates iOS build outputs.
- Final App Store upload is still done through Xcode archive flow (`Runner.xcworkspace` -> Product -> Archive).
- If archive is not visible in Organizer, open `ios/Runner.xcworkspace` and archive from Xcode directly.

## 10) Troubleshooting (real errors and fixes)

### KOE205 (Kakao invalid scope)

Cause:

- Requested scope not enabled in consent items.

Fix:

- Enable requested scopes in Kakao console, or remove unavailable scope from code.

### KOE205 still appears after adding consent items

Cause:

- Updated consent items in a different Kakao app than the one used by current REST API key.
- Redirect URI was not saved exactly (or missing from the same app settings).
- App was reloaded without full restart and stale run context remained.

Fix:

- Verify app key match first:
  - REST API key in app env must match the Kakao console app you edited.
- Verify exact redirect URI in Kakao console:
  - `https://<region>-<project>.cloudfunctions.net/kakaoOauthBridge`
- Fully restart app run (not hot reload only):
  - `flutter run --dart-define-from-file=env/prod.json`
- If console settings were just changed, retry after a short propagation wait.

### Kakao redirect URI invalid URL

Cause:

- Using `APP_SCHEME://...` in Kakao redirect URI field.

Fix:

- Register HTTPS bridge URI in Kakao console.

### Kakao profile lookup failed: unknown_error

Cause:

- Profile fetch returned payload with numeric `id`, parser expected string.

Fix:

- Parse `id` as string-or-number (`asIdString` helper).

### Wrong client id / client secret pair

Cause:

- Provider key/secret mismatch with app.

Fix:

- Recheck provider console keys and Firebase secrets.

### Firebase custom token signBlob denied

Cause:

- Missing IAM permission for function runtime service account.

Fix:

- Grant `roles/iam.serviceAccountTokenCreator`.
- Example command:

```bash
gcloud projects add-iam-policy-binding <project-id> \
  --member="serviceAccount:<project-number>-compute@developer.gserviceaccount.com" \
  --role="roles/iam.serviceAccountTokenCreator"
```

### Android build error in flutter_web_auth_2 (Registrar unresolved)

Cause:

- Old plugin version incompatible with current Android/Flutter toolchain.

Fix:

- Upgrade `flutter_web_auth_2` to newer version and run `flutter pub get`.

### `List<Object?>` / `PigeonUser...` type cast errors after custom token sign-in

Cause:

- FlutterFire plugin codec mismatch can appear right after `signInWithCustomToken` or `updateProfile`.

Fix:

- Keep the defensive flow used in jobworld:
  - treat this specific decode error as recoverable
  - re-read `FirebaseAuth.instance.currentUser`
  - continue Firestore upsert flow
  - avoid forcing `updateDisplayName` for custom provider uid (`naver:...`, `kakao:...`)

### iOS Swift Compiler Error: `Unable to find module dependency: 'NidThirdPartyLogin'`

Cause:

- `flutter_naver_login` was removed from pubspec, but `ios/Runner/AppDelegate.swift` still imports/uses `NidThirdPartyLogin`.

Fix:

- Remove `import NidThirdPartyLogin`.
- Remove `NidOAuth.shared.handleURL(...)` branch.
- Rebuild iOS app (`flutter clean` + `flutter pub get` + `flutter run ...`).

### Callable returns `INTERNAL` even though OAuth succeeded

Cause:

- Root cause is usually inside Cloud Functions (not client-side callback).

Fix:

- Always inspect function logs first:

```bash
firebase functions:log --only createNaverCustomToken
```

- In real integration we saw:
  - `iam.serviceAccounts.signBlob denied` (IAM role issue)
  - Firestore `Cannot use "undefined" as a Firestore value` (provider optional fields not normalized)

### Firestore error: `Cannot use "undefined" as a Firestore value (field "email")`

Cause:

- Naver profile can omit optional fields (`email`, `nickname`, `profile_image`).
- Writing raw provider payload directly to Firestore can include `undefined`.

Fix:

- Normalize provider profile values to safe strings or `null` before Firestore write.
- Never assume email exists for Naver login.
- Use fallback display name when nickname/name is missing.

### Display name changed unexpectedly after provider login

Cause:

- Server-side function rewrote `users/{uid}.displayName` on every login.
- Placeholder/provider-derived names were treated as final values.

Fix:

- Keep token creation on server; keep user profile upsert in client.
- In client upsert, replace provider placeholder names with generated noun+noun displayName.
- Keep a placeholder detector broad enough to catch migrated legacy values.

### Naver account returns little or no profile data

Cause:

- Consent scopes are not enabled (or user did not provide optional fields).

Fix:

- Design login flow to require only provider user id for account linking.
- Treat `email`, `nickname`, `name`, `profile_image` as optional.
- In client user upsert, avoid overwriting existing fields with empty strings.

## 11) Porting checklist per project (`gatchcatch`, `dubai`, `mileage_thief`)

1. Copy social auth service pattern
2. Copy bridge + callable function pattern
3. Configure provider consoles with project-specific redirect URIs
4. Register Firebase secrets in that project
5. Deploy functions in that project
6. Add `env/prod.json` with project keys
7. Build with `--dart-define-from-file`
8. Run smoke tests on Android + iOS

If all 8 pass, Naver/Kakao integration is production-ready.
