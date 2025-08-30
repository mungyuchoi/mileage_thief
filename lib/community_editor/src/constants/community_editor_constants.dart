class CommunityEditorConstants {
  // 디버그용 간단한 HTML 템플릿
  static const String simpleHtmlTemplate = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Simple Community Editor</title>
    <style>
        :root {
            --vvh: 100dvh;             /* visual viewport height (fallback: 100dvh) */
            --toolbar-h: 0px;          /* 툴바 높이 (keyboard up일 때만 설정) */
            --bottom-gap: 0px;         /* 하단 추가 여백 (툴바+안전영역) */
        }
        body {
            font-family: 'NanumGothic', -apple-system, BlinkMacSystemFont, sans-serif;
            margin: 0;
            padding: 0;
            background-color: #ffffff;
            font-size: 16px;
            line-height: 1.6;
            height: 100vh;
            overflow-y: auto;
        }
        .editor {
            min-height: calc(var(--vvh) - var(--toolbar-h));
            padding: 0 0 0 0;
            border: none;
            outline: none;
            width: 100%;
            background: transparent;
            font-family: inherit;
            font-size: 16px; /* 기본 폰트 크기 명시 */
            line-height: inherit;
            color: #000000; /* 기본 검은색 명시 */
            box-sizing: border-box;
            padding-bottom: var(--bottom-gap);
            overflow-y: auto;
            -webkit-overflow-scrolling: touch;
        }
        .editor:empty:before {
            content: attr(placeholder);
            color: #9e9e9e;
            pointer-events: none;
        }
        
        /* 리스트 스타일 */
        ul {
            list-style-type: disc; /* 가운데 점 */
            margin: 0.5em 0;
            padding-left: 20px;
        }
        
        ul li {
            margin: 0.2em 0;
            line-height: 1.6;
        }
        
        ol {
            margin: 0.5em 0;
            padding-left: 20px;
        }
        
        ol li {
            margin: 0.2em 0;
            line-height: 1.6;
        }
    </style>
</head>
<body>
    <div class="editor" contenteditable="true" placeholder="오늘 어떤 여행을 떠나셨나요?\n경험을 공유해주세요!"></div>
    
    <script>
        console.log('JavaScript loaded');
        
        function sendMessage(type, data) {
            try {
                if (window.communityEditor && window.communityEditor.postMessage) {
                    window.communityEditor.postMessage(JSON.stringify({
                        type: type,
                        data: data || {}
                    }));
                    console.log('Message sent:', type);
                } else {
                    console.log('communityEditor channel not available');
                }
            } catch (e) {
                console.error('Error sending message:', e);
            }
        }
        
        // 즉시 ready 메시지 전송
        setTimeout(function() {
            sendMessage('ready', {});
            console.log('Ready message sent');
        }, 100);
        
        const editor = document.querySelector('.editor');
        
        editor.addEventListener('input', function() {
            sendMessage('textChanged', {
                content: this.innerHTML,
                text: this.textContent
            });
            // 텍스트 변경 시 포맷 상태 확인 및 스크롤 조정
            setTimeout(function() {
                checkFormatState();
                if (window.communityEditorAPI && window.communityEditorAPI.scrollIntoView) {
                    window.communityEditorAPI.scrollIntoView();
                }
            }, 50);
        });
        
        editor.addEventListener('focus', function() {
            sendMessage('focus', {});
            // 포커스 시 포맷 상태 확인
            setTimeout(function() {
                checkFormatState();
            }, 100);
        });
        
        editor.addEventListener('blur', function() {
            sendMessage('blur', {});
        });
        
        // 선택 변경 시 포맷 상태 확인
        document.addEventListener('selectionchange', function() {
            checkFormatState();
        });
        
        // 키보드 입력 후 스크롤 조정
        editor.addEventListener('keyup', function() {
            setTimeout(function() {
                if (window.communityEditorAPI && window.communityEditorAPI.scrollIntoView) {
                    window.communityEditorAPI.scrollIntoView();
                }
            }, 50);
        });
        
        // 포맷 상태 확인 함수
        function checkFormatState() {
            try {
                // 에디터에 포커스가 있을 때만 상태 확인
                if (document.activeElement === editor) {
                    var formatState = {
                        bold: document.queryCommandState('bold'),
                        italic: document.queryCommandState('italic'),
                        underline: document.queryCommandState('underline'),
                        insertUnorderedList: document.queryCommandState('insertUnorderedList')
                    };
                    
                    console.log('Format state checked:', formatState);
                    sendMessage('formatChanged', { formatState: formatState });
                }
            } catch (e) {
                console.error('Error checking format state:', e);
            }
        }
        
        // API 설정
        window.communityEditorAPI = {
            focus: function() {
                editor.focus();
            },
            blur: function() {
                editor.blur();
            },
            setHTML: function(html) {
                editor.innerHTML = html;
            },
            getHTML: function() {
                return editor.innerHTML;
            },
            getText: function() {
                return editor.textContent;
            },
            setPlaceholder: function(text) {
                editor.setAttribute('placeholder', text);
            },
            execCommand: function(command, value) {
                try {
                    document.execCommand(command, false, value);
                    
                    // 명령 실행 후 포맷 상태 확인
                    setTimeout(function() {
                        checkFormatState();
                    }, 50);
                } catch (e) {
                    console.error('Error executing command:', e);
                }
            },
            insertList: function(ordered) {
                try {
                    // 순서 없는 리스트(bullet list) 또는 순서 있는 리스트 삽입
                    var command = ordered ? 'insertOrderedList' : 'insertUnorderedList';
                    document.execCommand(command, false, null);
                    
                    // 리스트 스타일 적용 (가운데 점 스타일)
                    if (!ordered) {
                        var selection = window.getSelection();
                        if (selection.rangeCount > 0) {
                            var container = selection.getRangeAt(0).commonAncestorContainer;
                            var listElement = container.nodeType === Node.TEXT_NODE ? 
                                container.parentNode : container;
                            
                            // 리스트 요소 찾기
                            while (listElement && listElement.tagName !== 'UL' && listElement.tagName !== 'OL') {
                                listElement = listElement.parentNode;
                                if (!listElement || listElement === editor) break;
                            }
                            
                            if (listElement && listElement.tagName === 'UL') {
                                listElement.style.listStyleType = 'disc'; // 가운데 점 스타일
                                listElement.style.paddingLeft = '20px';
                                listElement.style.marginLeft = '0px';
                            }
                        }
                    }
                    
                    // 포맷 상태 확인
                    setTimeout(function() {
                        checkFormatState();
                    }, 50);
                } catch (e) {
                    console.error('Error inserting list:', e);
                }
            },
            scrollIntoView: function() {
                // 커서 위치가 툴바에 가려지지 않도록 스크롤 조정
                var selection = window.getSelection();
                if (selection.rangeCount > 0) {
                    var range = selection.getRangeAt(0);
                    var rect = range.getBoundingClientRect();
                    var toolbarHeight = 80; // 툴바 높이
                    
                    if (rect.bottom > window.innerHeight - toolbarHeight) {
                        editor.scrollTop += (rect.bottom - (window.innerHeight - toolbarHeight) + 20);
                    }
                }
            }
        };
        
        (function () {
          function applyViewport() {
            var h = (window.visualViewport && window.visualViewport.height)
                      ? window.visualViewport.height
                      : window.innerHeight;
            document.documentElement.style.setProperty('--vvh', h + 'px');
          }
          applyViewport();
          if (window.visualViewport) {
            window.visualViewport.addEventListener('resize', applyViewport);
          }
          window.addEventListener('orientationchange', applyViewport);
          window.addEventListener('resize', applyViewport);
        })();
      
        // 2) Flutter에서 키보드/툴바 상태를 알려줄 때 호출할 함수
        //   예: keyboard up -> setToolbar(56)  / keyboard down -> setToolbar(0)
        function setToolbarHeight(px) {
          const safeBottom = (window.safeAreaInsets && window.safeAreaInsets.bottom) ? window.safeAreaInsets.bottom : 0;
          document.documentElement.style.setProperty('--toolbar-h', px + 'px');
          document.documentElement.style.setProperty('--bottom-gap', (px + safeBottom) + 'px');
        }
      
        // 3) 타이핑 시 커서가 항상 보이도록 (contenteditable/textarea 공통 대응)
        function scrollCaretIntoView() {
          const sel = document.getSelection && document.getSelection();
          if (!sel || sel.rangeCount === 0) return;
          const range = sel.getRangeAt(0);
          const rect = range.getBoundingClientRect();
          // editor 스크롤 컨테이너 기준으로 보이게
          const editor = document.querySelector('.editor');
          if (!editor) return;
          const er = editor.getBoundingClientRect();
          if (rect.bottom > er.bottom - 8) editor.scrollTop += (rect.bottom - er.bottom + 8);
          if (rect.top < er.top + 8)      editor.scrollTop -= (er.top - rect.top + 8);
        }
      
        document.addEventListener('selectionchange', scrollCaretIntoView);
        document.addEventListener('input', scrollCaretIntoView);
        
        console.log('API initialized');
    </script>
</body>
</html>
  ''';

  // HTML 템플릿 (커뮤니티용)
  static const String htmlTemplate = '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Community Rich Editor</title>
    <style>
        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
        }
        
        body {
            font-family: 'NanumGothic', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            font-size: 16px;
            line-height: 1.6;
            color: #212121;
            background-color: #ffffff;
            overflow-x: hidden;
        }
        
        .editor {
            min-height: 200px;
            padding: 16px;
            border: none;
            outline: none;
            resize: none;
            word-wrap: break-word;
            font-family: inherit;
            font-size: inherit;
            line-height: inherit;
            color: inherit;
        }
        
        /* contenteditable placeholder 표시 */
        .editor:empty:before {
            content: attr(placeholder);
            color: #9e9e9e;
            pointer-events: none;
        }

        .placeholder {
            color: #9e9e9e;
        }
        
        /* 이미지 스타일 */
        img {
            max-width: 100%;
            height: auto;
            border-radius: 8px;
            margin: 8px 0;
            display: block;
            object-fit: cover;
        }
        
        .image-container {
            position: relative;
            display: inline-block;
            max-width: 100%;
            margin: 8px 0;
        }
        
        .image-loading {
            background: #f5f5f5;
            border: 2px dashed #ddd;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            color: #999;
            margin: 8px 0;
        }
        
        /* 텍스트 포맷팅 */
        .bold, strong, b { font-weight: bold; }
        .italic, em, i { font-style: italic; }
        .underline, u { text-decoration: underline; }
        .strike { text-decoration: line-through; }
        
        /* 문단 스타일 */
        p {
            margin-bottom: 12px;
            min-height: 1.6em;
        }
        
        p:last-child {
            margin-bottom: 0;
        }
        
        h1, h2, h3, h4, h5, h6 {
            margin-bottom: 16px;
            font-weight: bold;
            line-height: 1.3;
        }
        
        h1 { font-size: 2em; }
        h2 { font-size: 1.5em; }
        h3 { font-size: 1.17em; }
        
        /* 리스트 스타일 */
        ul, ol {
            padding-left: 24px;
            margin-bottom: 12px;
        }
        
        ul li { list-style-type: disc; }
        ol li { list-style-type: decimal; }
        
        li {
            margin-bottom: 4px;
            line-height: 1.5;
        }
        
        /* 인용문 스타일 */
        blockquote {
            border-left: 4px solid #74512D;
            padding-left: 16px;
            margin: 16px 0;
            color: #757575;
            font-style: italic;
            background-color: #f9f9f9;
            padding: 12px 16px;
            border-radius: 4px;
        }
        
        /* 정렬 클래스 */
        .text-left { text-align: left; }
        .text-center { text-align: center; }
        .text-right { text-align: right; }
        .text-justify { text-align: justify; }
        
        /* 색상 및 배경 */
        .text-color { color: inherit; }
        .bg-color { background-color: inherit; }
        
        /* 링크 스타일 */
        a {
            color: #74512D;
            text-decoration: none;
        }
        
        a:hover {
            text-decoration: underline;
        }
        
        /* 코드 스타일 */
        code {
            background-color: #f1f1f1;
            padding: 2px 4px;
            border-radius: 3px;
            font-family: 'Courier New', Courier, monospace;
            font-size: 0.9em;
        }
        
        pre {
            background-color: #f8f8f8;
            padding: 12px;
            border-radius: 4px;
            overflow-x: auto;
            margin: 12px 0;
        }
        
        /* 구분선 */
        hr {
            border: none;
            border-top: 1px solid #ddd;
            margin: 20px 0;
        }
        
        /* 선택 영역 */
        ::selection {
            background-color: #74512D;
            color: white;
        }
        
        /* 포커스 상태 */
        .editor:focus {
            outline: none;
        }
        
        /* 테이블 스타일 */
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 12px 0;
        }
        
        table th, table td {
            border: 1px solid #ddd;
            padding: 8px;
            text-align: left;
        }
        
        table th {
            background-color: #f2f2f2;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="editor" contenteditable="true" placeholder="오늘 어떤 여행을 떠나셨나요?\n경험을 공유해주세요!"></div>
    
    <script>
        const editor = document.querySelector('.editor');
        let isReady = false;
        
        // 시각적 빈 상태 판단 (이미지 등은 내용으로 간주)
        function isVisuallyEmpty() {
            try {
                // 이미지 또는 로딩 프레임이 있으면 비어있지 않음
                if (editor.querySelector('img, .image-loading')) return false;
                // 텍스트가 있으면 비어있지 않음 (zero-width space 제거)
                const txt = editor.textContent.replace(/\u200B/g, '').trim();
                if (txt.length > 0) return false;
                // HTML이 <br> 같은 빈 라인만 있는 경우는 빈 것으로 간주
                const html = (editor.innerHTML || '').replace(/\s|&nbsp;/g, '').toLowerCase();
                return html === '' || html === '<br>' || html === '<p><br></p>';
            } catch (e) { return false; }
        }

        // 포커스 시 placeholder 처리
        editor.addEventListener('focus', function() {
            if (isVisuallyEmpty()) {
                // 비어있으면 진짜 비우기 (브라우저가 넣는 <br> 제거)
                this.innerHTML = '';
                this.classList.remove('placeholder');
            }
            sendMessage('focus', {});
        });
        
        editor.addEventListener('blur', function() {
            if (isVisuallyEmpty()) {
                // 비어있으면 진짜 비우기 -> :empty CSS placeholder 표시
                this.innerHTML = '';
                this.classList.add('placeholder');
            }
            sendMessage('blur', {});
        });
        
        // 초기 placeholder 설정
        if (isVisuallyEmpty()) {
            editor.innerHTML = '';
            editor.classList.add('placeholder');
        }

        // 모바일에서 터치만으로도 명시적으로 포커스/메시지 발생 보장
        const ensureFocus = function() {
            try {
                editor.focus();
                if (isVisuallyEmpty()) editor.innerHTML = '';
                sendMessage('focus', {});
            } catch (e) {}
        };
        editor.addEventListener('pointerdown', ensureFocus);
        editor.addEventListener('touchstart', ensureFocus, {passive: true});
        editor.addEventListener('click', ensureFocus);
        
        // Flutter로 메시지 전송
        function sendMessage(type, data) {
            try {
                if (window.communityEditor && window.communityEditor.postMessage) {
                    window.communityEditor.postMessage(JSON.stringify({
                        type: type,
                        data: data
                    }));
                } else {
                    console.log('communityEditor channel not available yet');
                }
            } catch (e) {
                console.error('Error sending message to Flutter:', e);
            }
        }
        
        // 텍스트 변경 이벤트
        editor.addEventListener('input', function() {
            sendMessage('textChanged', {
                content: this.innerHTML,
                text: this.textContent
            });
        });
        
        // 키보드 이벤트
        editor.addEventListener('keydown', function(e) {
            // Enter 키 처리
            if (e.key === 'Enter') {
                handleEnterKey(e);
            }
        });
        
        // Enter 키 처리 함수
        function handleEnterKey(e) {
            const selection = window.getSelection();
            const range = selection.getRangeAt(0);
            const currentElement = range.commonAncestorContainer;
            
            // 현재 요소가 리스트 아이템인지 확인
            let listItem = currentElement.nodeType === Node.TEXT_NODE 
                ? currentElement.parentElement 
                : currentElement;
                
            while (listItem && listItem.tagName !== 'LI' && listItem !== editor) {
                listItem = listItem.parentElement;
            }
            
            if (listItem && listItem.tagName === 'LI') {
                // 빈 리스트 아이템에서 Enter를 누르면 리스트 종료
                if (listItem.textContent.trim() === '') {
                    e.preventDefault();
                    const list = listItem.parentElement;
                    const newP = document.createElement('p');
                    newP.innerHTML = '<br>';
                    list.parentNode.insertBefore(newP, list.nextSibling);
                    listItem.remove();
                    
                    // 커서를 새 문단으로 이동
                    const newRange = document.createRange();
                    newRange.setStart(newP, 0);
                    newRange.collapse(true);
                    selection.removeAllRanges();
                    selection.addRange(newRange);
                }
            }
        }
        
        // 에디터 명령어 실행 함수들
        window.communityEditorAPI = {
            // 기본 포맷팅
            execCommand: function(command, value) {
                document.execCommand(command, false, value);
                sendMessage('formatChanged', { command: command, value: value });
            },
            
            // HTML 설정
            setHTML: function(html) {
                editor.innerHTML = html;
                if (editor.textContent.trim() === '') {
                    editor.classList.add('placeholder');
                } else {
                    editor.classList.remove('placeholder');
                }
            },
            
            // HTML 가져오기
            getHTML: function() {
                return editor.innerHTML;
            },
            
            // 텍스트 가져오기
            getText: function() {
                return editor.textContent;
            },
            
            // 포커스 설정
            focus: function() {
                editor.focus();
            },
            
            // 이미지 삽입
            insertImage: function(src, alt) {
                const img = document.createElement('img');
                img.src = src;
                img.alt = alt || 'Image';
                img.style.maxWidth = '100%';
                img.style.height = 'auto';
                
                const selection = window.getSelection();
                if (selection.rangeCount > 0) {
                    const range = selection.getRangeAt(0);
                    range.deleteContents();
                    range.insertNode(img);
                    
                    // 이미지 뒤에 커서 위치
                    range.setStartAfter(img);
                    range.collapse(true);
                    selection.removeAllRanges();
                    selection.addRange(range);
                } else {
                    editor.appendChild(img);
                }
                
                sendMessage('imageInserted', { src: src, alt: alt });
            },
            
            // 로딩 이미지 표시
            insertLoadingImage: function(id) {
                const loadingDiv = document.createElement('div');
                loadingDiv.className = 'image-loading';
                loadingDiv.id = 'loading-' + id;
                loadingDiv.innerHTML = '이미지 업로드 중...';
                
                const selection = window.getSelection();
                if (selection.rangeCount > 0) {
                    const range = selection.getRangeAt(0);
                    range.deleteContents();
                    range.insertNode(loadingDiv);
                    range.setStartAfter(loadingDiv);
                    range.collapse(true);
                    selection.removeAllRanges();
                    selection.addRange(range);
                } else {
                    editor.appendChild(loadingDiv);
                }
            },
            
            // 로딩 이미지를 실제 이미지로 교체
            replaceLoadingImage: function(id, src, alt) {
                const loadingDiv = document.getElementById('loading-' + id);
                if (loadingDiv) {
                    const img = document.createElement('img');
                    img.src = src;
                    img.alt = alt || 'Image';
                    img.style.maxWidth = '100%';
                    img.style.height = 'auto';
                    
                    loadingDiv.parentNode.replaceChild(img, loadingDiv);
                    sendMessage('imageReplaced', { id: id, src: src, alt: alt });
                }
            },
            
            // 이미 삽입된 이미지의 src를 교체 (업로드 완료 후 호출)
            updateImageSrc: function(oldSrc, newSrc) {
                try {
                    const imgs = editor.querySelectorAll('img');
                    for (let i = 0; i < imgs.length; i++) {
                        if (imgs[i].src === oldSrc) {
                            imgs[i].src = newSrc;
                        }
                    }
                } catch (e) {
                    console.error('updateImageSrc error', e);
                }
            },
            
            // 리스트 생성
            insertList: function(ordered) {
                const command = ordered ? 'insertOrderedList' : 'insertUnorderedList';
                document.execCommand(command, false, null);
                sendMessage('listInserted', { ordered: ordered });
            },
            
            // 플레이스홀더 설정
            setPlaceholder: function(text) {
                editor.setAttribute('placeholder', text);
            }
        };
        
        // 에디터 준비 완료
        document.addEventListener('DOMContentLoaded', function() {
            console.log('DOM Content Loaded');
            isReady = true;
            
            // 잠시 후 ready 메시지 전송 (JavaScript 채널이 준비될 시간을 줌)
            setTimeout(function() {
                sendMessage('ready', {});
                console.log('Ready message sent');
            }, 100);
        });
        
        // 추가적인 안전장치
        window.addEventListener('load', function() {
            console.log('Window loaded');
            if (!isReady) {
                isReady = true;
                setTimeout(function() {
                    sendMessage('ready', {});
                    console.log('Ready message sent from window load');
                }, 100);
            }
        });
        
        // 외부에서 함수 호출 가능하도록 설정
        window.addEventListener('message', function(event) {
            try {
                const data = JSON.parse(event.data);
                if (data.action && window.communityEditorAPI[data.action]) {
                    window.communityEditorAPI[data.action].apply(null, data.params || []);
                }
            } catch (e) {
                console.error('Error handling message:', e);
            }
        });
    </script>
</body>
</html>
  ''';

  // 지원되는 파일 형식
  static const List<String> supportedImageFormats = [
    'jpg', 'jpeg', 'png', 'gif', 'webp', 'svg'
  ];

  // 파일 크기 제한
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB
  static const int maxImageCount = 10;
  static const int maxTextLength = 100000; // 10만자

  // 기본값
  static const String defaultPlaceholder = '오늘 어떤 여행을 떠나셨나요?\n경험을 공유해주세요!';
  static const int defaultFontSize = 16;
  static const String defaultFontFamily = 'NanumGothic';

  // JavaScript 채널
  static const String jsChannelName = 'communityEditor';

  // 메시지 타입
  static const String messageTypeReady = 'ready';
  static const String messageTypeTextChanged = 'textChanged';
  static const String messageTypeFocus = 'focus';
  static const String messageTypeBlur = 'blur';
  static const String messageTypeImageInserted = 'imageInserted';
  static const String messageTypeImageReplaced = 'imageReplaced';
  static const String messageTypeFormatChanged = 'formatChanged';
  static const String messageTypeListInserted = 'listInserted';
  static const String messageTypeError = 'error';

  // CSS 클래스
  static const String editorClassName = 'editor';
  static const String placeholderClassName = 'placeholder';
  static const String imageLoadingClassName = 'image-loading';

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
    'removeFormat': 'removeFormat',
    'selectAll': 'selectAll',
    'fontSize': 'fontSize',
    'foreColor': 'foreColor',
    'backColor': 'backColor',
    'fontName': 'fontName',
  };

  // 색상 팔레트
  static const List<String> colorPalette = [
    '#000000', // 검은색
    '#FF0000', // 빨간색
    '#FF8C00', // 주황색
    '#FFD700', // 노란색
    '#32CD32', // 초록색
    '#1E90FF', // 파란색
    '#4B0082', // 남색
    '#8A2BE2', // 보라색
    '#74512D', // 브랜드 색상
    '#FF69B4', // 분홍색
    '#00CED1', // 청록색
    '#ADFF2F', // 연두색
    '#FFA500', // 주황색2
    '#DC143C', // 진홍색
    '#008B8B', // 진청록색
    '#8B4513', // 갈색
    '#808080', // 회색
  ];

  // 폰트 크기 옵션
  static const List<int> fontSizes = [8, 10, 12, 14, 16, 18, 20, 24, 28, 32, 36];
}
