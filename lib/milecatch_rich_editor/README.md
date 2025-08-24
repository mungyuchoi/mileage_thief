# Milecatch Rich Editor

Samsung Members 스타일의 리치 텍스트 에디터를 Flutter 앱에서 사용할 수 있도록 하는 라이브러리입니다.

## 주요 기능

- 📝 **리치 텍스트 편집**: 텍스트 서식(볼드, 이탤릭, 언더라인), 색상, 폰트 크기 조정
- 📎 **첨부파일 관리**: 이미지 및 문서 파일 첨부 (최대 20개)
- 🎨 **커스터마이징**: 다크 모드, 색상 팔레트, 폰트 설정
- 📱 **모바일 최적화**: 터치 인터페이스에 최적화된 UI/UX
- 🔄 **상태 관리**: Provider 패턴을 사용한 효율적인 상태 관리

## 설치

`pubspec.yaml` 파일에 다음 의존성들을 추가하세요:

```yaml
dependencies:
  webview_flutter: ^4.4.2
  image_picker: ^1.1.2
  file_picker: ^6.1.1
  permission_handler: ^12.0.1
  path_provider: ^2.1.2
  path: ^1.8.3
  uuid: ^4.0.0
  device_info_plus: ^11.5.0
  package_info_plus: ^8.3.0
```

## 기본 사용법

### 1. PostingController 초기화

```dart
import 'package:mileage_thief/milecatch_rich_editor/milecatch_rich_editor.dart';

class MyPostingScreen extends StatefulWidget {
  @override
  _MyPostingScreenState createState() => _MyPostingScreenState();
}

class _MyPostingScreenState extends State<MyPostingScreen> {
  late PostingController _postingController;

  @override
  void initState() {
    super.initState();
    _postingController = PostingController();
  }

  @override
  void dispose() {
    _postingController.dispose();
    super.dispose();
  }
  
  // ...
}
```

### 2. RichTextEditor 위젯 사용

```dart
Container(
  height: 400,
  child: RichTextEditor(
    initialContent: widget.editContentHtml,
    placeholder: '내용을 입력하세요...',
    isEditMode: widget.isEditMode,
    onTextChanged: (text) {
      // 텍스트 변경 시 콜백
      print('Text changed: $text');
    },
    onDataChanged: (data) {
      // 데이터 변경 시 콜백
      print('Data changed: $data');
    },
    onFocusChanged: () {
      // 포커스 변경 시 콜백
      print('Focus changed');
    },
  ),
),
```

### 3. 제목 입력 필드 연결

```dart
TextField(
  controller: _postingController.titleController,
  decoration: const InputDecoration(
    hintText: '제목',
    border: InputBorder.none,
  ),
  style: const TextStyle(fontSize: 18),
),
```

### 4. 첨부파일 기능 사용

```dart
ElevatedButton.icon(
  onPressed: () async {
    await _postingController.attachmentController.pickImageFromGallery();
  },
  icon: const Icon(Icons.add_photo_alternate_outlined),
  label: Text('사진 추가 (${_postingController.attachments.length}/20)'),
),
```

### 5. 게시글 저장

```dart
Future<void> _handleSubmit() async {
  // 유효성 검사
  final validation = _postingController.validatePost();
  if (validation.isNotEmpty) {
    // 에러 처리
    return;
  }

  // 게시글 저장
  final success = await _postingController.savePost();
  if (success) {
    // 성공 처리
    Navigator.pop(context);
  }
}
```

## 고급 사용법

### 에디터 컨트롤러 직접 사용

```dart
// 에디터 컨트롤러 접근
final editorController = _postingController.editorController;

// 텍스트 서식 적용
await editorController.setBold();
await editorController.setItalic();
await editorController.setTextColor(Colors.red);
await editorController.setFontSize(18);

// 이미지 삽입
await editorController.insertImage('https://example.com/image.jpg');

// HTML 내용 설정/가져오기
await editorController.setHtml('<p>Hello World</p>');
final content = await editorController.getHtml();
```

### 첨부파일 컨트롤러 직접 사용

```dart
final attachmentController = _postingController.attachmentController;

// 갤러리에서 이미지 선택
final image = await attachmentController.pickImageFromGallery();

// 카메라로 사진 촬영
final photo = await attachmentController.pickImageFromCamera();

// 파일 선택
final file = await attachmentController.pickFile();

// 첨부파일 제거
attachmentController.removeAttachment(attachmentId);
```

### 상태 모니터링

```dart
// PostingController 상태 리스너
_postingController.addListener(() {
  if (_postingController.hasUnsavedChanges) {
    // 변경사항이 있을 때의 처리
  }
  
  if (_postingController.isSaving) {
    // 저장 중일 때의 처리
  }
});
```

## 커스터마이징

### 색상 테마 변경

```dart
import 'package:mileage_thief/milecatch_rich_editor/src/constants/color_constants.dart';

// 브랜드 색상 사용
final brandColor = ColorConstants.milecatchBrown;
final lightBrandColor = ColorConstants.milecatchLightBrown;

// 에디터 색상 팔레트 사용
final editorColors = ColorConstants.editorColors;
```

### 폰트 설정 변경

```dart
import 'package:mileage_thief/milecatch_rich_editor/src/constants/font_constants.dart';

// 사용 가능한 폰트 크기
final availableSizes = FontConstants.availableFontSizes;

// 커스텀 텍스트 스타일 생성
final customStyle = FontConstants.createTextStyle(
  fontSize: 18,
  fontWeight: FontWeight.bold,
  fontFamily: 'NanumGothic',
  color: Colors.black,
);
```

## 주요 클래스

### 모델 클래스
- `EditorState`: 에디터 상태 관리
- `ToolbarState`: 툴바 상태 관리
- `PostingData`: 게시글 데이터 모델
- `AttachmentFile`: 첨부파일 정보 모델
- `UiComposingData`: JavaScript에서 전달되는 작성 데이터

### 컨트롤러 클래스
- `PostingController`: 게시글 작성 전체 상태 관리
- `EditorController`: 리치 텍스트 에디터 제어 전용
- `AttachmentController`: 첨부파일 관리 전용

### 유틸리티 클래스
- `JSBridge`: JavaScript와 Flutter 간 통신
- `FileUtils`: 파일 처리 관련 유틸리티
- `ImageUtils`: 이미지 처리 관련 유틸리티
- `PlatformUtils`: 플랫폼 관련 유틸리티

## 제한사항

- 최대 첨부파일 개수: 20개
- 이미지 파일 최대 크기: 10MB
- 문서 파일 최대 크기: 50MB
- 텍스트 최대 길이: 100,000자

## 지원 파일 형식

### 이미지 파일
- JPG, JPEG, PNG, GIF, WebP, SVG

### 문서 파일
- PDF, DOC, DOCX, TXT, RTF, XLS, XLSX, PPT, PPTX

## 라이선스

이 라이브러리는 Mileage Thief 프로젝트의 일부입니다.

