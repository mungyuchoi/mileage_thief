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
| reportedCount         | number   | 신고당한 횟수 |
| reportSubmittedCount  | number   | 신고한 횟수 |
| grade                 | string   | 등급 (이코노미, 비즈니스, 퍼스트, 히든) |
| gradeLevel            | number   | 등급 내 레벨 (1~5, 퍼스트는 1~2) |
| displayGrade          | string   | UI용: "비즈니스 Lv.3" |
| title                 | string   | 칭호 (예: 상테크 천재) |
| gradeUpdatedAt        | timestamp| 등급 갱신 일시 |
| peanutCount           | number   | 커뮤니티 포인트 (기존 mileagePoints → peanutCount로 변경) |
| peanutCountLimit      | number   | 포인트 최대치 (Flutter 구조 반영) |
| adBonusPercent        | number   | 광고 시 보너스 (%) |
| badgeVisible          | boolean  | 닉네임 옆 뱃지 표시 여부 |
| roles                 | array    | 권한 (예: ["user"], ["admin"]) |
| isBanned              | boolean  | 차단 여부 |
| warnCount             | number   | 경고 횟수 누적 |
| fcmToken              | string   | FCM 푸시 토큰 (Flutter 구조 반영) |
| followingCount        | number   | 내가 팔로우한 유저 수 |
| followerCount         | number   | 나를 팔로우한 유저 수 |

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

---

## 📁 posts/{yyyyMMdd}/{postId}

**게시글 본문 정보**

### ▶️ 문서 필드

| 필드명         | 타입     | 설명 |
|----------------|----------|------|
| postId         | string   | 문서 ID |
| boardId        | string   | 게시판 ID (e.g., deal, free) |
| title          | string   | 제목 |
| contentHtml    | string   | HTML 형식의 본문 |
| author         | map      | 작성자 정보 (uid, displayName, profileImageUrl) |
| viewsCount     | number   | 조회수 |
| likesCount     | number   | 좋아요 수 |
| commentCount   | number   | 댓글 수 |
| reportsCount   | number   | 신고 수 |
| isDeleted      | boolean  | 삭제 여부 |
| isHidden       | boolean  | 블라인드 여부 |
| hiddenByReport | boolean  | 신고 누적 자동 블라인드 여부 |
| createdAt      | timestamp| 작성 시각 |
| updatedAt      | timestamp| 수정 시각 |

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
| popular      | 인기글 모음   | 자동 필터링 (like 기준 등) (읽기 전용)     |

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

## 🔚 요약

이 구조로 다음 기능을 안정적으로 지원할 수 있음:

- 커뮤니티 글/댓글 작성, 좋아요, 신고
- 등급/레벨/포인트 기반 사용자 시스템
- 뱃지, 칭호, 관리자 권한
- 마이페이지에서 활동 기록 조회
- 운영진 신고 처리/유저 제재 관리
