# Milecatch Rich Editor 사용 가이드

## 🚀 빠른 시작

### 1. V2 화면 테스트하기

기존 `community_post_create_screen.dart` 대신 새로운 V2 화면을 사용하려면:

```dart
// 기존 코드를 찾아서
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => CommunityPostCreateScreen(
      initialBoardId: boardId,
      initialBoardName: boardName,
    ),
  ),
);

// 이렇게 변경하세요
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => CommunityPostCreateScreenV2(
      initialBoardId: boardId,
      initialBoardName: boardName,
    ),
  ),
);
```

### 2. import 추가

V2 화면을 사용하는 파일에 다음 import를 추가하세요:

```dart
import '../screen/community_post_create_screen_v2.dart';
```

### 3. 라우팅에서 사용하기

만약 named route를 사용한다면:

```dart
// main.dart 또는 라우팅 설정 파일에서
routes: {
  '/community_post_create_v2': (context) => CommunityPostCreateScreenV2(),
  // 기존 라우팅들...
}

// 사용할 때
Navigator.pushNamed(context, '/community_post_create_v2', arguments: {
  'initialBoardId': boardId,
  'initialBoardName': boardName,
});
```

## 🎯 주요 차이점

### V1 (기존) vs V2 (새 에디터)

| 기능 | V1 (html_editor_enhanced) | V2 (Milecatch Rich Editor) |
|------|--------------------------|---------------------------|
| 기반 기술 | 외부 패키지 | 자체 구현 라이브러리 |
| 커스터마이징 | 제한적 | 완전한 제어 |
| 브랜드 색상 | 기본 색상 | Milecatch 브랜드 색상 |
| 상태 관리 | 기본 | Provider 패턴으로 체계적 관리 |
| 확장성 | 어려움 | 쉬움 |
| 첨부파일 관리 | 기본 | 고급 관리 기능 |

### V2의 새로운 기능들

- ✨ **브랜드 통합**: Milecatch 색상 테마 적용
- 🎮 **체계적인 상태 관리**: PostingController로 모든 상태 통합 관리
- 📎 **고급 첨부파일 관리**: 진행률 표시, 타입별 관리, 에러 처리
- 🔧 **완전한 커스터마이징**: 모든 UI 요소 수정 가능
- 📱 **모바일 최적화**: 터치 인터페이스에 특화
- 🌙 **다크 모드 지원**: 라이트/다크 테마 지원

## 🔧 개발자를 위한 팁

### PostingController 활용

```dart
// 컨트롤러 상태 모니터링
_postingController.addListener(() {
  if (_postingController.hasUnsavedChanges) {
    // 변경사항 감지 시 처리
  }
  
  if (_postingController.isSaving) {
    // 저장 중일 때 처리
  }
});

// 유효성 검사
final errors = _postingController.validatePost();
if (errors.isNotEmpty) {
  // 에러 처리
}
```

### 에디터 직접 제어

```dart
final editorController = _postingController.editorController;

// 서식 적용
await editorController.setBold();
await editorController.setTextColor(Colors.red);

// 내용 삽입
await editorController.insertImage(imageUrl);
await editorController.insertText('새 텍스트');
```

### 첨부파일 관리

```dart
final attachmentController = _postingController.attachmentController;

// 상태 확인
print('첨부파일 개수: ${attachmentController.attachments.length}');
print('업로드 진행률: ${attachmentController.uploadingCount}');

// 에러 처리
if (attachmentController.lastError != null) {
  showSnackBar(attachmentController.lastError!);
}
```

## 🐛 문제 해결

### 자주 발생하는 문제들

1. **WebView 로딩이 안 됨**
   - 인터넷 권한 확인
   - Android에서 cleartext traffic 허용 설정

2. **첨부파일 선택이 안 됨**
   - 카메라/저장소 권한 확인
   - iOS에서 Info.plist 설정 확인

3. **한글 입력 문제**
   - WebView JavaScript 설정 확인
   - 입력 메서드 호환성 테스트

### 디버깅 도구

개발 중에는 다음과 같이 상태를 확인할 수 있습니다:

```dart
// 디버그 정보 표시 (개발 중에만)
if (kDebugMode) {
  Container(
    padding: EdgeInsets.all(8),
    color: Colors.yellow.withOpacity(0.2),
    child: Column(
      children: [
        Text('Editor Ready: ${_postingController.editorState.isReady}'),
        Text('Has Changes: ${_postingController.hasUnsavedChanges}'),
        Text('Attachments: ${_postingController.attachments.length}'),
      ],
    ),
  ),
}
```

## 📞 지원

문제가 발생하거나 새로운 기능이 필요한 경우:

1. 먼저 이 가이드와 README.md를 확인
2. 기존 코드의 패턴을 참고
3. 라이브러리 소스코드 확인 (`lib/milecatch_rich_editor/`)

Happy coding! 🎉
