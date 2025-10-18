# 마일리지도둑 커뮤니티 Firebase Firestore DB 설계

최종 업데이트: 2025-06-09  
기능 범위: 사용자 관리, 게시글/댓글 작성, 좋아요, 신고, 등급/레벨 시스템 등  

---

## 🚨 신고 사유(ReportReason) Enum

신고 시 선택 가능한 사유는 다음과 같습니다:

| 값      | 설명         |
|---------|--------------|
| abuse   | 욕설/비방    |
| spam    | 도배/광고    |
| sexual  | 음란/선정성  |
| hate    | 혐오/차별    |
| etc     | 기타         |

> Firestore의 posts, comments의 reports 서브컬렉션에서 reason 필드는 위 enum 값 중 하나를 사용합니다.

---

## 📁 users/{uid}

**사용자 기본 정보 및 등급/레벨/포인트 관리**

### ▶️ 문서 필드

| 필드명                | 타입     | 설명 |
|-----------------------|----------|------|
| uid                   | string   | Firebase Auth UID |
| displayName           | string   | 닉네임 |
| photoURL              | string   | 프로필 이미지 URL (기존 profileImageUrl → photoURL로 변경) |
| email                 | string   | 이메일 주소 |
| joinedAt              | timestamp| 가입일 |
| createdAt             | timestamp| 생성일 (Flutter 구조 반영) |
| lastLoginAt           | timestamp| 최근 로그인 시각 (Flutter 구조 반영) |
| postCount             | number   | 작성한 글 수 |
| commentCount          | number   | 댓글 수 |
| likesReceived         | number   | 받은 좋아요 수 |
| likesCount            | number   | 좋아요 수 |
| grade                 | string   | 등급 (이코노미, 비즈니스, 퍼스트, 히든) |
| gradeLevel            | number   | 등급 내 레벨 (1~5, 퍼스트는 1~2) |
| displayGrade          | string   | UI용: "비즈니스 Lv.3" |
| title                 | string   | 칭호 (예: 상테크 천재) |
| gradeUpdatedAt        | timestamp| 등급 갱신 일시 |
| peanutCount           | number   | 커뮤니티 포인트 (기존 mileagePoints → peanutCount로 변경) |
| peanutCountLimit      | number   | 포인트 최대치 (Flutter 구조 반영) |
| fcmToken              | string   | FCM 푸시 토큰 (Flutter 구조 반영) |
| followingCount        | number   | 내가 팔로우한 유저 수 |
| followerCount         | number   | 나를 팔로우한 유저 수 |
| photoURLChangeCount   | number   | 프로필 이미지 변경 횟수 (0부터 시작, 1회 무료) |
| displayNameChangeCount| number   | 닉네임 변경 횟수 (0부터 시작, 1회 무료) |
| photoURLEnable        | boolean  | 프로필 이미지 변경 가능 여부 (true/false) |
| displayNameEnable     | boolean  | 닉네임 변경 가능 여부 (true/false) |
| ownedEffects          | array    | 보유한 스카이 이펙트 목록 |
| currentSkyEffect      | string   | 현재 적용된 스카이 이펙트 (null 가능) |
| roles                 | array    | 권한 (예: ["user"], ["admin"]) |
| isBanned              | boolean  | 차단 여부 |

### 📂 서브컬렉션

#### ▶️ my_posts/{postId}
```json
{
  "postPath": "posts/20250609/posts/abc123",
  "title": "상테크 카드 추천!",
  "createdAt": "2025-06-09T10:00:00Z"
}
```

#### ▶️ liked_posts/{postId}
```json
{
  "postPath": "posts/20250608/posts/xyz456",
  "likedAt": "2025-06-08T22:30:00Z"
}
```

#### ▶️ bookmarks/{postId}
```json
{
  "postPath": "posts/20250608/posts/xyz456",
  "title": "상테크 카드 추천!",
  "bookmarkedAt": "2025-06-08T22:30:00Z"
}
```

#### ▶️ my_comments/{commentId} _(선택적)_
```json
{
  "commentPath": "posts/20250607/posts/abc123/comments/cmt789",
  "postPath": "posts/20250607/posts/abc123",
  "contentHtml": "<p>정보 감사합니다!</p>",
  "contentType": "html",
  "attachments": [],
  "createdAt": "2025-06-07T09:40:00Z"
}
```

#### ▶️ following/{targetUid}
```json
{
  "followedAt": "2025-06-10T12:34:56Z"
}
```
- 내가 팔로우하는 유저의 uid를 문서 ID로 저장
- 팔로잉 목록, 언팔로우, 팔로우 여부 확인 등에 활용

#### ▶️ followers/{followerUid}
```json
{
  "followedAt": "2025-06-10T12:34:56Z"
}
```
- 나를 팔로우하는 유저의 uid를 문서 ID로 저장
- 팔로워 목록, 팔로워 수, 팔로워 알림 등에 활용

#### ▶️ blocked/{blockedUid}
```json
{
  "displayName": "차단한 유저 닉네임",
  "photoURL": "https://...",
  "blockedAt": "2024-06-12T12:34:56Z"
}
```
- 내가 차단한 유저의 uid를 문서 ID로 저장
- 차단 목록, 차단 해제, 차단 여부 확인 등에 활용
- **최대 10명까지 차단 가능 (정책)**

#### ▶️ notifications/{notificationId}
```json
{
  "notificationId": "notif_1704794400000_cmt789",
  "type": "comment",
  "title": "새 댓글이 달렸습니다",
  "body": "vory!님이 회원님의 게시글에 댓글을 남겼습니다",
  "data": {
    "postId": "abc123",
    "dateString": "20250109",
    "boardId": "deal",
    "boardName": "적립/카드 혜택",
    "commentId": "cmt789",
    "authorUid": "user_def",
    "authorName": "vory!",
    "authorPhotoURL": "https://...",
    "deepLinkType": "post_detail",
    "scrollToCommentId": "cmt789"
  },
  "isRead": false,
  "receivedAt": "2025-01-09T14:30:00Z",
  "createdAt": "2025-01-09T14:30:00Z"
}
```
- 사용자가 받은 알림 히스토리 저장
- Cloud Functions에서 FCM 발송과 동시에 생성
- **일주일 후 자동 삭제 (정책)**
- **최대 50개까지 보관 (성능 최적화)**

##### 📋 알림 타입별 data 구조

**댓글 알림 (type: "comment")**
```json
{
  "postId": "abc123",
  "dateString": "20250109", 
  "boardId": "deal",
  "boardName": "적립/카드 혜택",
  "commentId": "cmt789",
  "authorUid": "user_def",
  "authorName": "vory!",
  "authorPhotoURL": "https://...",
  "deepLinkType": "post_detail",
  "scrollToCommentId": "cmt789"
}
```

**좋아요 알림 (type: "like")**
```json
{
  "postId": "abc123",
  "dateString": "20250109",
  "boardId": "deal", 
  "boardName": "적립/카드 혜택",
  "authorUid": "user_def",
  "authorName": "vory!",
  "authorPhotoURL": "https://...",
  "deepLinkType": "post_detail"
}
```

**답글/멘션 알림 (type: "mention")**
```json
{
  "postId": "abc123",
  "dateString": "20250109",
  "boardId": "deal",
  "boardName": "적립/카드 혜택", 
  "commentId": "cmt789",
  "parentCommentId": "cmt456",
  "authorUid": "user_def",
  "authorName": "vory!",
  "authorPhotoURL": "https://...",
  "deepLinkType": "post_detail",
  "scrollToCommentId": "cmt789"
}
```

**팔로우 알림 (type: "follow")**
```json
{
  "authorUid": "user_def",
  "authorName": "vory!",
  "authorPhotoURL": "https://...",
  "deepLinkType": "user_profile"
}
```

**시스템 알림 (type: "system")**
```json
{
  "deepLinkType": "my_page",
  "systemType": "grade_upgrade",
  "newGrade": "business",
  "newLevel": 1
}
```

---

## 📁 posts/{yyyyMMdd}/posts/{postId}

**게시글 본문 정보**

### ▶️ 문서 필드

| 필드명         | 타입     | 설명 |
|----------------|----------|------|
| postId         | string   | 문서 ID |
| postNumber     | string   | 게시글 고유 번호(SSR/정적 URL에 사용). 숫자 문자열 |
| boardId        | string   | 게시판 ID (e.g., deal, free) |
| title          | string   | 제목 |
| contentHtml    | string   | HTML 형식의 본문 |
| author         | map      | 작성자 정보 (uid, displayName, photoURL, displayGrade) |
| viewsCount     | number   | 조회수 |
| likesCount     | number   | 좋아요 수 |
| commentCount   | number   | 댓글 수 |
| reportsCount   | number   | 신고 수 |
| isDeleted      | boolean  | 삭제 여부 |
| isHidden       | boolean  | 블라인드 여부 |
| hiddenByReport | boolean  | 신고 누적 자동 블라인드 여부 |
| createdAt      | timestamp| 작성 시각 |
| updatedAt      | timestamp| 수정 시각 |

#### ▶️ author 구조 상세
```json
{
  "uid": "user123",
  "displayName": "vory!",
  "photoURL": "https://...",
  "displayGrade": "이코노미 Lv.1"
}
```

> **중요**: 사용자 정보 변경 시 author 필드 업데이트
> - 등급 업그레이드: 해당 유저의 모든 posts와 comments의 author.displayGrade 일괄 업데이트
> - 프로필 사진 변경: author.photoURL 일괄 업데이트  
> - 닉네임 변경: author.displayName 일괄 업데이트
> - 읽기 성능 최적화를 위해 비정규화된 구조 사용

### 📂 서브컬렉션

#### ▶️ comments/{commentId}
```json
{
  "commentId": "cmt789",
  "uid": "user_abc",
  "displayName": "무기명",
  "profileImageUrl": "https://...",
  "contentHtml": "<p>좋은 정보 감사합니다!</p>",
  "contentType": "html",
  "attachments": [
    {
      "type": "image",
      "url": "https://storage.../posts/20250609/posts/abc123/comments/cmt789/images/cmt789_abc123.png",
      "filename": "screenshot.png"
    }
  ],
  "parentCommentId": "parent_cmt_id",  // 답글의 부모 댓글 ID (null이면 원댓글)
  "depth": 1,                          // 들여쓰기 레벨 (0=원댓글, 1=답글)
  "replyToUserId": "user_def",         // 답글 대상 사용자 ID
  "mentionedUsers": ["user_def"],      // 멘션된 사용자 ID 배열
  "hasMention": true,                  // 멘션 포함 여부
  "likesCount": 0,
  "isDeleted": false,
  "isHidden": true,
  "hiddenByReport": true,
  "reportsCount": 3,
  "createdAt": "2025-06-09T10:20:00Z",
  "updatedAt": "2025-06-09T10:30:00Z"
}
```

##### ▶️ reports/{reporterUid}
```json
{
  "uid": "user_xyz",
  "reason": "욕설 포함",
  "reportedAt": "2025-06-09T10:25:00Z"
}
```

#### ▶️ likes/{uid}
```json
{
  "uid": "user_def",
  "likedAt": "2025-06-09T11:11:00Z"
}
```

#### ▶️ reports/{uid}
```json
{
  "uid": "user_xyz",
  "reason": "도배",
  "reportedAt": "2025-06-09T11:12:00Z"
}
```

---

## 📁 boards/{boardId}

**게시판 정의**

| boardId      | 이름          | 목적/설명                                 |
|--------------|---------------|-------------------------------------------|
| question     | 마일리지    | 마일리지, 항공사 정책, 발권 문의 등        |
| deal         | 적립/카드 혜택 | 상테크, 카드 추천, 이벤트 정보            |
| seat_share   | 좌석 공유     | 좌석 오픈 알림, 취소표 공유               |
| review       | 항공 리뷰     | 라운지, 기내식, 좌석 후기 등              |
| error_report | 오류 신고     | 앱/서비스 오류 제보                       |
| suggestion   | 건의사항      | 사용자 의견, 개선 요청                    |
| free         | 자유게시판    | 일상, 후기, 질문 섞인 잡담                |
| notice       | 운영 공지사항 | 관리자 공지, 업데이트 안내                |

---

## 📁 admin 컬렉션 (운영진용)

| 경로                                         | 설명 |
|----------------------------------------------|------|
| `admin/reported_items/{id}`                  | 신고 누적된 글/댓글 정보 |
| `admin/flagged_users/{uid}`                  | 문제 유저 정보 |
| `admin/deleted_posts/{postId}`               | 삭제된 글 백업 |
| `admin/board_settings/{boardId}`             | 게시판 설정 정보 |
| `admin/system_logs/{logId}`                  | 관리자 작업 로그 |

---

---

## 🔒 변경권 제한 시스템 (2025.06.30 추가)

### 📋 시스템 개요
사용자의 프로필 이미지와 닉네임 변경을 제한하여 땅콩 경제를 활성화하는 시스템입니다.

### 🎯 변경권 정책
- **1회 무료 변경**: 모든 사용자는 프로필 이미지와 닉네임을 각각 1회씩 무료로 변경 가능
- **유료 변경**: 2번째 변경부터는 땅콩 결제 필요
  - 프로필 이미지: 50땅콩
  - 닉네임: 30땅콩

### 📊 필드 상세 설명

#### ▶️ 변경 횟수 필드
| 필드명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `photoURLChangeCount` | number | 0 | 프로필 이미지 변경 횟수 (0부터 시작) |
| `displayNameChangeCount` | number | 0 | 닉네임 변경 횟수 (0부터 시작) |

#### ▶️ 변경 가능 여부 필드
| 필드명 | 타입 | 기본값 | 설명 |
|--------|------|--------|------|
| `photoURLEnable` | boolean | true | 프로필 이미지 변경 가능 여부 |
| `displayNameEnable` | boolean | true | 닉네임 변경 가능 여부 |

### 🔄 상태 변화 로직

#### 1. 무료 변경 (changeCount < 1)
```json
{
  "photoURLChangeCount": 0,
  "photoURLEnable": true
}
```
- 변경 가능
- 땅콩 차감 없음
- 변경 후: `changeCount++`, `enable = false`

#### 2. 유료 변경 (changeCount >= 1)
```json
{
  "photoURLChangeCount": 1,
  "photoURLEnable": false,
  "peanutCount": 100
}
```
- 땅콩 확인 후 변경 가능
- 변경 시 땅콩 차감
- 변경 후: `changeCount++`, `enable = false`

### 💰 가격 정보
```json
{
  "photoURL": 50,    // 프로필 이미지 변경권
  "displayName": 30  // 닉네임 변경권
}
```

### 🔧 UserService 메서드
- `canChangePhotoURL(uid)`: 변경 가능 여부 확인
- `canChangeDisplayName(uid)`: 변경 가능 여부 확인  
- `changePhotoURL(uid, newURL)`: 변경 처리 (땅콩 차감 포함)
- `changeDisplayName(uid, newName)`: 변경 처리 (땅콩 차감 포함)
- `getChangePrices()`: 가격 정보 조회

### 📱 UI/UX 흐름
1. **변경 시도** → 변경 가능 여부 확인
2. **땅콩 부족** → 구매 다이얼로그 표시
3. **땅콩 충분** → 소모 확인 다이얼로그 표시
4. **사용자 확인** → 실제 변경 진행
5. **변경 완료** → 땅콩 차감 및 카운트 증가

### 🗄️ 마이그레이션
- 기존 사용자: `migrateUsersToChangeSystem()` 함수로 필드 추가
- 새 사용자: `_createUserData()`에서 기본값 설정
- 앱 시작 시 `main.dart`에서 한 번만 실행

## 🔚 요약

이 구조로 다음 기능을 안정적으로 지원할 수 있음:

- 커뮤니티 글/댓글 작성, 좋아요, 신고
- 등급/레벨/포인트 기반 사용자 시스템
- 뱃지, 칭호, 관리자 권한
- 마이페이지에서 활동 기록 조회
- 운영진 신고 처리/유저 제재 관리


