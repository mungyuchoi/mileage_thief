# 상품권 템플릿 기능 설계서

## 목표
- 구매 화면에서 과거 입력값을 템플릿으로 저장/불러오기
- 일일 탭(구매 내역)에서 특정 구매 항목을 즉시 템플릿으로 저장
- 템플릿을 여러 개 관리(추가/수정/삭제/핀 고정/이름 수정)
- 템플릿이 유실되었을 때 안전하게 참조 정리
- 현재 구현에서 발생한 `_dependents.isEmpty`(Overlay) 크래시를 회피할 수 있게 메뉴/다이얼로그 호출 타이밍 분리

---

## 화면/기능 범위

### 1. 상품권 구매 화면 (GiftBuyScreen)
- 상단 AppBar 우측에 `템플릿` 버튼 추가 (본문 내 기존 `템플릿 불러오기` 버튼은 제거)
- `템플릿` 클릭 시 바텀시트 열기: 템플릿 불러오기 + 관리 진입
- 바텀시트 내 기능
  - 템플릿 목록 조회
  - 검색(선택)
  - 정렬: `pinned` 우선, `lastUsedAt` 내림차순, `name` 오름차순
  - 각 항목 액션
    - 적용
    - 편집(현재 값으로 수정)
    - 이름 수정
    - 삭제
    - 핀 고정/해제
  - 미리보기/요약 문자열 표시
- 고정 템플릿은 구매 폼 상단에 빠른 액션칩으로 노출하여 1탭으로 즉시 적용
- 템플릿 적용 시 폼 값 반영 규칙
  - `giftcardId`, `cardId`, `whereToBuyId`, `payType`, `faceValue`, `qty`, `priceInputMode`, `buyUnit`, `discount`, `memo`, `buyDate`를 반영
  - 금액/할인은 서로 연동되는 기존 입력 모드 유지
  - 삭제된 참조는 경고 후 해당 값 clear
    - `giftcardId` 삭제 → 상품권 선택값 초기화
    - `cardId` 삭제 → 카드 선택값 초기화
    - `whereToBuyId` 삭제 → 구매처 선택값 초기화
  - 적용 성공 시 `useCount += 1`, `lastUsedAt = now`

### 2. 정보 > 일일 탭 (GiftcardInfoScreen)
- 구매 항목 행의 `...` 팝업 메뉴에 `템플릿으로 저장` 메뉴 추가
- 사용자 액션: `정보 > 일일 > 구매 ... > 템플릿으로 저장`
  - 기본 이름을 `yyyyMMdd 구매건`으로 세팅
  - 다이얼로그에서 템플릿명 편집 가능
  - 저장 확인 시 동일 이름 중복 처리 정책은 자유설정
    - 단순 오버라이트 안함(새 문서 생성) 권장
  - 저장 완료 토스트 노출

### 3. 저장 규격 (Firestore)
- 경로: `users/{uid}/gift_templates/{templateId}`
- 문서 구조(권장)
  - `name: string`
  - `nameLower: string` (검색용)
  - `pinned: bool`
  - `useCount: number`
  - `lastUsedAt: Timestamp | null`
  - `dateMode: string` (예: `manual`, 향후 확장용)
  - `payload: map`
  - `createdAt: Timestamp`
  - `updatedAt: Timestamp`
  - `version: number`

#### payload 권장 스키마
- `giftcardId: string | null`
- `cardId: string | null`
- `whereToBuyId: string | null`
- `payType: string`
- `faceValue: number`
- `qty: number`
- `priceInputMode: 'buyUnit' | 'discount'`
- `buyUnit: number`
- `discount: number`
- `memo: string`
- `buyDate: Timestamp`

---

## 코드 변경 포인트(재구현 기준)

### A. `lib/screen/gift/gift_buy_screen.dart`
- 상태/필드
  - `List<Map<String, dynamic>> _templates = []`
  - `_templatesLoading`, `_priceInputMode` 추가
- 초기화
  - `initState` 또는 최초 진입 시 템플릿 로딩(`_loadTemplates`) 호출
- 템플릿 관련 메서드
  - `_loadTemplates()`
    - `users/{uid}/gift_templates` 조회
    - pinned 정렬 + recent 정렬 적용
  - `_openTemplateSheet()`
    - 바텀시트 열기 (템플릿 로드/적용/관리 메뉴)
    - 아이템 선택 시 `_applyTemplate`
  - `_applyTemplate(Map<String, dynamic> t)`
    - payload를 각 입력 컨트롤러/선택값으로 반영
    - 삭제된 참조 처리
    - 마지막 사용정보 업데이트
  - `_createTemplateFromCurrentForm()`
    - 현재 폼 기반 템플릿 생성
  - `_overwriteTemplateWithCurrentForm(Map<String, dynamic> template)`
    - 선택 템플릿에 대해 현재 값 덮어쓰기
  - `_renameTemplate`, `_deleteTemplate`, `_toggleTemplatePin`
  - `_templateSummary`, `_pinnedTemplates`
- UI
  - AppBar `actions` 에 `템플릿` 버튼 추가 (`onPressed: _openTemplateSheet`)
  - 본문 상단 기존 `OutlinedButton` 템플릿 불러오기 제거
  - pinned chip 영역 유지/갱신

### B. `lib/screen/giftcard_info_screen.dart`
- 일일 탭 ledger 위젯에 템플릿 저장 콜백 전달
  - `GiftcardDailyLedger(onSaveTemplate: (entry)...)`
- 템플릿 저장 함수 추가
  - `_saveBuyEntryAsTemplate(GiftcardLedgerEntry entry)`
  - 구매 타입 아닌 경우 return
  - default name: `${DateFormat('yyyyMMdd').format(buyDate)} 구매건`
  - 입력 다이얼로그로 템플릿명 받기
  - 저장 payload 작성 후 `users/{uid}/gift_templates` add

### C. `lib/widgets/giftcard_daily_ledger.dart`
- `_LedgerEntryRow`의 popup menu item에 `템플릿으로 저장` 추가
- 조건: `entry.type == GiftcardLedgerEntryType.buy`
- 선택 동작 시 즉시 navigator 변경/다이얼로그 열지 않도록 post-frame 지연 후 실행
  - `_dependents.isEmpty` 크래시 회피 목적

---

## 핵심 UX/동작 정의

### 템플릿 추가
- 진입 포인트
  - 구매 화면: 상단 `템플릿`
  - 일일 탭: 구매 row 메뉴 `템플릿으로 저장`
- 저장 후 처리
  - 저장 완료 토스트
  - 리스트 자동 refresh

### 템플릿 적용
- 즉시 적용: 구매 폼 컨트롤러에 값 주입
- 가격 모드 동기화
  - 액면가/매입가/할인율 필드 업데이트 시 기존 상호 연동 로직 준수
- 삭제된 참조 처리
  - 구매/카드/구매처가 삭제된 경우 경고 또는 silent clear 정책 둘 다 가능
  - 권장: 바로 clear + 사용자 안내(토스트/다이얼로그)

### 템플릿 이름 관리
- 기본 이름: `yyyyMMdd 구매건`
- 변경 가능: 다이얼로그에서 텍스트 수정
- 이름 검색
  - `nameLower` 컬럼 생성 시 소문자 처리하여 필터/검색

### 템플릿 정렬/표시
- 기본 정렬: 고정(핀) > 최근사용 > 이름
- 목록 요약 문자열
  - 예: `상품권명 / 카드명 / 매입가 or 할인율 / 수량`

---

## 크래시 방어 규칙 (Overlay Assertion 대응)

이 오류는 메뉴에서 다이얼로그/모달을 같은 build-cycle에서 동시에 처리할 때 흔히 발생

- 적용 포인트
  - 팝업 메뉴 선택 후 바로 `showDialog` 호출 금지
  - `WidgetsBinding.instance.addPostFrameCallback` 또는 1틱 지연 후 실행
  - 가능하면 `Navigator.of(context, rootNavigator: true).context` + `useRootNavigator: true` 사용
  - 다이얼로그/바텀시트 실행 전 `mounted` 확인
  - 컨텍스트 생명주기 끝난 뒤 작업하지 않기

---

## 구현 우선순위(재작성용)

### 1차 (필수)
- 저장: 구매 row 메뉴 + 다이얼로그
- 불러오기: 구매 화면 AppBar 템플릿 메뉴
- payload 기본 필드 반영
- 팝업 메뉴 크래시 대응

### 2차 (관리성)
- pinned, useCount, lastUsedAt 반영
- 템플릿 이름 수정/삭제/중복 정책
- 참조 삭제 처리(상품권/카드/구매처)

### 3차 (편의성)
- 템플릿 검색/필터
- 핀 해제/재정렬
- 템플릿 미리보기 태그/메모 반영

---

## 테스트 시나리오(최소)
1. 구매 입력 후 템플릿 저장
   - 이름 기본값 확인
   - 이름 직접 수정 저장
2. 구매 화면에서 `템플릿` 메뉴로 템플릿 목록 열림
3. 적용 시
   - 상품권/카드/구매처 선택값 반영
   - 금액/할인 값 모드 충돌 없음
4. 일일 탭에서 구매 row의 `템플릿으로 저장` 수행
   - 크래시 없이 저장 다이얼로그 표시
5. 참조 삭제 템플릿 적용
   - 삭제된 값이 clear되고 앱 크래시 없이 계속 동작
6. 여러 템플릿 저장/핀 설정/정렬/삭제

---

## 파일 정리 기준
- 구매 화면: `lib/screen/gift/gift_buy_screen.dart`
- 일일 탭: `lib/screen/giftcard_info_screen.dart`
- ledger 위젯: `lib/widgets/giftcard_daily_ledger.dart`


