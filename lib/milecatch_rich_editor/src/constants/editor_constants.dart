class EditorConstants {
  // HTML 템플릿
  static const String htmlTemplate = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Milecatch Rich Editor</title>
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        
        body {
            font-family: 'NanumGothic', sans-serif;
            font-size: 16px;
            line-height: 1.6;
            color: #212121;
            background-color: #ffffff;
        }
        
        .editor {
            min-height: 200px;
            padding: 16px;
            border: none;
            outline: none;
            resize: none;
            word-wrap: break-word;
        }
        
        .placeholder {
            color: #9e9e9e;
        }
        
        img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            margin: 8px 0;
        }
        
        p {
            margin-bottom: 12px;
        }
        
        h1, h2, h3, h4, h5, h6 {
            margin-bottom: 16px;
            font-weight: bold;
        }
        
        ul, ol {
            padding-left: 24px;
            margin-bottom: 12px;
        }
        
        blockquote {
            border-left: 4px solid #74512D;
            padding-left: 16px;
            margin: 16px 0;
            color: #757575;
            font-style: italic;
        }
    </style>
</head>
<body>
    <div class="editor" contenteditable="true" placeholder="내용을 입력하세요..."></div>
    
    <script>
        const editor = document.querySelector('.editor');
        
        // 포커스 시 placeholder 처리
        editor.addEventListener('focus', function() {
            if (this.textContent.trim() === '') {
                this.classList.remove('placeholder');
            }
        });
        
        editor.addEventListener('blur', function() {
            if (this.textContent.trim() === '') {
                this.classList.add('placeholder');
            }
        });
        
        // 초기 placeholder 설정
        if (editor.textContent.trim() === '') {
            editor.classList.add('placeholder');
        }
        
        // Flutter로 메시지 전송
        function sendMessage(type, data) {
            if (window.milecatchEditor && window.milecatchEditor.postMessage) {
                window.milecatchEditor.postMessage(JSON.stringify({
                    type: type,
                    data: data
                }));
            }
        }
        
        // 텍스트 변경 이벤트
        editor.addEventListener('input', function() {
            sendMessage('textChanged', {
                content: this.innerHTML,
                text: this.textContent
            });
        });
        
        // 포커스 이벤트
        editor.addEventListener('focus', function() {
            sendMessage('focus', {});
        });
        
        editor.addEventListener('blur', function() {
            sendMessage('blur', {});
        });
        
        // 에디터 준비 완료
        document.addEventListener('DOMContentLoaded', function() {
            sendMessage('ready', {});
        });
    </script>
</body>
</html>
  ''';

  // 다크 모드 HTML 템플릿
  static const String darkHtmlTemplate = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Milecatch Rich Editor (Dark Mode)</title>
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        
        body {
            font-family: 'NanumGothic', sans-serif;
            font-size: 16px;
            line-height: 1.6;
            color: #ffffff;
            background-color: #121212;
        }
        
        .editor {
            min-height: 200px;
            padding: 16px;
            border: none;
            outline: none;
            resize: none;
            word-wrap: break-word;
            color: #ffffff;
            background-color: #1e1e1e;
        }
        
        .placeholder {
            color: #757575;
        }
        
        img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            margin: 8px 0;
        }
        
        p {
            margin-bottom: 12px;
        }
        
        h1, h2, h3, h4, h5, h6 {
            margin-bottom: 16px;
            font-weight: bold;
        }
        
        ul, ol {
            padding-left: 24px;
            margin-bottom: 12px;
        }
        
        blockquote {
            border-left: 4px solid #8B6F3A;
            padding-left: 16px;
            margin: 16px 0;
            color: #bdbdbd;
            font-style: italic;
        }
    </style>
</head>
<body>
    <div class="editor" contenteditable="true" placeholder="내용을 입력하세요..."></div>
    
    <script>
        const editor = document.querySelector('.editor');
        
        // 포커스 시 placeholder 처리
        editor.addEventListener('focus', function() {
            if (this.textContent.trim() === '') {
                this.classList.remove('placeholder');
            }
        });
        
        editor.addEventListener('blur', function() {
            if (this.textContent.trim() === '') {
                this.classList.add('placeholder');
            }
        });
        
        // 초기 placeholder 설정
        if (editor.textContent.trim() === '') {
            editor.classList.add('placeholder');
        }
        
        // Flutter로 메시지 전송
        function sendMessage(type, data) {
            if (window.milecatchEditor && window.milecatchEditor.postMessage) {
                window.milecatchEditor.postMessage(JSON.stringify({
                    type: type,
                    data: data
                }));
            }
        }
        
        // 텍스트 변경 이벤트
        editor.addEventListener('input', function() {
            sendMessage('textChanged', {
                content: this.innerHTML,
                text: this.textContent
            });
        });
        
        // 포커스 이벤트
        editor.addEventListener('focus', function() {
            sendMessage('focus', {});
        });
        
        editor.addEventListener('blur', function() {
            sendMessage('blur', {});
        });
        
        // 에디터 준비 완료
        document.addEventListener('DOMContentLoaded', function() {
            sendMessage('ready', {});
        });
    </script>
</body>
</html>
  ''';

  // 지원되는 파일 형식
  static const List<String> supportedImageFormats = [
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'
  ];

  static const List<String> supportedDocumentFormats = [
    'pdf', 'doc', 'docx', 'txt', 'rtf', 'xls', 'xlsx', 'ppt', 'pptx'
  ];

  // 파일 크기 제한
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB
  static const int maxDocumentSize = 50 * 1024 * 1024; // 50MB
  static const int maxAttachmentCount = 20;
  static const int maxTextLength = 100000; // 10만자

  // 기본값
  static const String defaultPlaceholder = '내용을 입력하세요...';
  static const int defaultFontSize = 16;
  static const String defaultFontFamily = 'NanumGothic';

  // JavaScript 채널
  static const String jsChannelName = 'milecatchEditor';

  // 메시지 타입
  static const String messageTypeReady = 'ready';
  static const String messageTypeTextChanged = 'textChanged';
  static const String messageTypeFocus = 'focus';
  static const String messageTypeBlur = 'blur';
  static const String messageTypeDataChanged = 'dataChanged';
  static const String messageTypeError = 'error';

  // CSS 클래스
  static const String editorClassName = 'editor';
  static const String darkModeClassName = 'dark-mode';
  static const String placeholderClassName = 'placeholder';

  // 에디터 명령어
  static const Map<String, String> editorCommands = {
    'bold': 'bold',
    'italic': 'italic',
    'underline': 'underline',
    'strikethrough': 'strikeThrough',
    'justifyLeft': 'justifyLeft',
    'justifyCenter': 'justifyCenter',
    'justifyRight': 'justifyRight',
    'justifyFull': 'justifyFull',
    'insertOrderedList': 'insertOrderedList',
    'insertUnorderedList': 'insertUnorderedList',
    'indent': 'indent',
    'outdent': 'outdent',
    'undo': 'undo',
    'redo': 'redo',
  };
}

