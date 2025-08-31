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
  static const String htmlTemplate = r'''
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
        
        /* 링크 스타일 (에디터 내 파란색 + 밑줄) */
        a {
            color: #1E88E5;
            text-decoration: underline;
            cursor: pointer;
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

        /* 링크 프리뷰 플레이스홀더 (에디터에서만 보여지는 상자) */
        link-preview {
            display: block;
            margin: 8px 0;
        }
        .lp-box {
            display: flex;
            align-items: center;
            gap: 10px;
            border: 1px solid #e0e0e0;
            background: #fafafa;
            border-radius: 8px;
            padding: 10px 12px;
            color: #616161;
            font-size: 14px;
        }
        .lp-spinner {
            width: 16px; height: 16px;
            border: 2px solid #cfd8dc;
            border-top-color: #90caf9;
            border-radius: 50%;
            animation: lp-spin 1s linear infinite;
        }
        @keyframes lp-spin { from { transform: rotate(0); } to { transform: rotate(360deg); } }
        
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
        
        // 포맷 상태 확인 함수 (B/I/U 등 토글 상태 유지)
        function checkFormatState() {
            try {
                if (document.activeElement === editor) {
                    var formatState = {
                        bold: document.queryCommandState('bold'),
                        italic: document.queryCommandState('italic'),
                        underline: document.queryCommandState('underline'),
                        insertUnorderedList: document.queryCommandState('insertUnorderedList'),
                        insertOrderedList: document.queryCommandState('insertOrderedList')
                    };
                    sendMessage('formatChanged', { formatState: formatState });
                }
            } catch (e) {
                console.error('Error checking format state:', e);
            }
        }

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
        
        // URL 정규식 (간단형)
        const urlRegex = /\b((https?:\/\/)?(www\.)?[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}(\/[\w\-._~:/?#[\]@!$&'()*+,;=%]*)?)\b/g;

        function normalizeUrl(raw) {
            try {
                if (!raw) return null;
                let url = raw.trim();
                if (!/^https?:\/\//i.test(url)) {
                    url = 'https://' + url;
                }
                return url;
            } catch (e) { return null; }
        }

        function isInsideAnchor(node) {
            let el = node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
            while (el && el !== editor) {
                if (el.tagName === 'A') return true;
                el = el.parentElement;
            }
            return false;
        }

        function createLinkPreviewElement(url) {
            // 커스텀 태그로 마커 삽입 -> Flutter Html에서 AnyLinkPreview로 렌더
            const tag = document.createElement('link-preview');
            tag.setAttribute('link', url);
            // 에디터 자체에서 보이는 로딩 박스(저장 시엔 무시되고 상세화면에서 진짜 프리뷰 렌더)
            const box = document.createElement('div');
            box.className = 'lp-box';
            const spinner = document.createElement('div');
            spinner.className = 'lp-spinner';
            const text = document.createElement('div');
            text.textContent = '링크 미리보기 생성 중… ' + url;
            box.appendChild(spinner);
            box.appendChild(text);
            tag.appendChild(box);
            return tag;
        }

        function ensurePreviewAfter(anchorEl) {
            try {
                const url = anchorEl.getAttribute('href');
                if (!url) return;
                // 이미 다음 형제로 link-preview가 있으면 중복 생성 방지
                let next = anchorEl.nextSibling;
                while (next && ((next.nodeType === Node.TEXT_NODE && next.textContent.trim() === '') ||
                               (next.nodeType === Node.ELEMENT_NODE && next.tagName === 'BR'))) {
                    next = next.nextSibling;
                }
                if (anchorEl.getAttribute('data-has-preview') === '1') return;
                if (next && next.nodeType === Node.ELEMENT_NODE && next.tagName === 'LINK-PREVIEW') {
                    anchorEl.setAttribute('data-has-preview', '1');
                    return;
                }
                // 방어: 이미 앵커 다음에 존재하면 재삽입하지 않음
                let sibling = anchorEl.nextSibling;
                while (sibling && ((sibling.nodeType === Node.TEXT_NODE && sibling.textContent.trim() === '') || (sibling.nodeType === Node.ELEMENT_NODE && sibling.tagName === 'BR'))) {
                    sibling = sibling.nextSibling;
                }
                if (!(sibling && sibling.nodeType === Node.ELEMENT_NODE && sibling.tagName === 'LINK-PREVIEW')) {
                    const preview = createLinkPreviewElement(url);
                    if (anchorEl.parentNode) {
                        anchorEl.parentNode.insertBefore(preview, anchorEl.nextSibling);
                    }
                }
                anchorEl.setAttribute('data-has-preview', '1');
                // 내용 변경 반영
                setTimeout(function(){ try{ sendMessage('textChanged', { content: editor.innerHTML, text: editor.textContent }); }catch(e){} }, 0);
            } catch (e) {}
        }

        function autolinkNode(node) {
            if (node.nodeType !== Node.TEXT_NODE) return;
            if (!node.textContent || !urlRegex.test(node.textContent)) return;
            if (isInsideAnchor(node)) return;

            const text = node.textContent;
            const frag = document.createDocumentFragment();
            let lastIndex = 0;
            text.replace(urlRegex, (match, _g1, _g2, _g3, _g4, index) => {
                // 앞부분 일반 텍스트
                if (index > lastIndex) {
                    frag.appendChild(document.createTextNode(text.slice(lastIndex, index)));
                }
                const href = normalizeUrl(match);
                const a = document.createElement('a');
                a.href = href || match;
                a.textContent = match;
                a.rel = 'noopener noreferrer';
                a.target = '_blank';
                frag.appendChild(a);
                // 미리보기 마커
                ensurePreviewAfter(a);
                lastIndex = index + match.length;
                return match;
            });
            // 남은 텍스트
            if (lastIndex < text.length) {
                frag.appendChild(document.createTextNode(text.slice(lastIndex)));
            }
            // 교체
            node.parentNode.replaceChild(frag, node);
        }

        function walkAndAutolink(root) {
            const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null);
            const nodes = [];
            let n;
            while ((n = walker.nextNode())) nodes.push(n);
            nodes.forEach(autolinkNode);
        }

        function autolinkContent() {
            try { walkAndAutolink(editor); } catch (e) {}
        }

        function getBlockElementFrom(node) {
            let el = node.nodeType === Node.TEXT_NODE ? node.parentElement : node;
            while (el && el !== editor && !/^(P|DIV|LI|H1|H2|H3|H4|H5|H6)$/i.test(el.tagName)) {
                el = el.parentElement;
            }
            return el || editor;
        }

        function getRangeForOffsetsWithin(root, start, end) {
            const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, null);
            let node, pos = 0;
            const range = document.createRange();
            let startSet = false;
            while ((node = walker.nextNode())) {
                const len = node.textContent.length;
                if (!startSet && pos + len >= start) {
                    range.setStart(node, Math.max(0, start - pos));
                    startSet = true;
                }
                if (pos + len >= end) {
                    range.setEnd(node, Math.max(0, end - pos));
                    break;
                }
                pos += len;
            }
            return range;
        }

        function processUrlBeforeCaret() {
            try {
                const sel = window.getSelection();
                if (!sel || sel.rangeCount === 0) return;
                const caretRange = sel.getRangeAt(0);
                const block = getBlockElementFrom(caretRange.startContainer);

                // 0) 직전 의미 있는 노드가 이미 앵커면 재생성 금지, 프리뷰만 보장
                function getPrevSignificant(node) {
                    let n = (node.nodeType === Node.TEXT_NODE ? node : node.childNodes[node.childNodes.length-1]) || node.previousSibling;
                    if (node.nodeType !== Node.TEXT_NODE) n = node.previousSibling;
                    while (n && ((n.nodeType === Node.TEXT_NODE && n.textContent.trim() === '') ||
                                 (n.nodeType === Node.ELEMENT_NODE && n.tagName === 'BR'))) {
                        n = n.previousSibling;
                    }
                    return n;
                }
                const prev = getPrevSignificant(caretRange.startContainer);
                if (prev && prev.nodeType === Node.ELEMENT_NODE && prev.tagName === 'A') {
                    if (prev.getAttribute('data-has-preview') !== '1') {
                        ensurePreviewAfter(prev);
                    }
                    return; // 앵커가 이미 있으므로 다시 생성하지 않음
                }

                const preRange = document.createRange();
                preRange.setStart(block, 0);
                preRange.setEnd(caretRange.startContainer, caretRange.startOffset);
                const preTextRaw = preRange.toString();
                // zero-width 제거 및 끝 공백 제거하여 URL 끝 판정 정확화
                const preText = preTextRaw.replace(/\u200B/g, '');
                const preTextTrim = preText.replace(/\s+$/, '');

                let lastMatch = null; let m;
                urlRegex.lastIndex = 0;
                while ((m = urlRegex.exec(preTextTrim)) !== null) {
                    lastMatch = m;
                }
                // 현재 라인에 없으면 직전 블록 라인을 검사 (Enter로 새 줄 생성 직전 호출되므로 이전 라인에 URL이 위치)
                if (!lastMatch) {
                    let prev = block.previousSibling;
                    while (prev && ((prev.nodeType === Node.TEXT_NODE && prev.textContent.trim()==='') || (prev.nodeType===Node.ELEMENT_NODE && prev.tagName==='BR'))) {
                        prev = prev.previousSibling;
                    }
                    if (prev && prev.nodeType === Node.ELEMENT_NODE) {
                        const prevTextRaw = prev.textContent || '';
                        const prevTrim = prevTextRaw.replace(/\u200B/g,'').replace(/\s+$/,'');
                        urlRegex.lastIndex = 0;
                        while ((m = urlRegex.exec(prevTrim)) !== null) { lastMatch = m; }
                        if (!lastMatch) return;
                        const matchTextPrev = lastMatch[0];
                        const matchEndPrev = lastMatch.index + matchTextPrev.length;
                        if (matchEndPrev !== prevTrim.length) return;
                        const hrefPrev = normalizeUrl(matchTextPrev) || matchTextPrev;
                        const rangePrev = getRangeForOffsetsWithin(prev, lastMatch.index, matchEndPrev);
                        if (rangePrev.startContainer && rangePrev.startContainer.parentElement && rangePrev.startContainer.parentElement.tagName==='A') {
                            const existA = rangePrev.startContainer.parentElement;
                            if (existA.getAttribute('data-has-preview') !== '1') ensurePreviewAfter(existA);
                            return;
                        }
                        const aPrev = document.createElement('a');
                        aPrev.href = hrefPrev;
                        aPrev.textContent = matchTextPrev;
                        aPrev.rel = 'noopener noreferrer';
                        aPrev.target = '_blank';
                        rangePrev.deleteContents();
                        rangePrev.insertNode(aPrev);
                        ensurePreviewAfter(aPrev);
                        return;
                    } else {
                        return;
                    }
                }
                const matchText = lastMatch[0];
                const matchEnd = lastMatch.index + matchText.length;
                // URL이 블록 내 마지막 토큰이어야 하며, 공백/개행만 뒤따르는 경우 허용
                if (matchEnd !== preTextTrim.length) return;

                const href = normalizeUrl(matchText) || matchText;
                const range = getRangeForOffsetsWithin(block, lastMatch.index, matchEnd);
                // 이미 해당 범위가 앵커 내부인 경우, 프리뷰만 보장하고 종료
                if (range.startContainer && range.startContainer.parentElement && range.startContainer.parentElement.tagName === 'A') {
                    const existA = range.startContainer.parentElement;
                    if (existA.getAttribute('data-has-preview') !== '1') ensurePreviewAfter(existA);
                    return;
                }
                const a = document.createElement('a');
                a.href = href;
                a.textContent = matchText;
                a.rel = 'noopener noreferrer';
                a.target = '_blank';
                range.deleteContents();
                range.insertNode(a);

                // 커서를 앵커 뒤로 이동
                const after = document.createRange();
                after.setStartAfter(a);
                after.collapse(true);
                sel.removeAllRanges();
                sel.addRange(after);

                ensurePreviewAfter(a);
                // Flutter에 감지 이벤트 전달 (작성 화면 썸네일 사전 로드 트리거 용도)
                sendMessage('linkDetected', { link: href });
            } catch (e) {}
        }

        // 텍스트 변경 이벤트
        // Enter는 keydown 시점(분리된 핸들러)에서 처리하고,
        // 여기서는 스페이스만 처리해 중복을 방지
        editor.addEventListener('input', function(e) {
            // 일반 입력에서는 오토링크를 실행하지 않음 (중복/포커스 점프 방지)
            sendMessage('textChanged', {
                content: editor.innerHTML,
                text: editor.textContent
            });
            setTimeout(function() { try { checkFormatState(); } catch (e) {} }, 50);
            // Android IME 대응: 공백 입력 직후에만 처리
            const type = (e && e.inputType) || '';
            const data = (e && e.data) || '';
            if ((type === 'insertText' && (data === ' ' || data === '\u00A0'))) {
                processUrlBeforeCaret();
            }
        });

        // Enter는 keydown 시점(줄바꿈 되기 전)에서 처리해야 이전 라인의 URL을 놓치지 않음
        editor.addEventListener('keydown', function(e){
            if (e.key === 'Enter') {
                try { processUrlBeforeCaret(); } catch (err) {}
            }
        });

        // keyup 기반 처리는 중복 생성 원인이 되어 제거 (IME는 inputType으로 처리)

        // 블러 시에도 남은 URL을 정리
        editor.addEventListener('blur', function() {
            try { processUrlBeforeCaret(); } catch (e) {}
        });
        
        // 키보드 이벤트
        editor.addEventListener('keydown', function(e) {
            // Enter 키 처리
            if (e.key === 'Enter') {
                handleEnterKey(e);
            }
        });

        // 포커스 시 포맷 상태 갱신
        editor.addEventListener('focus', function() {
            setTimeout(function() { try { checkFormatState(); } catch (e) {} }, 100);
        });

        // 선택 변경 시 포맷 상태 갱신
        document.addEventListener('selectionchange', function() {
            try { checkFormatState(); } catch (e) {}
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
                // 명령 실행 후 포맷 상태 갱신
                setTimeout(function() { try { checkFormatState(); } catch (e) {} }, 50);
            },
            
            // HTML 설정
            setHTML: function(html) {
                editor.innerHTML = html;
                if (editor.textContent.trim() === '') {
                    editor.classList.add('placeholder');
                } else {
                    editor.classList.remove('placeholder');
                }
                // 내용 설정 후 포맷 상태 갱신
                setTimeout(function() { try { checkFormatState(); } catch (e) {} }, 50);
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
                // 리스트 토글 후 포맷 상태 갱신
                setTimeout(function() { try { checkFormatState(); } catch (e) {} }, 50);
            },
            
            // 플레이스홀더 설정
            setPlaceholder: function(text) {
                editor.setAttribute('placeholder', text);
            },
            // 저장 직전 강제 동기화: 전체 오토링크 수행 후 현재 HTML 통지
            forceSync: function() {
                try {
                    autolinkContent();
                    sendMessage('textChanged', { content: editor.innerHTML, text: editor.textContent });
                } catch (e) { console.error('forceSync error', e); }
            },
            // 링크 프리뷰 업데이트 (Flutter에서 메타데이터를 받아 카드로 교체)
            updateLinkPreview: function(link, meta) {
                try {
                    if (typeof meta === 'string') {
                        try { meta = JSON.parse(meta); } catch (e) { meta = {}; }
                    }
                    var title = meta && meta.title ? meta.title : link;
                    var desc = meta && meta.desc ? meta.desc : '';
                    var image = meta && meta.image ? meta.image : '';
                    var site = meta && meta.siteName ? meta.siteName : '';
                    var nodes = editor.querySelectorAll('link-preview[link="' + link + '"]');
                    var imgHtml = image ? ('<img src="' + image + '" style="width:56px;height:56px;border-radius:6px;object-fit:cover;flex:none;"/>') : '<div class="lp-spinner" style="flex:none"></div>';
                    var siteHtml = site ? ('<div style="color:#9e9e9e;font-size:11px;margin-top:2px;">' + site + '</div>') : '';
                    var card = '<div class="lp-box">' +
                               imgHtml +
                               '<div style="min-width:0">' +
                               '<div style="font-weight:600;color:#212121;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">' + title + '</div>' +
                               (desc ? '<div style="color:#616161;font-size:12px;overflow:hidden;display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;">' + desc + '</div>' : '') +
                               '<div style="color:#1E88E5;font-size:12px;margin-top:4px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">' + link + '</div>' +
                               siteHtml +
                               '</div></div>';
                    for (var i=0;i<nodes.length;i++) { nodes[i].innerHTML = card; nodes[i].setAttribute('data-ready','1'); }
                    setTimeout(function(){ try{ sendMessage('textChanged', { content: editor.innerHTML, text: editor.textContent }); }catch(e){} }, 0);
                } catch (e) { console.error('updateLinkPreview error', e); }
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
  static const String messageTypeLinkDetected = 'linkDetected';

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
